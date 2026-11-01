package resume_match.matching_agent

import resume_match.job_model.*
import stdx.encoding.json.*

// Only capability facts enter the semantic port. No name, sex or age fields.
public struct CapabilityEvidence {
    public let id: String
    public let dimension: String
    public let value: String
    public let excerpt: String
    private let sourceJson: String
    public init(id: String, dimension: String, value: String, excerpt: String, source: JsonObject) {
        dimensionIndex(dimension)
        if (id.isEmpty() || value.trimAscii().isEmpty() || value == "未知" || excerpt.trimAscii().isEmpty()) {
            throw Exception("Evidence must have an ID, known capability and original excerpt")
        }
        if (source["source_ref"].asString().getValue().isEmpty()) { throw Exception("Evidence source required") }
        this.id = id; this.dimension = dimension; this.value = value; this.excerpt = excerpt
        if (source["text"].asString().getValue() != excerpt) { throw Exception("Quote differs from source text") }
        this.sourceJson = source.toJsonString()
    }
    public func toJson(): JsonObject {
        let j = JsonObject()
        j.put("id", JsonString(id)); j.put("dimension", JsonString(dimension))
        j.put("value", JsonString(value)); j.put("quote", JsonString(excerpt)); j.put("source", JsonValue.fromStr(sourceJson))
        return j
    }
}

public struct Judgment {
    public let state: String
    public let score: Float64
    public let evidenceIds: Array<String>
    public init(state!: String = "待核实", score!: Float64 = 0.0, evidenceIds!: Array<String> = []) {
        this.state = state; this.score = score; this.evidenceIds = evidenceIds
    }
}

public interface SemanticJudge {
    func judge(requirement: Requirement, evidence: Array<CapabilityEvidence>): Judgment
}

public class UnknownSemanticJudge <: SemanticJudge {
    public func judge(requirement: Requirement, evidence: Array<CapabilityEvidence>): Judgment { Judgment() }
}

// Immutable serialized output prevents a caller altering the score before ranking.
public class MatchResult {
    private let json: String
    init(result: JsonObject) { this.json = result.toJsonString() }
    public func toJson(): JsonObject { JsonValue.fromStr(json).asObject() }
}
