#' @title Internal utilities
#' @description Shared helper functions for saber.

#' Compute a file hash for change detection
#'
#' @param filepath Path to a file.
#' @return MD5 hash as a hex string.
#' @noRd
file_hash <- function(filepath) {
    tools::md5sum(filepath)[[1L]]
}

#' Parse a comma-separated DCF field into a clean character vector
#' @noRd
parse_dcf_list <- function(x) {
    if (is.na(x) || nchar(trimws(x)) == 0L) {
        return(character(0L))
    }
    parts <- strsplit(x, ",")[[1L]]
    parts <- trimws(parts)
    # Strip version constraints like (>= 1.0)
    parts <- sub("\\s*\\(.*\\)", "", parts)
    parts <- parts[nchar(parts) > 0L]
    parts
}

#' Default directories to exclude when scanning for projects
#'
#' Returns a character vector of directory basenames that are skipped
#' when scanning for downstream projects. Override by passing a custom
#' \code{exclude} vector to \code{\link{blast_radius}}.
#'
#' @return Character vector of directory basenames.
#' @examples
#' default_exclude()
#' @export
default_exclude <- function() {
    c(
        # User directories
        "Documents", "Downloads", "Desktop", "Music", "Pictures",
        "Videos", "Templates", "Public", "Sync",
        # R internals
        "R", ".Rcheck",
        # Caches and configs
        ".cache", ".local", ".config", ".claude",
        # Build artifacts
        "actions-runner", "node_modules", ".git",
        # Other
        "snap", ".npm", ".cargo", ".rustup"
    )
}
