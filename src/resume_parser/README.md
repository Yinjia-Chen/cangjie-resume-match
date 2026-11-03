# 简历解析骨架

仓颉 `parseResume` 负责扩展名分流、独立工作目录、LibreOffice 转换、Docling 子进程调用、JSON 读取及结构化校验。Python 只解码文档，不承担业务抽取。

OCR 按平台选择：Mac 默认使用 Apple Vision / ocrmac，Linux 和 Windows WSL2 默认使用 Tesseract CLI（需安装 `eng`、`chi_sim` 语言数据）。可用 `RESUME_MATCH_OCR=tesseract` 显式选择；不同引擎结果可能不同，输出文档中的 `ocr_engine` 记录所选引擎。安装、环境检查与四格式回归见 [开发环境指南](../../docs/development.md)。

- 支持 `.pdf`、`.docx`、`.doc`、`.png/.jpg/.jpeg/.tif/.tiff/.bmp`；不支持的格式直接失败，扩展名不是内容真实性校验。
- 每次调用传入新的绝对 scratch 路径；失败返回非零退出码，不能继续当成有效简历。子进程等待上限 300 秒。
- `document.json` 保存文本片段、Docling 引用、段落序号及可获得的页码/bbox；段落序号是解析阅读顺序，不是 Word 原生段落索引。表格单元格保留表格级位置。
- `document.docling.json` 保存完整 Docling 输出；不直接交给 stdx 解析，避免其 Int64 限制无法读取 Docling 的 UInt64 文件哈希。
- `.doc` 保留 original_source 与转换标记；位置属于转换后的 DOCX，不承诺原 `.doc` 页码。
- `resume.json` 保存结构化结果；`Fact` 包含 `value` 与来源 segment ID。集合为空时 `status=未知`，字段为空时 `value=未知`；不把缺失解释为不具备。
- 工作经历保留起止字段（后续适配器输出 `YYYY-MM` 或 `至今`），项目保留职责和成果，学历保留学校/学历/专业，软素质必须有行为事例，并标记待面试核实。
- `StructuredExtractor` 是模型接入端口，当前 `UnknownExtractor` 不调用模型，所有业务集合未知。它不是已完成的信息抽取器；测试适配器仅验证结构契约。
- 同义词归一当前覆盖 JS/JavaScript、TS/TypeScript、Py/Python、Cangjie/仓颉，未知词保留原值。
- 当前校验非未知事实必须有有效来源 ID，软素质必须有行为字段；尚不验证模型事实是否由原文蕴含、日期合法性/区间重叠、OCR 置信度及复杂排版。所有输出保持 `needs_review`。

运行与版本详见 `docs/local-validation.md`；本阶段不接入匹配、面试、评分或 UI。
