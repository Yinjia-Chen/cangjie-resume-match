# 第二步：岗位模型与确定性匹配

2026-11-01。沿用仓颉 SDK 1.0.0、stdx 1.0.0.1、Docling 2.60.1，不新增依赖；放弃 Cangjie Magic DSL。第一步的 Magic 失败记录仅作历史说明，不再是当前工程阻断。

## 已实现

- `job_model.Requirement`：ID、四维类别、目标水平、是否必需、维度内权重；JSON 双向转换。
- `JobProfile`：默认技能 0.40、经验 0.35、学历 0.15、软素质 0.10；允许自定义，四维权重必须在 [0,1] 且总和为 1（浮点容差 1e-9），项权重在 (0,100]。
- `FrozenJob`：评估前以 revision 和完整 JSON 快照冻结；后续修改输入数组或读出的副本均不能修改已冻结配置，调权必须新建快照；同一排名必须使用相同 revision 和完整岗位快照。
- `resumeEvidence`：读取第一步 `structure` 输出的能力字段白名单，解析到原文、segment ID、来源引用、段落/页码/bbox；不读取姓名、性别、年龄等元数据；软素质仅接收行为事例，不能仅凭品质标签产生证据。
- `evaluate`：逐项调用语义接口，校验证据与结论，计算四维得分、总分、必需条件、覆盖率、优势、缺口、待核实项。
- `rank`：满足组 → 待核实组 → 不满足组；组内总分降序，相同分数保留输入顺序；拒绝重复候选 ID 和跨评估混排。
- `InterviewAgent`：仅方法签名，无实现。

## 评分与证据契约

维度分 = Σ(项权重 × 项得分) / Σ(该维度所有项权重)。总分 = Σ(维度权重 × 维度分)。每项和维度得分均为 0–100，总分也限制在 0–100；空维度计 0，标记 `has_requirements=false`，不向其他维度重新分配权重。岗位至少有一个要求，ID 不可重复。

项状态与得分约定：

| 状态 | 得分 | 证据 |
| --- | --- | --- |
| 满足 | 100 | 必须引用该维度的有效原文证据 |
| 不满足 | 0 ≤ 分数 < 100 | 必须引用该维度的有效原文证据；部分满足程度由未来适配器或人工固定量表给出 |
| 待核实 | 0 | 可无引用，也可保留不足以形成结论的原文引用 |

未知项仍保留在维度分母中，不计已满足。引用必须存在、属于对应维度且不重复，引用文本须与保存的来源文本一致。异常分值、矛盾状态、越界/重复引用或无证据的肯定/否定结论会抛错，不作为正常评分输出。

必需项中任一“不满足”则整组不满足，否则存在“待核实”则待核实，否则满足；没有必需项时该门槛视为满足，这不代表推荐面试。所有结果保留 `review_status=待人工复核`。未知不能被解释为能力不足。

证据覆盖率 = 有有效引用的要求项数量 / 全部要求项数量，不按权重计算、不按引用数量重复计算，也不等同于满足率；有引用但仍待核实的项可以贡献覆盖率，但贡献 0 分。

优势/缺口逐项保存岗位目标、状态、分数、原文及来源位置，理由使用固定模板，不由未接入的模型编造；未知项独立进入 `pending`。`candidate_id` 仅是外部匿名标识，用于定位结果和排除重复，不参与分数或并列破局。

证据校验保证引用结构和原文一致性，不证明语义结论被原文蕴含；HR 应只录入岗位能力要求，未来模型适配器仍需保证能力判断与原文相符，禁止把敏感属性包装成能力项。

## 调用流程

以下是库接口顺序，当前 CLI 仍只执行第一步的文档解析，不自动启动模型或批量匹配：

```text
JobProfile.fromJson(岗位 JSON)
  → FrozenJob(profile, evaluationRevision)
第一步结构化简历 JSON
  → resumeEvidence(resume)
  → evaluate(frozenJob, anonymousCandidateId, evidence, UnknownSemanticJudge())
  → rank(results)
  → result.toJson()
```

`FrozenJob.toJson/fromJson` 支持持久化评估配置。要求 JSON 示例：

```json
{
  "id": "frontend-1",
  "dimension_weights": {"skills": 0.4, "experience": 0.35, "education": 0.15, "soft_quality": 0.1},
  "requirements": [
    {"id": "s1", "dimension": "skills", "target_level": "熟练使用 JavaScript", "required": true, "weight": 1},
    {"id": "x1", "dimension": "experience", "target_level": "两年相关开发经历", "required": true, "weight": 1},
    {"id": "e1", "dimension": "education", "target_level": "本科", "required": false, "weight": 1},
    {"id": "b1", "dimension": "soft_quality", "target_level": "有跨团队协作的行为事例", "required": false, "weight": 1}
  ]
}
```

## 实测

运行 `bash validation/check_matching.sh`：

- `cjpm build` 成功（接口未使用参数及既有空模块有警告）。
- 48 项岗位/匹配断言通过：JSON 往返、冻结隔离、自定义权重、非法输入、未知计分、手算总分 72.5、证据覆盖率 0.75、组别优先于分数、稳定并列、必需失败优先、跨版本/权重混排拒绝、来源引用、人口属性元数据隔离。
- 第一阶段解析回归检查通过：分流、未知字段、技能归一、证据引用、软素质行为门槛。
- `otool -L target/matching-checks` 仅列出 stdx JSON、仓颉运行时、安全 C 库和系统库，不含 `lib-macro_magic`。

测试中的判断器和能力事例是合成输入，只用于确定性计算和契约验证，不代表真实语义匹配效果；本次未重跑 Docling 四格式解析或进行准确率评估。

## 仍为骨架

`UnknownSemanticJudge` 无论是否已有文本证据都返回待核实、零分、无引用；因此默认无优势或已证实缺口。第一步抽取仍为 `UnknownExtractor`，尚无模型输出解析/语义判断。相关经历年限区间合并、目标等级判定与固定语义量表仍待后续实现；本阶段不做关键词猜测或按文本臆断结论。面试生成、岗位录入 UI、完整运行编排及评估数据集均未展开。
