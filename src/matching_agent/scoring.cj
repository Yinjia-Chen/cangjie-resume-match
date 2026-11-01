package resume_match.matching_agent

import resume_match.job_model.*
import std.collection.*
import stdx.encoding.json.*

public func evaluate(job: FrozenJob, candidateId: String, evidence: Array<CapabilityEvidence>, judge: SemanticJudge): MatchResult {
    if (candidateId.trimAscii().isEmpty()) { throw Exception("Opaque candidate ID required") }
    let profile = job.snapshot()
    let evidenceIds = HashSet<String>()
    for (e in evidence) {
        if (evidenceIds.contains(e.id)) { throw Exception("Duplicate evidence ID") }
        evidenceIds.add(e.id)
    }
    let weighted = [0.0, 0.0, 0.0, 0.0]; let denominators = [0.0, 0.0, 0.0, 0.0]
    let items = JsonArray(); let strengths = JsonArray(); let gaps = JsonArray(); let pending = JsonArray()
    var covered: Int64 = 0
    var requiredFailed = false; var requiredPending = false
    for (r in profile.requirements) {
        let relevant = ArrayList<CapabilityEvidence>()
        for (e in evidence) { if (e.dimension == r.dimension) { relevant.add(e) } }
        let decision = judge.judge(r, relevant.toArray())
        if (!(decision.score >= 0.0 && decision.score <= 100.0)) { throw Exception("Score outside [0,100]") }
        if (decision.state != "满足" && decision.state != "不满足" && decision.state != "待核实") {
            throw Exception("Invalid requirement state")
        }
        if ((decision.state == "满足" && decision.score != 100.0) ||
            (decision.state == "不满足" && decision.score >= 100.0) ||
            (decision.state == "待核实" && decision.score != 0.0)) {
            throw Exception("Contradictory judgment")
        }
        let citations = JsonArray(); let used = HashSet<String>()
        for (id in decision.evidenceIds) {
            if (used.contains(id)) { throw Exception("Duplicate citation") }
            used.add(id)
            var found = false
            for (e in relevant) {
                if (e.id == id) { citations.add(e.toJson()); found = true }
            }
            if (!found) { throw Exception("Missing or cross-dimension evidence: ${id}") }
        }
        if (decision.state != "待核实" && citations.size() == 0) { throw Exception("Known conclusion requires resume evidence") }
        if (citations.size() > 0) { covered++ }
        let d = dimensionIndex(r.dimension)
        denominators[d] += r.weight
        weighted[d] += r.weight * decision.score // Unknown stays in denominator, contributes zero.
        if (r.required && decision.state == "不满足") { requiredFailed = true }
        if (r.required && decision.state == "待核实") { requiredPending = true }
        let item = JsonObject()
        item.put("requirement_id", JsonString(r.id)); item.put("dimension", JsonString(r.dimension))
        item.put("target_level", JsonString(r.target)); item.put("required", JsonBool(r.required))
        item.put("status", JsonString(decision.state)); item.put("score", JsonFloat(decision.score))
        item.put("evidence", citations)
        let reason = if (decision.state == "待核实") { "未知：尚无经证据支持的判断；不能视为满足或能力不足" }
            else if (decision.state == "满足") { "优势：该要求判为满足，依据见引用原文" }
            else { "缺口：该要求判为不满足，依据见引用原文；需人工复核" }
        item.put("reason", JsonString(reason))
        items.add(item)
        if (decision.state == "满足") { strengths.add(item) }
        else if (decision.state == "不满足") { gaps.add(item) }
        else { pending.add(item) }
    }
    var total = 0.0
    let scores = JsonObject()
    for (i in 0..4) {
        let score = if (denominators[i] == 0.0) { 0.0 } else { weighted[i] / denominators[i] }
        total += score * profile.weights[i]
        let d = JsonObject()
        d.put("score", JsonFloat(score)); d.put("weight", JsonFloat(profile.weights[i]))
        d.put("has_requirements", JsonBool(denominators[i] > 0.0))
        scores.put(dimensions()[i], d)
    }
    let result = JsonObject()
    result.put("candidate_id", JsonString(candidateId)); result.put("evaluation", job.toJson())
    result.put("total_score", JsonFloat(if (total > 100.0) { 100.0 } else { total })); result.put("dimension_scores", scores)
    result.put("mandatory_status", JsonString(if (requiredFailed) { "不满足" } else if (requiredPending) { "待核实" } else { "满足" }))
    result.put("evidence_coverage", JsonFloat(Float64(covered) / Float64(profile.requirements.size)))
    result.put("covered_requirements", JsonInt(covered)); result.put("requirement_count", JsonInt(profile.requirements.size))
    result.put("items", items); result.put("strengths", strengths); result.put("gaps", gaps); result.put("pending", pending)
    result.put("review_status", JsonString("待人工复核"))
    return MatchResult(result)
}

func priority(state: String): Int64 {
    match (state) { case "满足" => 0; case "待核实" => 1; case "不满足" => 2; case _ => throw Exception("Invalid mandatory state") }
}

public func rank(results: Array<MatchResult>): Array<MatchResult> {
    let sorted = Array<MatchResult>(results.size, {i => results[i]})
    let ids = HashSet<String>()
    for (result in sorted) {
        let j = result.toJson(); let id = j["candidate_id"].asString().getValue()
        if (ids.contains(id)) { throw Exception("Duplicate candidate ID") }
        ids.add(id)
        if (j["evaluation"].toJsonString() != sorted[0].toJson()["evaluation"].toJsonString()) {
            throw Exception("Cannot rank results from different frozen evaluations")
        }
    }
    // Stable insertion sort: equal group and score preserve input order.
    for (i in 1..sorted.size) {
        var pos = i
        while (pos > 0) {
            let a = sorted[pos].toJson(); let b = sorted[pos-1].toJson()
            let pa = priority(a["mandatory_status"].asString().getValue())
            let pb = priority(b["mandatory_status"].asString().getValue())
            if (!(pa < pb || (pa == pb && number(a["total_score"]) > number(b["total_score"])))) { break }
            let tmp = sorted[pos-1]; sorted[pos-1] = sorted[pos]; sorted[pos] = tmp
            pos--
        }
    }
    return sorted
}
