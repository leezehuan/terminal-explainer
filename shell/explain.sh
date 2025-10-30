# shell/explain.sh 文件内容 (修正版)
function explain() {
    # 检查是否有命令传入
    if [ $# -eq 0 ]; then
        echo "用法: explain <你的命令>"
        return 1
    fi
    
    # 执行传入的命令，并捕获其标准输出和标准错误
    local output
    output=$( "$@" 2>&1 )
    local exit_code=$?
    
    # 立即打印原始输出，保证用户体验
    echo "$output"
    
    # 直接调用 Python 核心脚本进行分析
    # 将所有命令参数合并为一个字符串 ("$*") 作为第一个参数
    # 将命令的输出 ("$output") 作为第二个参数
    /usr/local/bin/explain-cli "$*" "$output"
    
    # 返回原始命令的退出码
    return $exit_code
}
