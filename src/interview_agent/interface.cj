package resume_match.interview_agent

import resume_match.job_model.FrozenJob
import resume_match.matching_agent.MatchResult
import stdx.encoding.json.JsonObject

// Interface only; no question generation or model connection in stage two.
public interface InterviewAgent {
    func propose(job: FrozenJob, matching: MatchResult): JsonObject
}
