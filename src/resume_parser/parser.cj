package resume_match.resume_parser

import std.fs.*
import std.process.*
import stdx.encoding.json.*

public func route(path: String): String {
    let name = path.toAsciiLower()
    if (name.endsWith(".pdf")) { return "pdf" }
    if (name.endsWith(".docx")) { return "docx" }
    if (name.endsWith(".doc")) { return "doc" }
    for (suffix in [".png", ".jpg", ".jpeg", ".tiff", ".tif", ".bmp"]) {
        if (name.endsWith(suffix)) { return "image" }
    }
    throw Exception("Unsupported resume format: ${path}")
}

// No shell interpolation. Output is a file, avoiding pipe-buffer deadlocks.
public func runTool(command: String, args: Array<String>): Unit {
    let child = launch(command, args)
    let code = child.wait(timeout: Duration.second * 300)
    if (code != 0) { throw Exception("Tool failed (${code}): ${command}") }
}

public func parseResume(input: String, scratch: String, python: String, bridge: String,
    soffice: String, extractor: StructuredExtractor): JsonObject {
    let format = route(input)
    // Caller supplies a fresh absolute scratch directory for each invocation.
    if (exists(scratch)) { throw Exception("Scratch directory must be fresh") }
    Directory.create(scratch)
    var decodedInput = input
    if (format == "doc") {
        runTool(soffice, ["--headless", "-env:UserInstallation=file://${scratch}/lo-profile",
            "--convert-to", "docx", "--outdir", scratch, input])
        let base = Path(input).fileName
        decodedInput = "${scratch}/${base[..base.size-4]}.docx"
        if (!exists(decodedInput)) { throw Exception("DOC conversion produced no DOCX") }
    }
    let output = "${scratch}/document.json"
    if (format == "image") {
        runTool(python, [bridge, decodedInput, output, "--image"])
    } else {
        runTool(python, [bridge, decodedInput, output])
    }
    let document = JsonValue.fromStr(String.fromUtf8(File.readFrom(output))).asObject()
    if (document["status"].asString().getValue() != "parsed_requires_review") {
        throw Exception("Parsing requires manual handling")
    }
    document.put("original_source", JsonString(input))
    document.put("conversion", JsonString(if (format == "doc") { "doc_to_docx" } else { "none" }))
    return structure(document, extractor)
}
