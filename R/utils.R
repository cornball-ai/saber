#' @title Internal utilities
#' @description Shared helper functions for basalt.

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
