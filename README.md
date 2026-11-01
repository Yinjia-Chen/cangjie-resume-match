# 基于仓颉语言的招聘简历筛选与智能匹配系统

首选仓库名：`cangjie-resume-match`。

本仓库已完成解析骨架、岗位模型和仓颉加权评分；结构化抽取与语义判断尚未接入模型。
采用仓颉结构体、普通接口和 JSON，不依赖 Cangjie Magic DSL；不引入向量库或消息队列。

## 模块

| 目录 | 职责 | 对应任务 |
| --- | --- | --- |
| src/resume_parser/ | 多格式简历解析、结构化信息抽取和证据保留 | ① |
| src/job_model/ | 技能、经验、学历、软素质四维岗位建模 | ② |
| src/matching_agent/ | 多维匹配、评分、排序和推荐理由 | ③④ |
| src/interview_agent/ | 个性化面试题、追问和考察要点 | ⑤ |
| src/results_evaluation/ | 结果展示、人工标注录入和评估报告 | ⑥及操作入口 |

## 数据流

简历文件 → 文本及来源位置 → 简历结构化数据。

岗位描述 → 四维岗位要求 → HR 确认。

结构化简历 + 岗位要求 → 匹配 Agent → 仓颉计算分数与排序 → 推荐结果 → 按需生成面试题。

人工筛选结果 + 系统输出 → 评估模块 → 对比报告。

## 文档与数据

- [完整技术方案](docs/technical-solution.md)
- [第二步实现与验证](docs/matching-implementation.md)
- [样例输入说明](data/README.md)
- [评估说明](evaluation/README.md)

版本、运行命令与实测边界见 [本地验证报告](docs/local-validation.md)，解析契约见 [解析模块说明](src/resume_parser/README.md)。
