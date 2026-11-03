# 第一步本地验证报告

日期：2026-11-01（Asia/Shanghai）。机器：macOS 15.7.1（24G231）、Apple Silicon arm64。
仅使用本地生成的合成样例，无真实简历或大模型 API 调用。

**新机器安装入口：** 本文保留第一阶段历史记录；当前安装与验证统一使用 [开发环境指南](development.md)。当前工程不需要安装或构建 Magic。Linux/WSL2 使用 Tesseract CLI，当前所需 stdx 包可由固定源码构建。

**第二步更新：**下文 Magic 测试是第一步历史记录；当前已弃用 Magic，已从活动版本锁移除，不依赖 `lib-macro_magic`。当前方案见 [第二步实现说明](matching-implementation.md)。

## 结论

| 项目 | 实测结果 | 范围 / 限制 |
| --- | --- | --- |
| 仓颉 SDK | 通过 | `cjc/cjpm --version` 为 1.0.0，解析模块 `cjpm build` 成功 |
| Agent DSL / Magic | **阻断** | 固定 commit 的 `cjpm build` 在加载 `lib-macro_magic.dsl.dylib` 时失败：`__DATA_CONST segment missing SG_READ_ONLY flag`；不能宣称 DSL 可用或能生成 JSON |
| Docling DOCX | 通过 | 中英文 7 个文本片段，JSON 可读，保留来源引用与阅读顺序；无可用原生页码 |
| Docling PDF | 通过 | 文本型单页 PDF 生成 JSON，2 个片段，带页码/bbox；尚未验证扫描 PDF、复杂表格、多页布局 |
| Docling 图片 OCR | 通过（需复核） | PNG 英文 OCR 生成 6 个片段，带位置；`API` 误识别为 `APl`，未验证中文图片准确率 |
| 旧 `.doc → .docx` | 通过 | LibreOfficeDev 无界面转换后，Docling 输出 7 个片段，中英文文本保留；测试 `.doc` 由 DOCX 合成，不代表所有历史 Word 文件 |
| 仓颉调用命令并读取 JSON | 通过 | 四种格式全部贯通：仓颉 → 命令行工具 → 精简 JSON → stdx 读取 → `resume.json` |
| 抽取骨架 | 通过结构检查 | 格式分流、未知值、同义词归一、证据引用、软素质行为门槛；没有调用抽取模型，不能宣称业务抽取准确率 |

Magic 使用官方 `docs/install.md` 要求的 1.0.0 基线而非最新 SDK。尝试添加 `-B /usr/bin` 后仍出现相同宏库加载错误，验证 checkout 已恢复原配置；未修改或二进制修补 SDK / Magic。该组合只能作为**已锁定的验证基线**，不能作为已验证可运行的 Agent 依赖。

Docling 原始 JSON 的 `origin.binary_hash=9885280710229059644` 超出 stdx 此版本的 Int64 解析范围。现保留完整 `document.docling.json`，仓颉仅读取不含该字段的 `document.json`；并非删掉原始证据。

## 锁定版本

精确工具版本与下载包哈希见根目录 `toolchain.lock.json`；Python 全部直接/传递依赖精确版本见 `requirements.lock`（`pip check` 通过）。

| 组件 | 锁定值 |
| --- | --- |
| Cangjie SDK / cjpm | 1.0.0 / mac-aarch64；SDK SHA-256 已与官网核对 |
| stdx | 1.0.0.1 / mac-aarch64；下载包 SHA-256 已记录 |
| Cangjie Magic | manifest 1.0.0，commit `bc4624fac86ad8498b61d7e5f3b1168659bc72b5`（编译阻断） |
| Python | 3.14.7 |
| Docling | 2.60.1 |
| docling-core / docling-parse / docling-ibm-models | 2.105.0 / 4.7.3 / 3.15.0 |
| ocrmac / OpenCV headless | 1.0.1 / 5.0.0.93 |
| torch / transformers | 2.15.0 / 4.57.6 |
| 布局模型 | `ds4sd/docling-layout-heron@8f39ad3c0b4c58e9c2d2c84a38465abf757272d8`，桥接代码固定 revision |
| 表格模型 | Docling 固定 `ds4sd/docling-models@v2.3.0`，本次解析到 `fc0f2d45e2218ea24bce5045f58a389aed16dc23`（记录哈希，未额外强制校验远端 tag） |
| OCR 引擎 | Apple Vision，语言配置 `zh-Hans,en-US`；依赖系统版本 |
| `.doc` 转换 | LibreOfficeDev 26.8.0.0.alpha0，build `2c87e51eeaa2b413ff4ae097b2705eea1995d8e5`；使用机器现有工具，非稳定版兼容承诺 |

本地 SDK 和 stdx 在 `.tools/`，Python 环境在 `.venv/`，模型在 Hugging Face 本地缓存。依赖/生成产物均被 `.gitignore` 排除。首次下载模型需要网络，解析不调用远端推理服务。最终以 `HF_HUB_OFFLINE=1` 重跑四种格式全部通过，验证了模型缓存齐全时的离线 Hugging Face 运行。

## 复现

当前环境可直接执行（仓库根目录，bash/zsh）：

```bash
source .tools/cangjie/envsetup.sh
export DYLD_LIBRARY_PATH="$PWD/.tools/stdx/darwin_aarch64_llvm/dynamic/stdx:$DYLD_LIBRARY_PATH"
cjpm build
.venv/bin/python validation/make_fixtures.py
soffice --headless '-env:UserInstallation=file:///tmp/resume-lo-validation' --convert-to 'doc:MS Word 97' --outdir validation/output validation/output/sample.docx
HF_HUB_OFFLINE=1 .venv/bin/python validation/verify.py
cjc src/resume_parser/*.cj validation/parser_checks.cj --import-path .tools/stdx/darwin_aarch64_llvm/dynamic/stdx -L .tools/stdx/darwin_aarch64_llvm/dynamic/stdx -lstdx.encoding.json -o target/parser-checks
target/parser-checks
```

`verify.py` 使用全新临时目录调用仓颉程序，检查四种格式的关键文本、来源位置、未知状态、退出码以及有效 JSON；结果保留在 `validation/output/results.json` 和 `verified-{docx,pdf,png,doc}/`。内部路径记录当时临时目录，目录清理后请在对应 `verified-*` 下查看复制的证据文件。

单文件入口：

```bash
target/release/bin/main /absolute/resume.docx /absolute/new-scratch "$PWD/.venv/bin/python" "$PWD/src/resume_parser/docling_bridge.py" "$(command -v soffice)"
```

输出为 scratch 下的 `resume.json`，退出码 0 只表示文档解析及骨架序列化成功；业务字段仍未知、总状态仍为 `needs_review`。损坏文件、无文本、工具失败或抽取校验异常均不可当作成功结果。OCR 质量尚无自动评分，默认人工复核。

新机器按 [开发环境指南](development.md) 安装，不需要重现上述 Magic 历史验证。SDK 与 stdx 源码下载和校验、依赖安装由 `scripts/setup.py` 处理，完整回归使用 `bash scripts/check.sh --full`。

## 依据

- [仓颉 SDK 1.0.0 官方下载](https://cangjie-lang.cn/download/1.0.0)。
- [Magic 固定版本安装说明](https://gitcode.com/Cangjie-TPC/CangjieMagic/blob/bc4624fac86ad8498b61d7e5f3b1168659bc72b5/docs/install.md)。
- [stdx 官方仓库](https://github.com/cangjielanguage/cangjie_stdx)。
- [Docling 官方支持格式](https://docling-project.github.io/docling/usage/supported_formats/)与[安装说明](https://docling-project.github.io/docling/getting_started/installation/)。

以上官方资料用于定位安装和接口，表中“通过”以本次本机执行为依据，不等同于完整系统或真实简历验收。
