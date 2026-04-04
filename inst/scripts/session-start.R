#!/usr/bin/env Rscript
# saber - generate project briefing at session start
# For use as a Claude Code or Codex SessionStart hook
#
# Usage: Rscript session-start.R [agent]
#   agent: "claude", "codex", or omit for interactive default

cli_args <- commandArgs(trailingOnly = TRUE)
agent <- if (length(cli_args) > 0L) cli_args[[1L]] else NULL

session_cwd <- getwd()

resolve_repo_root <- function(path) {
    root <- tryCatch(
                    system2("git", c("-C", path, "rev-parse", "--show-toplevel"),
                            stdout = TRUE, stderr = FALSE),
                    error = function(e) character(0L)
    )
    if (length(root) == 0L) {
        return(NULL)
    }

    root <- trimws(root[[1L]])
    if (nchar(root) == 0L) {
        return(NULL)
    }
    path.expand(root)
}

load_briefing_fun <- function(repo_root = NULL) {
    if (!is.null(repo_root)) {
        local_fun <- tryCatch(
                            {
                                r_dir <- file.path(repo_root, "R")
                                if (!file.exists(file.path(repo_root, "DESCRIPTION")) ||
                                    !dir.exists(r_dir)) {
                                    stop("No local package source found")
                                }

                                env <- new.env(parent = baseenv())
                                r_files <- list.files(r_dir, pattern = "\\.[Rr]$",
                                                      full.names = TRUE)
                                for (f in r_files) {
                                    sys.source(f, envir = env)
                                }
                                get("briefing", envir = env, inherits = FALSE)
                            },
                            error = function(e) NULL
        )
        if (is.function(local_fun)) {
            return(local_fun)
        }
    }

    if (requireNamespace("saber", quietly = TRUE)) {
        return(saber::briefing)
    }

    stop("saber not available")
}

repo_root <- resolve_repo_root(session_cwd)
if (!is.null(repo_root)) {
    project <- basename(repo_root)
    scan_dir <- dirname(repo_root)
} else {
    project <- basename(session_cwd)
    scan_dir <- path.expand("~")
}

briefing_text <- tryCatch(
    {
        briefing_fun <- load_briefing_fun(repo_root)
        capture.output(
            briefing_text <- briefing_fun(project, scan_dir = scan_dir,
                                          agent = agent)
        )
        briefing_text
    },
    error = function(e) {
        paste0("# Briefing: ", project,
               "\n_saber not available:_ ", conditionMessage(e), "\n")
    }
)

if (is.null(briefing_text) || nchar(briefing_text) == 0L) {
    briefing_text <- paste0("# Briefing: ", project,
                            "\n_No briefing available._\n")
}

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
