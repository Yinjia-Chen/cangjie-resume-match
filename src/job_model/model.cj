package resume_match.job_model

import std.collection.*
import stdx.encoding.json.*

public func dimensions(): Array<String> { ["skills", "experience", "education", "soft_quality"] }

public func dimensionIndex(value: String): Int64 {
    let names = dimensions()
    for (i in 0..names.size) { if (names[i] == value) { return i } }
    throw Exception("Unsupported capability dimension: ${value}")
}

public func number(value: JsonValue): Float64 {
    match (value.kind()) {
        case JsonKind.JsInt => Float64(value.asInt().getValue())
        case JsonKind.JsFloat => value.asFloat().getValue()
        case _ => throw Exception("Expected JSON number")
    }
}

public struct Requirement {
    public let id: String
    public let dimension: String
    public let target: String
    public let required: Bool
    public let weight: Float64
    public init(id: String, dimension: String, target: String, required!: Bool = false, weight!: Float64 = 1.0) {
        if (id.trimAscii().isEmpty() || target.trimAscii().isEmpty()) { throw Exception("Empty requirement ID/target") }
        dimensionIndex(dimension)
        if (!(weight > 0.0 && weight <= 100.0)) { throw Exception("Item weight must be finite in (0,100]") }
        this.id = id; this.dimension = dimension; this.target = target
        this.required = required; this.weight = weight
    }
    public func toJson(): JsonObject {
        let j = JsonObject()
        j.put("id", JsonString(id)); j.put("dimension", JsonString(dimension))
        j.put("target_level", JsonString(target)); j.put("required", JsonBool(required)); j.put("weight", JsonFloat(weight))
        return j
    }
    public static func fromJson(j: JsonObject): Requirement {
        Requirement(j["id"].asString().getValue(), j["dimension"].asString().getValue(),
            j["target_level"].asString().getValue(), required: j["required"].asBool().getValue(), weight: number(j["weight"]))
    }
}

public struct JobProfile {
    public let id: String
    public let requirements: Array<Requirement>
    public let weights: Array<Float64>
    public init(id: String, requirements: Array<Requirement>, weights!: Array<Float64> = [0.40, 0.35, 0.15, 0.10]) {
        if (id.trimAscii().isEmpty() || requirements.isEmpty()) { throw Exception("Job ID and requirements are required") }
        if (weights.size != 4) { throw Exception("Exactly four dimension weights required") }
        var sum = 0.0
        for (w in weights) {
            if (!(w >= 0.0 && w <= 1.0)) { throw Exception("Invalid dimension weight") }
            sum += w
        }
        if (!(sum >= 0.999999999 && sum <= 1.000000001)) { throw Exception("Dimension weights must sum to 1") }
        let ids = HashSet<String>()
        for (r in requirements) {
            if (ids.contains(r.id)) { throw Exception("Duplicate requirement ID") }
            ids.add(r.id)
        }
        this.id = id; this.requirements = requirements; this.weights = weights
    }
    public func toJson(): JsonObject {
        let j = JsonObject(); let items = JsonArray(); let ws = JsonObject()
        for (r in requirements) { items.add(r.toJson()) }
        for (i in 0..4) { ws.put(dimensions()[i], JsonFloat(weights[i])) }
        j.put("id", JsonString(id)); j.put("requirements", items); j.put("dimension_weights", ws)
        return j
    }
    public static func fromJson(j: JsonObject): JobProfile {
        let items = j["requirements"].asArray(); let rs = ArrayList<Requirement>()
        for (i in 0..items.size()) { rs.add(Requirement.fromJson(items[i].asObject())) }
        let ws = j["dimension_weights"].asObject()
        return JobProfile(j["id"].asString().getValue(), rs.toArray(),
            weights: Array<Float64>(4, {i => number(ws[dimensions()[i]])}))
    }
}

// Serialize once: caller mutations cannot change the evaluation snapshot.
public class FrozenJob {
    public let revision: String
    private let json: String
    public init(profile: JobProfile, revision: String) {
        if (revision.trimAscii().isEmpty()) { throw Exception("Evaluation revision required") }
        this.revision = revision
        this.json = JobProfile.fromJson(profile.toJson()).toJson().toJsonString()
    }
    public func snapshot(): JobProfile { JobProfile.fromJson(JsonValue.fromStr(json).asObject()) }
    public func toJson(): JsonObject {
        let j = JsonObject()
        j.put("revision", JsonString(revision)); j.put("profile", JsonValue.fromStr(json))
        return j
    }
    public static func fromJson(j: JsonObject): FrozenJob {
        FrozenJob(JobProfile.fromJson(j["profile"].asObject()), j["revision"].asString().getValue())
    }
}
