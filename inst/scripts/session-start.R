#!/usr/bin/env Rscript
# saber - generate project briefing at session start
# For use as a Claude Code SessionStart hook

project <- basename(getwd())

briefing_text <- tryCatch(
    saber::briefing(project),
    error = function(e) {
        paste0("# Briefing: ", project,
               "\n_saber not available:_ ", conditionMessage(e), "\n")
    }
)

if (is.null(briefing_text) || nchar(briefing_text) == 0L) {
    briefing_text <- paste0("# Briefing: ", project,
                            "\n_No briefing available._\n")
}

# Escape for JSON
escaped <- gsub("\\\\", "\\\\\\\\", briefing_text)
escaped <- gsub("\"", "\\\\\"", escaped)
escaped <- gsub("\n", "\\\\n", escaped)
escaped <- gsub("\t", "\\\\t", escaped)

cat(sprintf('{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "%s"
  }
}', escaped))
