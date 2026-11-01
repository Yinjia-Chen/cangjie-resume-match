package resume_match.matching_agent

import std.collection.*
import stdx.encoding.json.*

// Read only the parser's capability allowlist; ignore name/sex/age/other metadata.
public func resumeEvidence(resume: JsonObject): Array<CapabilityEvidence> {
    let sources = HashMap<String, JsonObject>()
    let segments = resume["document"].asObject()["segments"].asArray()
    for (i in 0..segments.size()) {
        let segment = segments[i].asObject(); let id = segment["id"].asString().getValue()
        if (sources.contains(id)) { throw Exception("Duplicate source segment ID") }
        sources[id] = segment
    }
    let result = ArrayList<CapabilityEvidence>()
    let addFact = { fact: JsonObject, dimension: String, key: String =>
        let value = fact["value"].asString().getValue()
        if (value != "未知" && !value.trimAscii().isEmpty()) {
            let refs = fact["evidence"].asArray()
            if (refs.size() == 0) { throw Exception("Capability fact lacks source evidence") }
            for (i in 0..refs.size()) {
                let id = refs[i].asString().getValue()
                if (!sources.contains(id)) { throw Exception("Unknown resume source: ${id}") }
                let segment = sources[id]
                result.add(CapabilityEvidence("${key}:${id}", dimension, value,
                    segment["text"].asString().getValue(), JsonValue.fromStr(segment.toJsonString()).asObject()))
            }
        }
    }
    for ((group, dimension, fields) in [
        ("skills", "skills", ["self"]),
        ("experiences", "experience", ["employer", "role", "start", "end"]),
        ("projects", "experience", ["name", "responsibility", "outcome"]),
        ("education", "education", ["institution", "degree", "major"]),
        // Quality labels alone never constitute behavioral evidence.
        ("behavior_evidence", "soft_quality", ["behavior"])
    ]) {
        let items = resume[group].asObject()["items"].asArray()
        for (i in 0..items.size()) {
            let item = items[i].asObject()
            for (field in fields) {
                let fact = if (field == "self") { item } else { item[field].asObject() }
                addFact(fact, dimension, "${group}:${i}:${field}")
            }
        }
    }
    return result.toArray()
}
