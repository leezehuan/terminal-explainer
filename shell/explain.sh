# shell/explain.sh 文件内容
function explain() {
    if [ $# -eq 0 ]; then
        # ...
        return 1
    fi
    
    local output
    output=$( "$@" 2>&1 )
    local exit_code=$?
    
    echo "$output"
    
    if [ -z "$OPENAI_API_KEY" ]; then
        # ...
        return 1
    fi
    
    # 路径修改为绝对路径
    /usr/local/bin/explain-cli "$*" "$output"
    
    return $exit_code
}
