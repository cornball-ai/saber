#' @title Feature hubs
#' @description Markdown files mapping concepts to code via wikilinks.

#' Create or update a feature hub
#'
#' Writes a markdown file to \code{~/.cache/basalt/hubs/} that maps a concept
#' to code locations using \code{[[project::function]]} wikilinks.
#'
#' @param name Character. Hub name (used as filename).
#' @param content Character. Markdown content for the hub.
#' @param hubs_dir Directory for hub files.
#' @return The file path (invisibly).
#' @export
hub <- function(name, content,
                hubs_dir = file.path(tools::R_user_dir("basalt", "cache"), "hubs")) {
    dir.create(hubs_dir, recursive = TRUE, showWarnings = FALSE)
    outfile <- file.path(hubs_dir, paste0(name, ".md"))
    writeLines(content, outfile)
    message("Wrote hub: ", outfile)
    invisible(outfile)
}

#' List all feature hubs
#'
#' Returns a data.frame of hub files with their wikilink references.
#'
#' @param hubs_dir Directory containing hub files.
#' @return A data.frame with columns: name, file, links (comma-separated
#'   wikilink targets).
#' @export
hubs <- function(hubs_dir = file.path(path.expand("~"), ".cache", "basalt",
                                      "hubs")) {
    if (!dir.exists(hubs_dir)) {
        return(data.frame(name = character(), file = character(),
                          links = character(), stringsAsFactors = FALSE))
    }

    files <- list.files(hubs_dir, pattern = "\\.md$", full.names = TRUE)
    if (length(files) == 0L) {
        return(data.frame(name = character(), file = character(),
                          links = character(), stringsAsFactors = FALSE))
    }

    names_vec <- tools::file_path_sans_ext(basename(files))
    links_vec <- vapply(files, function(fp) {
        lines <- readLines(fp, warn = FALSE)
        all_links <- regmatches(lines, gregexpr("\\[\\[([^]]+)\\]\\]", lines))
        all_links <- unlist(all_links)
        if (length(all_links) == 0L) return("")
        targets <- gsub("^\\[\\[|\\]\\]$", "", all_links)
        paste(unique(targets), collapse = ", ")
    }, character(1))

    data.frame(name = names_vec, file = files, links = unname(links_vec),
               stringsAsFactors = FALSE, row.names = NULL)
}

