
# 终端解释器 (Terminal Explainer)

还在为看不懂复杂的终端输出或难以理解的错误信息而烦恼吗？`Terminal Explainer` 将大语言模型（LLM）的强大威力直接带入您的命令行，一键解释任何命令的输出结果，并支持连续追问！

---

## ✨ 功能特性

-   **即时解释**：在任何您想执行的命令前加上 `ex`，即可在看到命令输出后，立即获得 AI 的逐项解释。
-   **分析上一条**：如果您忘记在命令前加 `ex`，只需直接输入 `ex`，工具会自动分析上一条命令及其输出。
-   **智能追问**：使用 `ex -c "你的问题"` 对上一次的分析结果进行追问，AI 会结合完整的对话历史来回答，实现多轮对话。
-   **错误诊断**：当命令执行失败时，AI 会分析错误信息，指出问题根源并提供可能的解决方案。
-   **常开模式**：通过 `ex -turnon` 开启“自动分析”，无需再手动输入 `ex`。每条命令执行后都会自动分析。使用 `ex -turnoff` 可随时关闭。
-   **超长输出保护**：当命令输出超过一万个字符时，自动截断，只将核心部分上传分析，为您节省 Token 和费用。
-   **高度可配置**：支持通过配置文件 `config.ini` 自定义 API Key、API End-point 和使用的模型。
-   **安装/卸载便捷**：提供一键式 `install.sh` 和 `uninstall.sh` 脚本，自动处理依赖和环境配置。
-   **广泛兼容**：完美支持 `bash` 和 `zsh`。

## 🚀 安装

安装过程非常简单，仅需两步。

#### 依赖项
在安装前，请确保您的系统（如 Ubuntu/Debian）已安装 `git`, `python3`, 和 `python3-pip`。

```bash
sudo apt update
sudo apt install git python3 python3-pip
```

#### 安装步骤
1.  首先，克隆本仓库到您的本地机器：
    ```bash
    git clone https://github.com/leezehuan/terminal-explainer.git
    ```

2.  进入项目目录，并使用 `sudo` 运行安装脚本：
    ```bash
    cd terminal-explainer
    sudo ./install.sh
    ```
    安装脚本会自动将核心程序安装到系统目录，并为您自动配置好 shell 环境。

## ⚙️ 配置

**安装后，最重要的一步是配置您的 API Key。**

安装脚本会在您的家目录下创建一份配置文件，位于：`~/.config/terminal-explainer/config.ini`。

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
model = gpt-4o
```

> **密钥优先级**：您也可以通过设置环境变量 `OPENAI_API_KEY` 来提供 API 密钥，它的优先级高于配置文件。

配置完成后，**请务必重启您的终端**，或运行 `source ~/.bashrc` (或 `source ~/.zshrc`) 使配置生效。

## 💡 使用方法

#### 示例 1: 解释一个任意命令
只需在您要执行的命令前加上 `ex` 即可。

```bash
ex ls -la
```
您会先看到 `ls -la` 的正常输出，紧接着下方就会出现 AI 对输出内容的逐项解释。

#### 示例 2: 分析上一条命令
如果您刚刚执行完一条命令，希望回过头来再看一下解释，只需直接输入：

```bash
# 首先执行一个命令
docker ps -a

# 然后请求分析
ex
```
工具会自动找到上一条执行的 `docker ps -a` 及其完整输出，并进行分析。

#### 示例 3: 智能追问
在得到 AI 的解释后，您可能还有疑问。这时可以使用 `ex -c` 进行追问。

```bash
# 场景：分析完 ls -la 后
ex

# ... AI 给出了解释 ...

# 用户对解释中的“硬链接数”感到好奇，于是追问
ex -c "第二列的硬链接数是什么意思？为什么目录的链接数不是1？"
```
AI 会理解这是在问关于 `ls -la` 输出的问题，并给出针对性的回答。您可以连续使用 `ex -c` 进行多轮追问。

#### 示例 4: 开启/关闭“常开模式”
如果您希望每条命令执行后都自动进行分析，可以开启此模式：

```bash
ex -turnon
```
开启后，您无需再输入 `ex`，每条命令（除了 `ex` 相关命令本身）执行完成后都会自动触发分析。此设置在当前 shell 会话中永久有效。

若需关闭，可执行：
```bash
ex -turnoff
```

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