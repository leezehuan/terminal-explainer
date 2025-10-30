#!/bin/bash

# ==============================================================================
# Terminal Explainer - Installation Script
# ==============================================================================
#
# 这个脚本会执行以下操作:
# 1. 检查 root 权限和基本依赖 (python3, pip3)。
# 2. 安装所需的 Python 库 (requests)。
# 3. 将主程序和 shell 函数文件复制到系统标准位置。
# 4. 为用户创建并配置 .ini 配置文件。
# 5. 自动更新用户的 .bashrc 和 .zshrc 以加载 explain 函数。
#
# ==============================================================================

# --- 配置和函数 ---
set -e # 如果任何命令失败，则立即退出脚本

# 检查是否以 root 权限运行
check_root() {
  if [ "$EUID" -ne 0 ]; then
    echo "错误: 请使用 sudo 运行此安装脚本。"
    echo "用法: sudo ./install.sh"
    exit 1
  fi
}

# 打印步骤标题
step() {
  echo -e "\n\033[1;34m=> $1\033[0m"
}


# --- 主程序 ---
check_root

step "开始安装 Terminal Explainer..."

# [ 步骤 1: 检查依赖 ]
step "步骤 1/5: 检查系统依赖..."
command -v python3 >/dev/null 2>&1 || { echo >&2 "错误: 'python3' 未找到。请先安装 python3。"; exit 1; }
command -v pip3 >/dev/null 2>&1 || { echo >&2 "错误: 'pip3' 未找到。请先安装 python3-pip。"; exit 1; }
echo "依赖检查通过。"

# [ 步骤 2: 安装 Python 库 ]
step "步骤 2/5: 安装 Python 'requests' 库..."
pip3 install requests --quiet
echo "'requests' 库已安装。"

# [ 步骤 3: 复制程序文件 ]
step "步骤 3/5: 安装核心文件..."
# 创建存放 shell 函数的目录
mkdir -p /usr/local/share/terminal-explainer
# 使用 'install' 命令复制文件，这是比 'cp' 更规范的方式
install -m 755 bin/explain-cli /usr/local/bin/explain-cli
install -m 644 shell/explain.sh /usr/local/share/terminal-explainer/explain.sh
echo "文件已安装到 /usr/local/bin 和 /usr/local/share/terminal-explainer。"

# [ 步骤 4: 创建用户配置文件 ]
step "步骤 4/5: 设置用户配置文件..."
# `sudo` 命令会保留 `SUDO_USER` 变量，指向最初调用 sudo 的用户
# 我们需要为这个用户创建配置文件
THE_USER=${SUDO_USER:-$(whoami)}
HOME_DIR=$(getent passwd "$THE_USER" | cut -d: -f6)

if [ -z "$HOME_DIR" ]; then
    echo "错误: 无法确定用户 '$THE_USER' 的家目录。"
    exit 1
fi

CONFIG_DIR="$HOME_DIR/.config/terminal-explainer"
CONFIG_FILE="$CONFIG_DIR/config.ini"

# 创建配置目录，并确保所有权正确
mkdir -p "$CONFIG_DIR"
chown "$THE_USER":"$THE_USER" "$CONFIG_DIR"

# 如果配置文件不存在，则从模板创建
if [ ! -f "$CONFIG_FILE" ]; then
    echo "  -> 为用户 '$THE_USER' 创建默认配置文件..."
    install -m 644 -o "$THE_USER" -g "$THE_USER" config.ini.template "$CONFIG_FILE"
else
    echo "  -> 配置文件 '$CONFIG_FILE' 已存在，跳过创建。"
fi



# --- 安装完成 ---
echo -e "\n\033[1;32m✅ 安装成功！\033[0m"
echo
echo -e "\033[1;33m下一步操作:\033[0m"
echo -e "1. \033[1m请务必编辑您的配置文件并填入 API Key:\033[0m"
echo -e "   \033[36mnano $CONFIG_FILE\033[0m"
echo
echo -e "2. \033[1m重新启动您的终端，或运行以下命令使配置生效:\033[0m"
echo -e "   \033[36msource $HOME_DIR/.bashrc\033[0m (如果您使用 bash)"
echo -e "   \033[36msource $HOME_DIR/.zshrc\033[0m (如果您使用 zsh)"
echo
