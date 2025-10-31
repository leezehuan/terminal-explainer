# 终端解释器 (Terminal Explainer)

还在为看不懂复杂的终端输出或难以理解的错误信息而烦恼吗？`Terminal Explainer` 将大语言模型（LLM）的强大威力直接带入您的命令行，一键解释任何命令的输出结果！

---

## ✨ 功能特性

- **智能解释**：利用强大的 AI 模型（如 GPT-3.5/4）解释 `ls`, `git`, `docker`, `kubectl` 等任何命令的输出。
- **错误诊断**：当命令执行失败时，AI 会分析错误信息，指出问题根源并提供可能的解决方案。
- **读取上一条**：支持直接输入 `ex`，自动读取上一条命令及其输出并进行分析。
- **常开模式**：通过 `ex -turnon` 开启“结果分析常开”，无需输入 `ex`，每条命令执行后自动分析其输出。
- **高度可配置**：支持通过配置文件自定义 API Key、API End-point 和使用的模型，方便接入第三方代理或不同的模型。
- **安装便捷**：提供一键安装脚本，自动处理依赖和环境配置。
- **兼容主流**：完美支持 `bash` 和 `zsh`。

> **提示**：为实现“读取上一条命令及其输出”和“常开模式”的功能，本工具会在当前交互式会话中，将终端的输出流 `tee` 到一个位于配置目录下的会话日志文件中，并使用特殊标记来划分每条命令的边界。

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
    安装脚本会自动将核心程序安装到系统目录，并为您自动配置好 shell 环境。

## ⚙️ 配置

**安装后，最重要的一步是配置您的 API Key。**

安装脚本会自动在您的家目录下创建一份配置文件，位于：`~/.config/terminal-explainer/config.ini`。

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

## 💡 使用方法

#### 示例1：解释一个任意命令 (新用法)

只需在您要执行的命令前加上 `ex` 即可。

```bash
ex ls -la
```
您会先看到 `ls -la` 的正常输出，紧接着下方就会出现 AI 对输出内容的逐项解释。

#### 示例2：读取上一条命令及输出并进行分析

如果您刚刚执行完一条命令，希望回过头来再看一下解释，只需直接输入：

```bash
ex
```
工具会自动找到上一条执行的命令及其完整输出，并进行分析。

#### 示例3：开启“结果分析常开”模式

如果您希望每条命令执行后都自动进行分析，可以开启此模式：

```bash
ex -turnon
```
开启后，您无需再输入 `ex`，每条命令（除了 `ex` 相关命令本身）执行完成后都会自动触发分析。此设置在当前 shell 会话中永久有效；若需关闭，可重启 shell 或手动删除状态文件 `~/.config/terminal-explainer/always_on`。

#### 兼容旧命令名

为了向后兼容，`explain` 命令仍然可用，作为 `ex` 的别名。

```bash
explain ls -la
```

## 🔧 工作原理

1.  **钩子注入**：安装时，插件通过 `source` 命令将 `explain.sh` 脚本载入您的 `.bashrc` 或 `.zshrc`。该脚本会利用 `bash` 的 `DEBUG` trap 和 `PROMPT_COMMAND` 或 `zsh` 的 `preexec`/`precmd` 钩子，来监控命令的执行。
2.  **会话日志**：脚本还会将当前交互式 shell 的标准输出和标准错误通过 `tee` 命令实时复制一份到日志文件 `~/.config/terminal-explainer/session.log`。
3.  **边界标记**：在每条命令即将执行前 (pre-exec)，钩子函数会在日志中写入一个唯一的**开始标记** (`<<<EX-CMD-START>>>`) 和命令本身；在命令执行完毕后 (pre-cmd)，钩子会写入一个**结束标记** (`<<<EX-CMD-END>>>`)。这样，每条命令及其输出在日志中都被清晰地界定。
4.  **命令分析**：
    *   当您执行 `ex <命令>` 时，shell 函数会先执行 `<命令>`，捕获其输出，然后连同命令字符串一起交给 Python 核心脚本 `explain-cli` 去分析。
    *   当您执行 `ex` (无参数) 时，函数会从后向前扫描会话日志，找到最后一个完整的“开始-结束”标记对，提取出其中的命令和输出，再交给 `explain-cli`。
    *   在**常开模式**下，pre-cmd 钩子在每次命令执行完毕后，都会自动执行与 `ex` 相同的日志提取和分析流程。

## 卸载

如果您想卸载本工具，只需进入项目目录并运行卸载脚本即可：

```bash
cd terminal-explainer
sudo ./uninstall.sh
```
脚本会自动清理所有安装的文件和 shell 配置。

## 🤝 贡献

欢迎任何形式的贡献！如果您有好的想法或发现了 Bug，请随时提交 Pull Request 或创建 Issue。

一些可能的未来方向：
*   支持本地化部署的大语言模型（Ollama, Llama.cpp 等）。
*   为常见命令的输出增加缓存机制，以节省 API 调用。
*   增加更智能的触发策略，例如仅在命令失败或输出中包含特定错误模式时才自动解释。

## 📜 许可证

本项目采用 [MIT](https://opensource.org/licenses/MIT) 许可证。