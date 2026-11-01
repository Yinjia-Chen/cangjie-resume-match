package matching_checks

import resume_match.job_model.*
import resume_match.matching_agent.*
import resume_match.resume_parser.*
import stdx.encoding.json.*

var checks: Int64 = 0
func check(ok: Bool, label: String): Unit {
    if (!ok) { throw Exception("FAIL: ${label}") }
    checks++
}
func close(a: Float64, b: Float64): Bool { a-b < 0.000001 && b-a < 0.000001 }
func rejects(action: () -> Unit, label: String): Unit {
    var failed = false
    try { action() } catch (_: Exception) { failed = true }
    check(failed, label)
}
class Scores <: SemanticJudge {
    let scores: Array<Float64>
    init(scores: Array<Float64>) { this.scores = scores }
    public func judge(r: Requirement, evidence: Array<CapabilityEvidence>): Judgment {
        let s = scores[dimensionIndex(r.dimension)]
        if (s < 0.0) { return Judgment() }
        return Judgment(state: if (s == 100.0) { "满足" } else { "不满足" }, score: s, evidenceIds: [evidence[0].id])
    }
}
class Ambiguous <: SemanticJudge {
    public func judge(r: Requirement, evidence: Array<CapabilityEvidence>): Judgment {
        Judgment(evidenceIds: [evidence[0].id])
    }
}
class Bad <: SemanticJudge {
    let decision: Judgment
    init(decision: Judgment) { this.decision = decision }
    public func judge(r: Requirement, evidence: Array<CapabilityEvidence>): Judgment { decision }
}
class SkillOnly <: SemanticJudge {
    public func judge(r: Requirement, evidence: Array<CapabilityEvidence>): Judgment {
        if (r.id == "s") { return Judgment(state: "满足", score: 100.0, evidenceIds: ["skills"]) }
        return Judgment()
    }
}
class Extracted <: StructuredExtractor {
    public func extract(document: JsonObject): ResumeDraft {
        ResumeDraft(skills: [Fact(value: "JS", evidence: ["s1"])])
    }
}

main(): Int64 {
    let requirements = [Requirement("s", "skills", "JavaScript 熟练", required: true),
        Requirement("x", "experience", "相关开发两年"), Requirement("e", "education", "本科"),
        Requirement("b", "soft_quality", "有跨团队协作事例")]
    let weights = [0.4, 0.35, 0.15, 0.1]
    let profile = JobProfile("job-1", requirements, weights: weights)
    let frozen = FrozenJob(profile, "evaluation-1")
    weights[0] = 1.0
    check(close(frozen.snapshot().weights[0], 0.4), "frozen weights detached from input")
    let copy = frozen.snapshot(); copy.weights[0] = 0.0
    check(close(frozen.snapshot().weights[0], 0.4), "snapshot cannot mutate frozen job")
    check(FrozenJob.fromJson(frozen.toJson()).toJson().toJsonString() == frozen.toJson().toJsonString(), "JSON round trip")
    rejects({ => JobProfile("bad", requirements, weights: [0.4,0.35,0.15,0.2]); () }, "weight sum")
    rejects({ => JobProfile("bad", requirements, weights: [1.1,-0.1,0.0,0.0]); () }, "negative weights")
    rejects({ => JobProfile("bad", []); () }, "empty requirements")
    rejects({ => JobProfile("bad", [requirements[0],requirements[0]]); () }, "duplicate requirements")
    rejects({ => Requirement("bad", "age", "30岁以下"); () }, "non-capability dimension")
    rejects({ => Requirement("bad", "skills", "JS", weight: 0.0); () }, "zero item weight")
    rejects({ => FrozenJob(frozen.snapshot(), ""); () }, "missing evaluation revision")
    let evidence = Array<CapabilityEvidence>(4, {i =>
        let s = JsonObject(); s.put("source_ref", JsonString("#/texts/${i}"))
        s.put("text", JsonString("synthetic capability ${i}")); s.put("paragraph", JsonInt(i+1))
        CapabilityEvidence(dimensions()[i], dimensions()[i], "capability ${i}", "synthetic capability ${i}", s)
    })
    let unknown = evaluate(frozen, "unknown", evidence, UnknownSemanticJudge()).toJson()
    check(number(unknown["total_score"]) == 0.0, "unknown score zero")
    check(number(unknown["evidence_coverage"]) == 0.0, "unknown coverage zero")
    check(unknown["mandatory_status"].asString().getValue() == "待核实", "unknown mandatory")
    check(unknown["strengths"].asArray().size() == 0 && unknown["gaps"].asArray().size() == 0, "no fictional conclusion")
    check(unknown["pending"].asArray().size() == 4, "all requirements pending")
    let ambiguous = evaluate(frozen,"ambiguous",evidence,Ambiguous()).toJson()
    check(number(ambiguous["evidence_coverage"]) == 1.0 && number(ambiguous["total_score"]) == 0.0, "cited but inconclusive evidence earns no score")
    check(ambiguous["mandatory_status"].asString().getValue() == "待核实", "ambiguous requirement remains pending")
    let mixed = evaluate(frozen, "mixed", evidence, Scores([100.0,50.0,100.0,-1.0]))
    let mj = mixed.toJson()
    check(close(number(mj["total_score"]), 72.5), "weighted total 72.5")
    check(number(mj["evidence_coverage"]) == 0.75, "coverage includes cited negative finding")
    check(mj["strengths"].asArray().size() == 2 && mj["gaps"].asArray().size() == 1, "strengths and gaps")
    check(mj["gaps"].asArray()[0].asObject()["evidence"].asArray()[0].asObject()["quote"].asString().getValue() == "synthetic capability 1", "gap quotes source")
    let low = evaluate(frozen, "low", evidence, Scores([100.0,-1.0,-1.0,-1.0]))
    let high = evaluate(frozen, "high", evidence, Scores([100.0,100.0,100.0,100.0]))
    let pending = evaluate(frozen, "pending", evidence, Scores([-1.0,100.0,100.0,100.0]))
    let failed = evaluate(frozen, "failed", evidence, Scores([0.0,100.0,100.0,100.0]))
    let sorted = rank([failed,pending,low,mixed,high])
    for ((i, id) in [(0,"high"),(1,"mixed"),(2,"low"),(3,"pending"),(4,"failed")]) {
        check(sorted[i].toJson()["candidate_id"].asString().getValue() == id, "mandatory group then total")
    }
    let twin = evaluate(frozen, "twin", evidence, Scores([100.0,-1.0,-1.0,-1.0]))
    check(rank([twin,low])[0].toJson()["candidate_id"].asString().getValue() == "twin", "stable score ties")
    check(rank([]).isEmpty(), "empty ranking")
    rejects({ => rank([low,low]); () }, "duplicate candidates")
    let other = evaluate(FrozenJob(frozen.snapshot(), "evaluation-2"), "other", evidence, UnknownSemanticJudge())
    rejects({ => rank([other,low]); () }, "different frozen revisions")
    let changed = evaluate(FrozenJob(JobProfile("job-1",requirements,weights:[1.0,0.0,0.0,0.0]),"evaluation-1"),"changed",evidence,UnknownSemanticJudge())
    rejects({ => rank([changed,low]); () }, "different weights with same revision")
    let requiredBoth = FrozenJob(JobProfile("both",[Requirement("s","skills","JS",required:true),Requirement("x","experience","两年",required:true)]),"v1")
    check(evaluate(requiredBoth,"both",evidence,Scores([0.0,-1.0,-1.0,-1.0])).toJson()["mandatory_status"].asString().getValue() == "不满足", "mandatory failure takes precedence over pending")
    let weightedJob = FrozenJob(JobProfile("weighted", [Requirement("s","skills","JS",weight:3.0),
        Requirement("s2","skills","Python",weight:1.0)]), "v1")
    check(close(number(evaluate(weightedJob,"weighted",evidence,SkillOnly()).toJson()["total_score"]),30.0), "unknown retained in item denominator; empty dimensions zero")
    let custom = FrozenJob(JobProfile("custom",requirements,weights:[1.0,0.0,0.0,0.0]),"v1")
    check(number(evaluate(custom,"custom",evidence,Scores([100.0,0.0,0.0,0.0])).toJson()["total_score"]) == 100.0, "custom dimension weights")
    for (bad in [Judgment(state:"满足",score:101.0,evidenceIds:["skills"]),
        Judgment(state:"满足",score:100.0), Judgment(state:"满足",score:100.0,evidenceIds:["missing"]),
        Judgment(state:"满足",score:100.0,evidenceIds:["education"]),
        Judgment(state:"待核实",score:1.0), Judgment(state:"不满足",score:100.0,evidenceIds:["skills"]),
        Judgment(state:"满足",score:100.0,evidenceIds:["skills","skills"]), Judgment(state:"invented")]) {
        rejects({ => evaluate(frozen,"invalid",evidence,Bad(bad)); () }, "invalid judgment/citation rejected")
    }
    rejects({ => evaluate(frozen,"duplicate",[evidence[0],evidence[0]],UnknownSemanticJudge()); () }, "duplicate evidence")
    let source = JsonValue.fromStr("{\"segments\":[{\"id\":\"s1\",\"text\":\"Used JS\",\"source_ref\":\"#/texts/0\",\"paragraph\":1}]}").asObject()
    let parsed = structure(source,Extracted())
    parsed.put("name",JsonString("任何姓名")); parsed.put("sex",JsonString("任何性别")); parsed.put("age",JsonInt(99))
    let facts = resumeEvidence(parsed)
    check(facts.size == 1 && facts[0].value == "JavaScript", "resume adapter reads only capabilities")
    check(facts[0].toJson()["quote"].asString().getValue() == "Used JS", "resume source preserved")
    let before = evaluate(frozen,"anon",facts,UnknownSemanticJudge()).toJson().toJsonString()
    parsed.put("name",JsonString("其他姓名")); parsed.put("sex",JsonString("其他性别")); parsed.put("age",JsonInt(18))
    check(before == evaluate(frozen,"anon",resumeEvidence(parsed),UnknownSemanticJudge()).toJson().toJsonString(), "demographic metadata has no effect")
    check(resumeEvidence(structure(source,UnknownExtractor())).isEmpty(), "unknown extraction yields no facts")
    source["segments"].asArray()[0].asObject().put("id",JsonString("changed"))
    rejects({ => resumeEvidence(parsed); () }, "dangling resume citation")
    println("PASS: ${checks} matching/job assertions")
    return 0
}
