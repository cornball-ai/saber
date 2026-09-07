skill_snapshot <- function(root) {
    paths <- skill_walk(root)
    main <- file.path(root, "SKILL.md")
    if (!main %in% paths) stop("Missing SKILL.md resource.", call. = FALSE)
    hashes <- unname(tools::md5sum(paths))
    if (anyNA(hashes)) stop("Unreadable skill resource.", call. = FALSE)
    data.frame(resource = substring(paths, nchar(root) + 2L),
               path = normalizePath(paths, winslash = "/", mustWork = TRUE),
               md5 = hashes, stringsAsFactors = FALSE)
}

#' Read an instruction from a skill manifest
#'
#' Returns the exact UTF-8 file text after checking its recorded identity and
#' fingerprint. Supporting resources receive the same checks as SKILL.md.
#'
#' @param manifest A skill_manifest() result for the current session.
#' @param id Exact selected skill id, including its package or root namespace.
#' @param resource Relative resource path within that skill, default SKILL.md.
#' @return One character string, without a wrapper or whitespace normalization.
#' @details
#' Only resources inventoried in this manifest are readable. Absolute paths,
#' parent traversal, changed files, and symlink escapes are refused. Rebuild the
#' manifest explicitly to accept changed source instructions. This reader does
#' not execute scripts or grant tool permissions. Binary/NUL-containing files
#' and files larger than 1 MiB are refused by this text interface.
#' @examples
#' m <- skill_manifest(packages = character(), lib.loc = character())
#' nrow(m$entries)
#' @export
skill_read <- function(manifest, id, resource = "SKILL.md") {
    if (!inherits(manifest, "saber_skill_manifest")) {
        stop("Expected a skill manifest.", call. = FALSE)
    }
    context_string(id, "id")
    context_string(resource, "resource")
    if (grepl("[\\\\:]|^/", resource) ||
        any(strsplit(resource, "/", fixed = TRUE)[[1L]] %in% c("", ".", ".."))) {
        stop("Resource must be a skill-relative path.", call. = FALSE)
    }
    index <- which(manifest$entries$id == id & manifest$entries$selected)
    if (length(index) != 1L) stop("Skill id is not selected in this manifest.",
                                  call. = FALSE)
    records <- manifest$resources[[id]]
    record <- records[records$resource == resource,, drop = FALSE]
    if (nrow(record) != 1L) stop("Resource is not in this skill snapshot.", call. = FALSE)
    root <- manifest$entries$path[index]
    requested <- file.path(root, resource)
    skill_check_resource(requested, root, record)
    size <- file.info(requested)$size
    if (is.na(size) ||
        size > 1048576) stop("Skill text exceeds 1 MiB.", call. = FALSE)
    bytes <- readBin(requested, "raw", n = size)
    skill_check_resource(requested, root, record)
    if (any(bytes == as.raw(0))) stop("Resource is not text.", call. = FALSE)
    text <- rawToChar(bytes)
    if (!validUTF8(text)) stop("Resource is not UTF-8 text.", call. = FALSE)
    Encoding(text) <- "UTF-8"
    text
}

skill_check_resource <- function(path, root, record) {
    current <- normalizePath(path, winslash = "/", mustWork = FALSE)
    expected <- record$path
    if (.Platform$OS.type == "windows") {
        current <- tolower(current)
        expected <- tolower(expected)
    }
    if (!file.exists(path) || dir.exists(path) || !skill_within(path, root) ||
        !identical(current, expected) ||
        !identical(unname(tools::md5sum(path)), record$md5)) {
        stop("Skill resource drifted; rebuild the manifest explicitly.",
             call. = FALSE)
    }
}
