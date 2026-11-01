package resume_match.resume_parser

import std.collection.*
import stdx.encoding.json.*

public interface StructuredExtractor {
    func extract(document: JsonObject): ResumeDraft
}

// Deliberately no model call in stage one. The port accepts a future API adapter.
public class UnknownExtractor <: StructuredExtractor {
    public func extract(document: JsonObject): ResumeDraft { ResumeDraft() }
}

public func normalizeSkill(value: String): String {
    match (value.trimAscii().toAsciiLower()) {
        case "js" | "javascript" => "JavaScript"
        case "ts" | "typescript" => "TypeScript"
        case "py" | "python" => "Python"
        case "cangjie" | "仓颉" => "仓颉"
        case _ => value.trimAscii()
    }
}

public func structure(document: JsonObject, extractor: StructuredExtractor): JsonObject {
    let segments = document["segments"].asArray()
    let ids = HashSet<String>()
    for (i in 0..segments.size()) { ids.add(segments[i].asObject()["id"].asString().getValue()) }
    let draft = extractor.extract(document)
    let checked = { fact: Fact =>
        if (fact.value != "未知" && fact.evidence.isEmpty()) {
            throw Exception("Fact has no evidence: ${fact.value}")
        }
        for (id in fact.evidence) {
            if (!ids.contains(id)) { throw Exception("Invalid evidence reference: ${id}") }
        }
        fact.toJson()
    }
    let skills = JsonArray()
    for (skill in draft.skills) {
        skills.add(checked(Fact(value: normalizeSkill(skill.value), evidence: skill.evidence)))
    }
    let experiences = JsonArray()
    for (item in draft.experiences) {
        let obj = JsonObject()
        obj.put("employer", checked(item.employer)); obj.put("role", checked(item.role))
        obj.put("start", checked(item.start)); obj.put("end", checked(item.end))
        experiences.add(obj)
    }
    let projects = JsonArray()
    for (item in draft.projects) {
        let obj = JsonObject()
        obj.put("name", checked(item.name)); obj.put("responsibility", checked(item.responsibility))
        obj.put("outcome", checked(item.outcome)); projects.add(obj)
    }
    let education = JsonArray()
    for (item in draft.education) {
        let obj = JsonObject()
        obj.put("institution", checked(item.institution)); obj.put("degree", checked(item.degree))
        obj.put("major", checked(item.major)); education.add(obj)
    }
    let behaviors = JsonArray()
    for (item in draft.behaviors) {
        if (item.quality.value != "未知" && item.behavior.value == "未知") {
            throw Exception("Soft quality requires behavioral evidence")
        }
        let obj = JsonObject()
        obj.put("quality", checked(item.quality)); obj.put("behavior", checked(item.behavior))
        obj.put("status", JsonString("待面试核实")); behaviors.add(obj)
    }
    let result = JsonObject()
    result.put("schema_version", JsonString("0.1"))
    result.put("status", JsonString("needs_review"))
    result.put("document", document)
    for ((key, values) in [("skills", skills), ("experiences", experiences), ("projects", projects),
                           ("education", education), ("behavior_evidence", behaviors)]) {
        let group = JsonObject()
        group.put("status", JsonString(if (values.size() == 0) { "未知" } else { "待核实" }))
        group.put("items", values)
        result.put(key, group)
    }
    return result
}
