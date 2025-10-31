# shell/explain.sh

# 说明:
# - 新增 ex 命令，支持：
#   1) ex <cmd...> 运行并解释该命令
#   2) ex 读取上一条命令及其输出并进行分析
#   3) ex -turnon 开启“结果分析常开”，自动对每条命令的输出进行分析
# - 为实现 ex 与“上一条命令输出”能力，脚本会将当前终端会话输出 tee 到日志文件，并用标记分割每条命令。
# - 同时支持 bash 与 zsh（使用 DEBUG trap + PROMPT_COMMAND 或 preexec/precmd）。

# --- 基础路径与状态 ---
if [ -n "$ZSH_VERSION" ]; then
  setopt PROMPT_SUBST 2>/dev/null || true
fi

EX_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/terminal-explainer"
EX_STATE_FILE="$EX_CONFIG_DIR/always_on"
EX_SESSION_LOG="$EX_CONFIG_DIR/session.log"
EX_START="<<<EX-CMD-START>>>"
EX_END="<<<EX-CMD-END>>>"

mkdir -p "$EX_CONFIG_DIR"
: > /dev/null 2>&1 || true
touch "$EX_SESSION_LOG" 2>/dev/null || true

# 读取常开状态
EX_ALWAYS_ON=0
if [ -f "$EX_STATE_FILE" ]; then
  read -r __ex_state < "$EX_STATE_FILE" || true
  if [ "$__ex_state" = "on" ]; then EX_ALWAYS_ON=1; fi
fi

# --- 将会话输出 tee 到日志 ---
# 仅在当前 shell 实例中生效，不影响其他会话
if [ -z "${EX_LOGGING_ACTIVE+x}" ]; then
  EX_LOGGING_ACTIVE=1
  # 将 stdout/stderr 都 tee 到日志，且仍然显示到终端
  exec > >(tee -a "$EX_SESSION_LOG") 2>&1
fi

# --- 内部工具函数 ---
__ex_should_auto_analyze() {
  # 一次性抑制（避免 ex 自己触发的重复分析）
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

__ex_extract_last() {
  # 参数: $1 = cmd_file, $2 = out_file
  local cmd_file="$1"
  local out_file="$2"
  : > "$cmd_file"
  : > "$out_file"

  awk -v start="$EX_START" -v end="$EX_END" -v cf="$cmd_file" -v of="$out_file" '
    $0 ~ "^"start {
      collecting=1
      current_cmd=substr($0, length(start)+2)
      delete out; n=0
      next
    }
    $0 ~ "^"end {
      if (collecting) {
        last_cmd=current_cmd
        last_n=n
        for (i=1; i<=n; i++) last_out[i]=out[i]
        collecting=0
      }
      next
    }
    collecting {
      out[++n]=$0
      next
    }
    END {
      if (last_cmd != "") {
        print last_cmd > cf
        for (i=1; i<=last_n; i++) print last_out[i] > of
      }
    }
  ' "$EX_SESSION_LOG"

  [ -s "$cmd_file" ] || return 1
  return 0
}

__ex_analyze_last() {
  local cmd_file out_file
  cmd_file="$(mktemp 2>/dev/null || echo "$EX_CONFIG_DIR/.last_cmd")"
  out_file="$(mktemp 2>/dev/null || echo "$EX_CONFIG_DIR/.last_out")"

  if __ex_extract_last "$cmd_file" "$out_file"; then
    local cmd_str out_str
    cmd_str="$(cat "$cmd_file")"
    out_str="$(cat "$out_file")"
    EX_IN_HOOK=1
    /usr/local/bin/explain-cli "$cmd_str" "$out_str"
    EX_IN_HOOK=0
  else
    echo "[ex] 未捕获到上一条命令及其输出。"
  fi

  rm -f "$cmd_file" "$out_file" 2>/dev/null || true
}

# --- 钩子: bash 与 zsh ---
if [ -n "$BASH_VERSION" ]; then
  __ex_bash_preexec() {
    [ "${EX_IN_HOOK:-0}" = "1" ] && return
    # 获取完整上一条命令
    local cmd
    cmd=$(HISTTIMEFORMAT= history 1 | sed 's/^ *[0-9]\+ *//')
    EX_CURRENT_CMD="$cmd"
    printf '%s %s\n' "$EX_START" "$EX_CURRENT_CMD"
  }
  trap '__ex_bash_preexec' DEBUG

  __ex_bash_precmd() {
    [ "${EX_IN_HOOK:-0}" = "1" ] && return
    printf '%s %s\n' "$EX_END" "$EX_CURRENT_CMD"
    EX_LAST_CMD="$EX_CURRENT_CMD"
    if __ex_should_auto_analyze; then
      __ex_analyze_last || true
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
    printf '%s %s\n' "$EX_START" "$EX_CURRENT_CMD"
  }
  __ex_zsh_precmd() {
    [[ "${EX_IN_HOOK:-0}" = 1 ]] && return
    printf '%s %s\n' "$EX_END" "$EX_CURRENT_CMD"
    EX_LAST_CMD="$EX_CURRENT_CMD"
    if __ex_should_auto_analyze; then
      __ex_analyze_last || true
    fi
  }

  if typeset -f add-zsh-hook >/dev/null 2>&1; then
    add-zsh-hook preexec __ex_zsh_preexec
    add-zsh-hook precmd __ex_zsh_precmd
  else
    # 退化支持
    preexec() { __ex_zsh_preexec "$@" ; }
    precmd() { __ex_zsh_precmd ; }
  fi
fi

# --- 用户命令: ex / explain(兼容) ---
function ex() {
  # 功能开关
  if [ $# -eq 1 ] && [ "$1" = "-turnon" ]; then
    EX_ALWAYS_ON=1
    echo "on" > "$EX_STATE_FILE"
    echo "✅ 已开启结果分析常开功能。"
    return 0
  fi

  # 无参数：分析上一条命令及其输出
  if [ $# -eq 0 ]; then
    __ex_analyze_last
    return $?
  fi

  # ex <cmd...>：执行并解释该命令
  local output exit_code
  output=$( "$@" 2>&1 )
  exit_code=$?

  # 原始输出
  echo "$output"

  # 避免自动模式重复解释
  EX_SUPPRESS_AUTO_ONE=1
  EX_IN_HOOK=1
  /usr/local/bin/explain-cli "$*" "$output"
  EX_IN_HOOK=0

  return $exit_code
}

# 兼容旧命令名
function explain() {
  ex "$@"
}
