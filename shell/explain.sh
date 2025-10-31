# shell/explain.sh (v8 - 修复 ex -c 误判：以原始命令为“命令参数”，对话式上下文作为“输出”上传；保留10k上传限制与追问链)

# --- 基础路径与状态 ---
if [ -n "$ZSH_VERSION" ]; then
  setopt PROMPT_SUBST 2>/dev/null || true
fi

EX_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/terminal-explainer"
EX_STATE_FILE="$EX_CONFIG_DIR/always_on"
EX_SESSION_LOG="$EX_CONFIG_DIR/session.log"
EX_START="<<<EX-CMD-START>>>"
EX_END="<<<EX-CMD-END>>>"

# 上传到 LLM 的输出字数上限（字符数）
EX_UPLOAD_CHAR_LIMIT="${EX_UPLOAD_CHAR_LIMIT:-10000}"

mkdir -p "$EX_CONFIG_DIR"
touch "$EX_SESSION_LOG" 2>/dev/null || true

# 常开状态
EX_ALWAYS_ON=0
if [ -f "$EX_STATE_FILE" ]; then
  read -r __ex_state < "$EX_STATE_FILE" || true
  if [ "$__ex_state" = "on" ]; then EX_ALWAYS_ON=1; fi
fi

# 将会话输出 tee 到日志（仅初始化一次）
if [ -z "${EX_LOGGING_ACTIVE+x}" ]; then
  EX_LOGGING_ACTIVE=1
  # 重定向 stdout/stderr 到 tee，同时仍显示到终端
  exec > >(tee -a "$EX_SESSION_LOG") 2>&1
fi

# --- 内部工具函数 ---
__ex_should_auto_analyze() {
  # 避免 ex 手动分析后自动模式重复触发
  if [ "${EX_SUPPRESS_AUTO_ONE:-0}" = "1" ]; then
    EX_SUPPRESS_AUTO_ONE=0
    return 1
  fi

  [ "${EX_ALWAYS_ON:-0}" = "1" ] || return 1
  [ -n "${EX_LAST_CMD:-}" ] || return 1

  case "$EX_LAST_CMD" in
    ex|ex\ *|explain|explain\ *|*/explain-cli*|explain-cli*)
      return 1
      ;;
  esac

  return 0
}

# 从日志中提取“最近一条非 ex/explain 的命令及其输出”
__ex_extract_last_non_ex() {
  local cmd_file="$1"
  local out_file="$2"
  : > "$cmd_file"
  : > "$out_file"

  awk -v start="$EX_START" -v end="$EX_END" -v cf="$cmd_file" -v of="$out_file" '
    function flush_segment() {
      seg_count++
      seg_cmd[seg_count]=current_cmd
      seg_out[seg_count]=out_buf
      out_buf=""
    }
    $0 ~ "^"start {
      collecting=1
      current_cmd=substr($0, length(start)+2)  # start + 空格
      out_buf=""
      next
    }
    $0 ~ "^"end {
      if (collecting) {
        flush_segment()
        collecting=0
      }
      next
    }
    collecting {
      out_buf = (out_buf == "" ? $0 : out_buf "\n" $0)
      next
    }
    END {
      for (i=seg_count; i>=1; i--) {
        cmd=seg_cmd[i]
        if (cmd !~ /^(ex($| )|explain($| ))/) {
          print cmd > cf
          if (seg_out[i] != "") print seg_out[i] > of
          exit
        }
      }
      if (seg_count >= 1) {
        print seg_cmd[seg_count] > cf
        if (seg_out[seg_count] != "") print seg_out[seg_count] > of
      }
    }
  ' "$EX_SESSION_LOG"

  [ -s "$cmd_file" ] || return 1
  return 0
}

# 构建 ex -c 追问链上下文（对话式模板），同时导出“原始命令字符串”
# $1: context_file 输出对话式上下文
# $2: origin_cmd_file 输出原始命令（用于作为 explain-cli 的第一个参数）
# $3: 当前追问文本
__ex_build_followup_context() {
  local context_file="$1"
  local origin_cmd_file="$2"
  local current_q="$3"

  : > "$context_file" || return 1
  : > "$origin_cmd_file" || return 1

  awk -v start="$EX_START" -v end="$EX_END" -v current_q="$current_q" -v ocf="$origin_cmd_file" '
    # 收集所有分段
    $0 ~ "^"start {
      collecting=1
      seg_count++
      seg_cmd[seg_count]=substr($0, length(start)+2)
      seg_out[seg_count]=""
      next
    }
    $0 ~ "^"end {
      collecting=0
      next
    }
    collecting {
      seg_out[seg_count] = (seg_out[seg_count]=="" ? $0 : seg_out[seg_count] "\n" $0)
      next
    }
    END {
      # 默认输出的原始命令（若无法识别）
      origin_cmd_str = ""

      if (seg_count >= 1) {
        # 从末尾回溯：收集连续 ex -c 段
        idx = seg_count
        c = 0
        while (idx >= 1 && seg_cmd[idx] ~ /^ex[ ]+-c[ ]+/) {
          c++; exci[c] = idx
          idx--
        }

        base_idx = (idx >= 1 ? idx : 0)

        # 判断 base 是否为 ex（但不是 ex -c）
        is_base_ex = 0
        if (base_idx > 0) {
          if (seg_cmd[base_idx] ~ /^ex($|[ ])/ && seg_cmd[base_idx] !~ /^ex[ ]+-c[ ]+/) {
            is_base_ex = 1
          }
        }

        # 推断原始命令
        if (base_idx > 0) {
          if (is_base_ex) {
            if (seg_cmd[base_idx] == "ex") {
              prev_cmd_idx = (base_idx - 1 >= 1 ? base_idx - 1 : 0)
              if (prev_cmd_idx > 0) {
                origin_cmd_str = seg_cmd[prev_cmd_idx]
              }
            } else {
              # ex <cmd...>
              origin_cmd_str = seg_cmd[base_idx]
              gsub(/^ex[ ]+/,"",origin_cmd_str)
            }
          } else {
            # base 是普通命令
            origin_cmd_str = seg_cmd[base_idx]
          }
        }
      }

      # 将原始命令写入文件（为空则给一个语义安全的占位，不是 ex -c）
      if (origin_cmd_str == "") origin_cmd_str = "FOLLOWUP_CONTEXT"
      print origin_cmd_str > ocf

      # 输出对话式模板到 stdout（调用方重定向到 context_file）
      print "你是一个专业的Linux终端助手。下面是一段你和用户之间的对话历史。"
      print ""
      print "重要指示：下面的“输出”并非单纯的命令标准输出，而是包含对话历史与提问。"
      print "不要解释或执行 ex / ex -c 命令本身；请仅基于“原始命令与其真实输出”来回答最后的追问。"
      print ""
      print "---"
      print "[对话起点]"
      print ""
      print "用户执行了以下命令:"
      if (origin_cmd_str != "") {
        print "`" origin_cmd_str "`"
      } else {
        print "`（无法识别上一条非追问命令）`"
      }
      print ""
      print "该命令产生了如下输出（节选/或为空）："
      print "```"
      # 尝试填充原始输出
      origin_out_str = ""
      if (seg_count >= 1) {
        # 若 base 存在，则取其输出作为原始输出的首选
        if (base_idx > 0) {
          if (is_base_ex) {
            # ex 或 ex <cmd...> 的上一段可能才是原始输出
            prev_cmd_idx = (base_idx - 1 >= 1 ? base_idx - 1 : 0)
            if (prev_cmd_idx > 0) origin_out_str = seg_out[prev_cmd_idx]
          } else {
            origin_out_str = seg_out[base_idx]
          }
        }
      }
      if (origin_out_str != "") print origin_out_str
      print "```"

      # 上一轮回答（如果可用：当 base 是 ex / ex <cmd...> 时）
      ai_prev_ans = ""
      if (seg_count >= 1 && base_idx > 0 && is_base_ex) {
        ai_prev_ans = seg_out[base_idx]
      }
      if (ai_prev_ans != "") {
        print ""
        print "---"
        print "[你的上一轮回答]"
        print ""
        print "你对上述命令和输出进行了解释："
        print "```"
        print ai_prev_ans
        print "```"
      }

      # 历史追问与回答（按时间顺序，从最早到最近）
      if (seg_count >= 1) {
        # 统计连续 ex -c 的数量 c（已在上面得到）
        if (c > 0) {
          print ""
          print "---"
          print "[之前的追问与回答历史]"
          for (i=c; i>=1; i--) {
            qi = exci[i]
            q = seg_cmd[qi]
            sub(/^ex[ ]+-c[ ]+/,"", q)
            ans = seg_out[qi]
            print ""
            print "用户的追问:"
            print "\"" q "\""
            print ""
            print "你的回答:"
            print "```"
            if (ans != "") print ans
            print "```"
          }
        }
      }

      # 当前追问
      print ""
      print "---"
      print "[用户的当前追问]"
      print ""
      print "\"" current_q "\""
      print ""
      print "请根据以上的完整对话背景，针对用户的当前追问进行直接、简洁且准确的回答。"
    }
  ' "$EX_SESSION_LOG" > "$context_file"
}

__ex_analyze_prev() {
  local cmd_file out_file
  cmd_file="$(mktemp 2>/dev/null || echo "$EX_CONFIG_DIR/.last_cmd")"
  out_file="$(mktemp 2>/dev/null || echo "$EX_CONFIG_DIR/.last_out")"

  if __ex_extract_last_non_ex "$cmd_file" "$out_file"; then
    local cmd_str out_str
    cmd_str="$(cat "$cmd_file")"
    # 只读取并上传前 EX_UPLOAD_CHAR_LIMIT 个字符
    if command -v cut >/dev/null 2>&1; then
      out_str="$(cut -c -"${EX_UPLOAD_CHAR_LIMIT}" "$out_file" 2>/dev/null || cat "$out_file")"
    else
      out_str="$(cat "$out_file")"
      out_str="$(printf '%s' "$out_str" | awk -v n="$EX_UPLOAD_CHAR_LIMIT" '{s=s $0 ORS} END{print substr(s,1,n)}')"
    fi
    EX_IN_HOOK=1
    /usr/local/bin/explain-cli "$cmd_str" "$out_str"
    EX_IN_HOOK=0
  else
    echo "[ex] 未捕获到上一条命令及其输出。"
  fi

  rm -f "$cmd_file" "$out_file" 2>/dev/null || true
}

__ex_analyze_followup() {
  # $1: 当前追问文本
  local question="$1"
  local ctx_file origin_cmd_file t_ctx origin_cmd
  ctx_file="$(mktemp 2>/dev/null || echo "$EX_CONFIG_DIR/.ctx_followup")"
  origin_cmd_file="$(mktemp 2>/dev/null || echo "$EX_CONFIG_DIR/.origin_cmd")"

  __ex_build_followup_context "$ctx_file" "$origin_cmd_file" "$question" || {
    echo "[ex] 构建追问上下文失败。"
    return 1
  }

  origin_cmd="$(cat "$origin_cmd_file" 2>/dev/null || true)"
  if [ -z "$origin_cmd" ]; then
    origin_cmd="FOLLOWUP_CONTEXT"
  fi

  # 只读取并上传前 EX_UPLOAD_CHAR_LIMIT 个字符
  if command -v cut >/dev/null 2>&1; then
    t_ctx="$(cut -c -"${EX_UPLOAD_CHAR_LIMIT}" "$ctx_file" 2>/dev/null || cat "$ctx_file")"
  else
    t_ctx="$(cat "$ctx_file")"
    t_ctx="$(printf '%s' "$t_ctx" | awk -v n="$EX_UPLOAD_CHAR_LIMIT" '{s=s $0 ORS} END{print substr(s,1,n)}')"
  fi

  # 避免自动模式重复分析
  EX_SUPPRESS_AUTO_ONE=1
  EX_IN_HOOK=1
  # 关键改动：将“命令参数”设置为原始命令（或FOLLOWUP_CONTEXT），
  # 而不是把 "ex -c ..." 作为命令传给 explain-cli，避免LLM误把 ex 当编辑器解释
  /usr/local/bin/explain-cli "$origin_cmd" "$t_ctx"
  EX_IN_HOOK=0

  rm -f "$ctx_file" "$origin_cmd_file" 2>/dev/null || true
}

# --- 钩子: bash 与 zsh ---
if [ -n "$BASH_VERSION" ]; then
  __ex_bash_preexec() {
    [ "${EX_IN_HOOK:-0}" = "1" ] && return
    local cmd
    cmd=$(HISTTIMEFORMAT= history 1 | sed 's/^ *[0-9]\+ *//')
    EX_CURRENT_CMD="$cmd"
    # 直接写入日志文件，避免污染终端
    printf '%s %s\n' "$EX_START" "$EX_CURRENT_CMD" >> "$EX_SESSION_LOG"
  }
  trap '__ex_bash_preexec' DEBUG

  __ex_bash_precmd() {
    [ "${EX_IN_HOOK:-0}" = "1" ] && return
    printf '%s\n' "$EX_END" >> "$EX_SESSION_LOG"
    EX_LAST_CMD="$EX_CURRENT_CMD"
    if __ex_should_auto_analyze; then
      __ex_analyze_prev || true
    fi
  }
  if [[ -z "$PROMPT_COMMAND" ]]; then
    PROMPT_COMMAND="__ex_bash_precmd"
  else
    PROMPT_COMMAND="__ex_bash_precmd; $PROMPT_COMMAND"
  fi
fi

if [ -n "$ZSH_VERSION" ]; then
  autoload -Uz add-zsh-hook 2>/dev/null || true

  __ex_zsh_preexec() {
    [[ "${EX_IN_HOOK:-0}" = 1 ]] && return
    EX_CURRENT_CMD="$1"
    printf '%s %s\n' "$EX_START" "$EX_CURRENT_CMD" >> "$EX_SESSION_LOG"
  }

  __ex_zsh_precmd() {
    [[ -n "$ZLE_STATE" || -n "$ZLE" ]] && return
    [[ "${EX_IN_HOOK:-0}" = 1 ]] && return
    printf '%s\n' "$EX_END" >> "$EX_SESSION_LOG"
    EX_LAST_CMD="$EX_CURRENT_CMD"
    if __ex_should_auto_analyze; then
      __ex_analyze_prev || true
    fi
  }

  if typeset -f add-zsh-hook >/dev/null 2>&1; then
    add-zsh-hook preexec __ex_zsh_preexec
    add-zsh-hook precmd __ex_zsh_precmd
  else
    preexec() { __ex_zsh_preexec "$@" ; }
    precmd() { __ex_zsh_precmd ; }
  fi
fi

# --- 用户命令: ex / explain(兼容) ---
function ex() {
  # ex -turnon：开启自动分析
  if [ $# -eq 1 ] && [ "$1" = "-turnon" ]; then
    EX_ALWAYS_ON=1
    echo "on" > "$EX_STATE_FILE"
    echo "✅ 已开启结果分析常开功能。"
    return 0
  fi

  # ex -c <追问内容>：对“上一个不是 ex -c 的命令与回答”的追问，支持连续追问链
  if [ $# -ge 1 ] && [ "$1" = "-c" ]; then
    shift
    local question
    question="$*"
    if [ -z "$question" ]; then
      echo "[ex] 用法: ex -c <你的追问内容>"
      return 1
    fi
    __ex_analyze_followup "$question"
    return $?
  fi

  # ex：分析上一条有效命令
  if [ $# -eq 0 ]; then
    __ex_analyze_prev
    return $?
  fi

  # ex <cmd...>：执行并分析该命令
  local output exit_code truncated_out
  output=$( "$@" 2>&1 )
  exit_code=$?

  # 原始输出打印到终端（不截断）
  echo "$output"

  # 仅上传前 EX_UPLOAD_CHAR_LIMIT 个字符
  truncated_out="$(printf '%s' "$output" | cut -c -"${EX_UPLOAD_CHAR_LIMIT}")"

  # 避免自动模式重复分析
  EX_SUPPRESS_AUTO_ONE=1
  EX_IN_HOOK=1
  /usr/local/bin/explain-cli "$*" "$truncated_out"
  EX_IN_HOOK=0

  return $exit_code
}

# 兼容旧命令名
function explain() {
  ex "$@"
}
