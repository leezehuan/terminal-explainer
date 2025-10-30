# 终端解释器 (Terminal Explainer)


还在为看不懂复杂的终端输出或难以理解的错误信息而烦恼吗？`Terminal Explainer` 将大语言模型（LLM）的强大威力直接带入您的命令行，一键解释任何命令的输出结果！


---

## ✨ 功能特性

*   **智能解释**：利用强大的 AI 模型（如 GPT-3.5/4）解释 `ls`, `git`, `docker`, `kubectl` 等任何命令的输出。
*   **错误诊断**：当命令执行失败时，AI 会分析错误信息，指出问题根源并提供可能的解决方案。
*   **高度可配置**：支持通过配置文件自定义 API Key、API End-point 和使用的模型，方便接入第三方代理或不同的模型。
*   **安装便捷**：提供一键安装脚本，自动处理依赖和环境配置。
*   **兼容主流**：完美支持 `bash` 和 `zsh`。

## 🚀 安装

安装过程非常简单，仅需两步。

**依赖项:**
在安装前，请确保您的系统（如 Ubuntu）已安装 `git`, `python3`, 和 `python3-pip`。

```bash
sudo apt update
sudo apt install git python3 python3-pip
```

**安装步骤:**
1.  首先，克隆本仓库到您的本地机器：
    ```bash
    git clone https://github.com/leezehuan/terminal-explainer
    ```

2.  进入项目目录，并使用 `sudo` 运行安装脚本：
    ```bash
    cd terminal-explainer
    sudo ./install.sh
    ```
    安装脚本会自动将程序安装到系统目录，并为您配置好 shell 环境。

## ⚙️ 配置

**安装后，最重要的一步是配置您的 API Key。**

安装脚本会自动在您的家目录下创建一份配置文件位于：`~/.config/terminal-explainer/config.ini`。

请用您喜欢的文本编辑器打开此文件，并填入您的个人信息：

```ini
# ~/.config/terminal-explainer/config.ini

[API]
# 必需！替换这里的占位符为你的真实 API Key
api_key = YOUR_API_KEY_HERE

# 如果你使用 OpenAI 官方服务，请保持默认值。
# 如果你使用第三方代理，请修改为你的代理地址。
api_url = https://api.openai.com/v1/chat/completions

# 你想使用的语言模型。
model = gpt-3.5-turbo
```

> **提示**：您也可以通过设置环境变量 `OPENAI_API_KEY` 来提供 API 密钥，它的优先级高于配置文件。

配置完成后，**请务必重启您的终端**，或运行 `source ~/.bashrc` (或 `source ~/.zshrc`) 使配置生效。

## 💡 如何使用

使用方法极为简单，只需在您要执行的命令前加上 `explain` 即可。

#### 示例1：解释一个成功的命令

```bash
explain ls -la
```
您会先看到 `ls -la` 的正常输出，紧接着下方就会出现 AI 对输出内容的逐项解释。

#### 示例2：分析一个失败的命令

```bash
explain cat /root/secret.txt
```
您会先看到熟悉的 `Permission denied` 错误，随后 AI 会告诉您为什么会出现这个错误，并建议您可能需要使用 `sudo` 权限。

## 🔧 工作原理

1.  当您执行 `explain <命令>` 时，定义的 `explain` shell 函数会首先被触发。
2.  该函数会执行您传入的 `<命令>`，并完整捕获其标准输出和标准错误。
3.  函数将捕获到的“原始命令”和“命令输出”作为参数，传递给核心的 Python 脚本 `explain-cli`。
4.  `explain-cli` 脚本负责读取配置文件（`config.ini`）和环境变量，获取 API Key 等信息。
5.  最后，脚本构造一个合适的 Prompt，向指定的大语言模型 API 发送请求，并将返回的解释内容格式化后打印在您的终端上。

## 卸载

如果您想卸载本工具，只需进入项目目录并运行卸载脚本即可：

```bash
cd terminal-explainer
sudo ./uninstall.sh
```
脚本会自动清理所有安装的文件和配置。

## 🤝 贡献

欢迎任何形式的贡献！如果您有好的想法或发现了 Bug，请随时提交 Pull Request 或创建 Issue。

一些可能的未来方向：
*   支持本地化部署的大语言模型（Ollama, Llama.cpp 等）。
*   为常见命令的输出增加缓存机制，以节省 API 调用。
*   增加“智能触发”模式，仅在命令失败时自动解释。

## 📜 许可证

本项目采用 [MIT](https://opensource.org/licenses/MIT) 许可证。
