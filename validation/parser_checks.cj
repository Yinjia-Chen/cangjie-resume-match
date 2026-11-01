package resume_match.resume_parser
import stdx.encoding.json.*

class SampleExtractor <: StructuredExtractor {
    let mode: Int64
    init(mode: Int64) { this.mode = mode }
    public func extract(document: JsonObject): ResumeDraft {
        if (mode == 1) { return ResumeDraft(skills: [Fact(value: "JS")]) }
        if (mode == 2) { return ResumeDraft(skills: [Fact(value: "JS", evidence: ["missing"])]) }
        if (mode == 3) {
            return ResumeDraft(behaviors: [BehaviorEvidence(quality: Fact(value: "协作", evidence: ["s1"]))])
        }
        return ResumeDraft(skills: [Fact(value: "JS", evidence: ["s1"])],
            experiences: [Experience(start: Fact(value: "2022-01", evidence: ["s1"]))],
            projects: [Project()], education: [Education()])
    }
}

func check(condition: Bool): Unit {
    if (!condition) { throw Exception("Check failed") }
}

main(): Int64 {
    check(route("A.PDF") == "pdf")
    check(route("A.Doc") == "doc")
    check(route("A.docx") == "docx")
    check(route("A.JPEG") == "image")
    var rejected = false
    try { route("a.exe") } catch (_: Exception) { rejected = true }
    check(rejected)
    check(normalizeSkill(" js ") == "JavaScript")
    check(Fact(value: " ").value == "未知")
    let doc = JsonValue.fromStr("{\"segments\":[{\"id\":\"s1\",\"text\":\"JS 2022-01\"}]}").asObject()
    let empty = structure(doc, UnknownExtractor())
    check(empty["skills"].asObject()["status"].asString().getValue() == "未知")
    let result = structure(doc, SampleExtractor(0))
    check(result["skills"].asObject()["items"].asArray()[0].asObject()["value"].asString().getValue() == "JavaScript")
    check(result["experiences"].asObject()["items"].asArray()[0].asObject()["end"].asObject()["value"].asString().getValue() == "未知")
    for (mode in 1..4) {
        var failed = false
        try { structure(doc, SampleExtractor(mode)) } catch (_: Exception) { failed = true }
        check(failed)
    }
    println("PASS: routing, unknowns, normalization, evidence references, behavior guard")
    return 0
}
