package resume_match.resume_parser

import stdx.encoding.json.*

// Every fact carries source segment IDs. Missing is not negative evidence.
public struct Fact {
    public let value: String
    public let evidence: Array<String>
    public init(value!: String = "未知", evidence!: Array<String> = []) {
        this.value = if (value.trimAscii().isEmpty()) { "未知" } else { value }
        this.evidence = evidence
    }
    public func toJson(): JsonObject {
        let refs = JsonArray()
        for (id in evidence) { refs.add(JsonString(id)) }
        let obj = JsonObject()
        obj.put("value", JsonString(value))
        obj.put("evidence", refs)
        return obj
    }
}

public struct Experience {
    public let employer: Fact
    public let role: Fact
    public let start: Fact
    public let end: Fact
    public init(employer!: Fact = Fact(), role!: Fact = Fact(), start!: Fact = Fact(), end!: Fact = Fact()) {
        this.employer = employer; this.role = role; this.start = start; this.end = end
    }
}
public struct Project {
    public let name: Fact
    public let responsibility: Fact
    public let outcome: Fact
    public init(name!: Fact = Fact(), responsibility!: Fact = Fact(), outcome!: Fact = Fact()) {
        this.name = name; this.responsibility = responsibility; this.outcome = outcome
    }
}
public struct Education {
    public let institution: Fact
    public let degree: Fact
    public let major: Fact
    public init(institution!: Fact = Fact(), degree!: Fact = Fact(), major!: Fact = Fact()) {
        this.institution = institution; this.degree = degree; this.major = major
    }
}
public struct BehaviorEvidence {
    public let quality: Fact
    public let behavior: Fact
    public init(quality!: Fact = Fact(), behavior!: Fact = Fact()) {
        this.quality = quality; this.behavior = behavior
    }
}
public struct ResumeDraft {
    public let skills: Array<Fact>
    public let experiences: Array<Experience>
    public let projects: Array<Project>
    public let education: Array<Education>
    public let behaviors: Array<BehaviorEvidence>
    public init(skills!: Array<Fact> = [], experiences!: Array<Experience> = [],
        projects!: Array<Project> = [], education!: Array<Education> = [], behaviors!: Array<BehaviorEvidence> = []) {
        this.skills = skills; this.experiences = experiences; this.projects = projects
        this.education = education; this.behaviors = behaviors
    }
}
