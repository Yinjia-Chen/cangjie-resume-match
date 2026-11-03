# 开发环境配置

本指南用于从 GitHub 全新克隆后配置当前仓颉工程。安装入口为 `scripts/setup.py`，环境检查与回归入口为 `scripts/check.sh`。SDK、stdx 与虚拟环境安装到仓库的 `.tools/`、`.venv/`，不需要复制其他人的绝对路径，也不修改全局 shell 配置。

## 平台与功能范围

| 开发环境 | 仓颉工具链 | OCR | 配置方式 |
| --- | --- | --- | --- |
| Apple Silicon Mac，macOS 14 或以上 | mac-aarch64 SDK | Apple Vision / ocrmac | 原生终端 |
| Ubuntu 22.04 / 24.04，x86_64 或 aarch64 | 对应 Linux SDK | Tesseract CLI，简体中文及英文 | 原生 Linux 终端 |
| Windows 10/11 | WSL2 内的 Linux SDK | WSL2 内的 Tesseract CLI | Ubuntu + VS Code WSL |

Windows 按 WSL2 路线使用完整解析和评分链路，不混用 Windows Python、SDK 或 LibreOffice。原生 PowerShell 工具链及 Intel Mac不在本次配置范围内。Linux/WSL2 与 Mac 使用不同 OCR 引擎，识别结果可能不同，准确率实验应记录操作系统和 OCR 引擎。

当前可运行的是多格式文档解析、岗位模型及确定性评分校验。结构化模型抽取、语义匹配、面试生成、Sites 前端、Worker 和隧道仍按 [总体规划](overall-plan.md) 开发，尚无相关服务代码或可填写的有效服务凭证；安装开发环境不会使这些未实现功能自动可用。

## 固定版本与下载来源

- Python：`.python-version` 中的 **3.14.7**。
- 仓颉 SDK：**1.0.0**；各平台官方地址及 SHA-256 在 `toolchain.lock.json`。
- stdx：**1.0.0.1**。旧公开二进制下载地址目前不可用，新安装从官方镜像仓库的固定源码提交 `1b3a36675d6817c7c972d8326d397c18bbebe8f7` 构建本工程用到的 `stdx.serialization.serialization` 与 `stdx.encoding.json`，包含 JSON 的 C FFI；无需 CMake、Magic 或额外业务框架。源码压缩包有 SHA-256 校验，许可证复制到本地工具目录。
- Python 包：`requirements.lock` 精确固定；Apple 专属包使用平台条件，Linux 不安装 PyObjC/ocrmac。Linux 先安装同版本 PyTorch CPU wheel，避免下载 CUDA 运行库；`+cpu` 是相同公开版本的 CPU 构建标识。
- 模型：布局模型固定 revision；表格模型沿用 Docling 的 `v2.3.0` 标签，锁文件保留历史观察到的 commit，尚未把该标签改成不可变提交。首次完整验证需要联网下载模型，模型缓存不提交到 Git。

安装脚本先校验下载包，再解压与编译；遇到错误立即停止，不自动降级版本。已有匹配版本的 SDK/stdx 可复用；强制重建所需 stdx 包使用 `--rebuild-stdx`。锁文件中的原 Mac 二进制 SHA-256 是历史安装包记录，不用于校验新编译的源码产物。

Mac 的源码构建通过链接参数 `-no_data_const` 兼容现代 dyld，并设置 `@rpath` 安装名；Linux 设置库的 SONAME，避免产物依赖临时构建目录。不会修改或二进制修补 SDK。

## 1 安装系统前置依赖

### Mac

先安装 Xcode Command Line Tools；首次安装按系统提示完成后再继续：

```bash
xcode-select --install
```

安装 Homebrew 后，在终端执行：

```bash
brew install libffi uv
brew install --cask libreoffice
uv python install 3.14.7
```

如果已有 LibreOffice，可直接复用，或通过 `SOFFICE_BIN` 指向可执行文件。解析工作不依赖 Codex 自带的运行环境。

### Windows

在管理员 PowerShell 中安装 WSL2 Ubuntu，按提示重启并创建 Linux 用户：

```powershell
wsl --install -d Ubuntu-24.04
wsl --list --verbose
```

确认 Ubuntu 的版本列为 `2`。此后所有安装、Git、Python 和仓颉命令都在 Ubuntu 终端内执行。建议把项目克隆到 Linux 用户目录，避免放在 `/mnt/c/`；编辑器使用 VS Code 的 WSL 扩展打开同一目录。

### Linux 与 WSL2 Ubuntu

```bash
sudo apt-get update
sudo apt-get install -y build-essential curl git ca-certificates libffi-dev libssl-dev \
  libreoffice-writer tesseract-ocr tesseract-ocr-eng tesseract-ocr-chi-sim fonts-dejavu-core
```

按 [uv 官方安装说明](https://docs.astral.sh/uv/getting-started/installation/) 安装 uv，重新打开终端或按安装器提示更新当前 PATH 后执行：

```bash
uv python install 3.14.7
```

已有 Python 3.14.7 时可直接使用该解释器，无需 uv。当前锁定的科学计算 wheel 要求较新的系统；不要用 Alpine/musl 或未经验证的旧发行版替换上述 Ubuntu 基线。

## 2 克隆与安装

```bash
git clone https://github.com/Yinjia-Chen/cangjie-resume-match.git
cd cangjie-resume-match
uv run --no-project --python 3.14.7 python scripts/setup.py
```

没有 uv、但已有 Python 3.14.7：

```bash
python3.14 scripts/setup.py
```

安装过程包括 SDK 下载、stdx 构建、创建 `.venv`、安装锁定依赖和 `pip check`。需要能访问仓颉官网、GitHub/PyPI；Linux 还需要 PyTorch CPU wheel 源。SDK 下载超过 200 MB，首次 Python 及模型安装也需要预留网络和磁盘空间。

安装脚本不会自动执行 sudo 或安装操作系统软件。若现有 `.venv` 的 Python 版本不一致，先重命名旧目录再重建；不要跨操作系统复制 `.venv` 或 `.tools`。

## 3 配置当前终端并验证

```bash
source scripts/env.sh
bash scripts/check.sh --full
```

`env.sh` 支持 bash/zsh，自动选择本平台 stdx 目录及动态库变量，检测 LibreOffice。每次打开新终端后重新 source 即可；无需编辑全局 `.bashrc`、`.zshrc`。

完整验证依次执行：

1. Python、包版本、SDK、stdx、LibreOffice 和 OCR 前置条件检查。
2. 仓颉构建、48 项匹配断言及解析契约回归。
3. OCR 配置分流测试。
4. 生成不含个人信息的 DOCX、PDF、图片及旧 DOC 样例。
5. 实际运行“仓颉 → Docling/OCR → JSON”四格式解析，检查文本和来源位置。

生成文件在 `validation/output/`，构建文件在 `target/`，均已忽略。完整验证会实际下载缺少的模型权重；完成后，可验证 Hugging Face 模型缓存可离线复用：

```bash
HF_HUB_OFFLINE=1 bash scripts/check.sh --full
```

仅开发岗位模型、评分逻辑，暂时不安装 Python 大模型依赖或文档工具时：

```bash
uv run --no-project --python 3.14.7 python scripts/setup.py --core-only
source scripts/env.sh
bash scripts/check.sh --core-only
```

`--core-only` 不代表 PDF/Word/OCR 环境已就绪。GitHub Actions 中的环境验证使用相同安装与检查入口；WSL2 仍需在实际目标机器执行完整检查，不能把 Linux runner 的成功视为所有 Windows 配置均已验收。

## 4 解析自己的文件

先执行上述完整验证，再使用绝对路径和一个尚不存在的工作目录：

```bash
source scripts/env.sh
cjpm build
target/release/bin/main /absolute/resume.pdf /absolute/new-scratch \
  "$RESUME_MATCH_ROOT/.venv/bin/python" \
  "$RESUME_MATCH_ROOT/src/resume_parser/docling_bridge.py" "$SOFFICE_BIN"
```

结果位于工作目录的 `resume.json`。当前模型抽取仍是 `UnknownExtractor`，返回未知和 `needs_review` 是当前实现的预期行为；不是完整的智能匹配结论。

## 常用配置与排查

| 配置或现象 | 处理 |
| --- | --- |
| `SOFFICE_BIN` | 指向本系统的 LibreOffice 可执行文件；路径有空格时加引号，例如 `export SOFFICE_BIN="/Applications/LibreOffice.app/Contents/MacOS/soffice"` |
| `RESUME_MATCH_OCR` | 默认 `auto`：Mac 用 `ocrmac`，Linux/WSL2 用 `tesseract`；可在安装 Tesseract 后显式设为 `tesseract`，其他值报错 |
| Tesseract 找不到语言数据 | `tesseract --list-langs` 应包含 `eng` 和 `chi_sim`，补装相应 Ubuntu 软件包；如自行设置 `TESSDATA_PREFIX`，确认其指向实际语言目录 |
| 找不到 stdx 或动态库 | 在项目目录重新 `source scripts/env.sh`，不要复用其他平台的 `.tools`；运行 `scripts/setup.py --rebuild-stdx` 后重新构建 |
| SDK 下载、哈希或包解析失败 | 检查网络，保留锁定版本；可预先将对应安装包放入 `.tools/downloads/`，文件名见脚本，脚本仍会验证 SHA-256 |
| macOS 阻止 SDK 可执行文件 | 确认安装来源与校验值；setup 下载后会清除项目 SDK 的 quarantine 属性，手工安装的包应按官方指南处理 |
| `pip` 找不到锁定版本 | 检查 Python、架构、PyPI/CPU wheel 源及代理；不要直接升级整个依赖集，先保留具体错误 |
| 首次 PDF/OCR 超时或模型缺失 | 先联网运行 `--full`，确认模型下载完成；离线前再跑一次带 `HF_HUB_OFFLINE=1` 的完整检查 |

大模型 API 及网页服务配置待功能接入时再定义。密钥放在本地未跟踪配置或服务端环境变量，不写进报告、源码或 Git。不要把本项目后续服务的“尚未实现”误诊为开发环境安装失败。

## 官方资料

- [仓颉 1.0.0 下载与校验](https://cangjie-lang.cn/download/1.0.0)
- [仓颉工具链安装](https://docs.cangjie-lang.cn/en/docs/1.0.0/user_manual/source_en/first_understanding/install_Community.html)
- [stdx 固定源码](https://github.com/cangjielanguage/cangjie_stdx/tree/1b3a36675d6817c7c972d8326d397c18bbebe8f7)
- [Docling 安装与 OCR](https://docling-project.github.io/docling/getting_started/installation/)
- [Microsoft WSL 安装](https://learn.microsoft.com/en-us/windows/wsl/install)
