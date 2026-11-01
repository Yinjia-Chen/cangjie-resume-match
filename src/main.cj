package resume_match

import resume_match.resume_parser.*
import std.fs.File

main(args: Array<String>): Int64 {
    if (args.size != 5) {
        println("Usage: resume_match INPUT ABS_FRESH_SCRATCH PYTHON BRIDGE SOFFICE")
        return 2
    }
    try {
        let result = parseResume(args[0], args[1], args[2], args[3], args[4], UnknownExtractor())
        File.writeTo("${args[1]}/resume.json", result.toJsonString().toArray())
        println("Saved: ${args[1]}/resume.json")
        return 0
    } catch (e: Exception) {
        println("needs_review: ${e.message}")
        return 1
    }
}
