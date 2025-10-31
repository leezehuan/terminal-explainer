#!/bin/bash
# uninstall.sh

# --- 卸载脚本 ---
if [ "$EUID" -ne 0 ]; then
  echo "请使用 sudo 运行此脚本: sudo ./uninstall.sh"
  exit 1
fi

echo "正在卸载 Terminal Explainer..."

# 1. 移除可执行文件
rm -f /usr/local/bin/explain-cli

# 2. 移除 shell 配置文件
rm -rf /usr/local/share/terminal-explainer

# 3. 从用户的 shell 配置中移除 source 命令
USERS_TO_CONFIGURE=()
if [ -n "$SUDO_USER" ]; then USERS_TO_CONFIGURE+=("$SUDO_USER"); fi
if [ -n "$LOGNAME" ] && [ "$LOGNAME" != "$SUDO_USER" ]; then USERS_TO_CONFIGURE+=("$LOGNAME"); fi

for user in "${USERS_TO_CONFIGURE[@]}"; do
    HOME_DIR=$(getent passwd "$user" | cut -d: -f6)
    if [ -f "$HOME_DIR/.bashrc" ]; then
        sed -i '/# --- Terminal Explainer ---/,/explain.sh/d' "$HOME_DIR/.bashrc"
    fi
    if [ -f "$HOME_DIR/.zshrc" ]; then
        sed -i '/# --- Terminal Explainer ---/,/explain.sh/d' "$HOME_DIR/.zshrc"
    fi
done

echo "卸载完成。请重启终端。"
