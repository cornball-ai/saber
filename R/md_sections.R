#' @title Markdown section comparison
#' @description Split instruction files into heading-delimited sections so
#'   text an agent already holds is not loaded a second time.

#' Split markdown lines into heading-delimited sections
#'
#' A section runs from an ATX heading up to the next one. Text before the
#' first heading is its own section. Headings inside fenced code blocks do
#' not start a section.
#' @noRd
md_sections <- function(lines) {
    if (length(lines) == 0L) {
        return(list())
    }
    fence <- grepl("^\\s*(```|~~~)", lines)
    in_fence <- cumsum(fence) %% 2L == 1L
    heading <- grepl("^#{1,6}(\\s|$)", lines) & !fence & !in_fence
    unname(split(lines, cumsum(heading)))
}

#' Comparison key for a section: its text without edge whitespace
#' @noRd
md_section_key <- function(section) {
    trimws(paste(sub("\\s+$", "", section), collapse = "\n"))
}

#' Comparison keys for the non-empty sections of a file
#' @noRd
md_section_keys <- function(lines) {
    keys <- vapply(md_sections(lines), md_section_key, "")
    keys[nzchar(keys)]
}

#' Keep the sections of a file that were not already seen
#'
#' Returns the remaining lines, their keys, and the number of sections
#' dropped. A file with nothing dropped is returned verbatim.
#' @noRd
md_new_sections <- function(lines, seen) {
    sections <- md_sections(lines)
    keys <- vapply(sections, md_section_key, "")
    fresh <- nzchar(keys) & !(keys %in% seen)
    dropped <- sum(nzchar(keys) & !fresh)
    if (!any(fresh)) {
        lines <- character(0L)
    } else if (dropped > 0L) {
        lines <- unlist(sections[fresh])
    }
    list(lines = lines, keys = keys[fresh], dropped = dropped)
}
