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

