function explain() {
    if [ $# -eq 0 ]; then
        echo "用法: explain <你的命令>"
        return 1
    fi
    
    # 正确执行命令并捕获输出
    local output
    output=$( "$@" 2>&1 )
    local exit_code=$?
    
    # 打印原始输出
    echo "$output"
    
    # 检查环境变量
    if [ -z "$OPENAI_API_KEY" ]; then
        echo -e "\n\033[31m错误: 环境变量 OPENAI_API_KEY 未设置！\033[0m"
        return 1
    fi
    
    # --- 关键修改在这里 ---
    # 使用 "$*" 将所有命令参数合并成一个字符串传递给 Python
    python3 /home/lee/analyst.py "$*" "$output"
    
    return $exit_code
}