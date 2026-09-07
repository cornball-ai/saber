skill_path_key <- function(path) {
    path <- normalizePath(path, winslash = "/", mustWork = FALSE)
    if (.Platform$OS.type == "windows") tolower(path) else path
}

skill_within <- function(path, root) {
    path <- skill_path_key(path)
    root <- sub("/+$", "", skill_path_key(root))
    identical(path, root) || startsWith(path, paste0(root, "/"))
}

# Follow directory aliases only within the selected root and visit each once.
skill_walk <- function(root, bundles = FALSE) {
    if (!dir.exists(root)) return(character())
    root <- normalizePath(root, winslash = "/", mustWork = TRUE)
    queue <- root
    visited <- result <- character()
    while (length(queue)) {
        path <- queue[1L]
        queue <- queue[-1L]
        canonical <- normalizePath(path, winslash = "/", mustWork = FALSE)
        key <- skill_path_key(canonical)
        if (!skill_within(canonical, root)) {
            stop("Skill resource escapes its root.", call. = FALSE)
        }
        if (key %in% visited) next
        visited <- c(visited, key)
        if (length(visited) > 10000L) stop("Skill tree exceeds 10000 paths.",
            call. = FALSE)
        if (dir.exists(path)) {
            if (bundles && file.exists(file.path(path, "SKILL.md"))) {
                result <- c(result, path)
            } else {
                children <- list.files(path, full.names = TRUE, all.files = FALSE,
                                       no.. = TRUE)
                queue <- c(queue, children)
            }
        } else if (!bundles && file.exists(path)) {
            result <- c(result, path)
        }
    }
    sort(result)
}

skill_package_root <- function(path, origin) {
    desc <- tryCatch(read.dcf(file.path(path, "DESCRIPTION"),
                              fields = c("Package", "Version")),
                     error = function(e) NULL)
    if (is.null(desc) || !nrow(desc) || is.na(desc[1L, "Package"])) return(NULL)
    package <- desc[1L, "Package"]
    version <- desc[1L, "Version"]
    if (is.na(version)) version <- ""
    if (origin == "source") {
        root <- file.path(path, "inst", "skills")
    } else {
        root <- file.path(path, "skills")
    }
    data.frame(owner = paste0("package:", package), package = package,
               version = version, origin = origin, path = root,
               stringsAsFactors = FALSE)
}

skill_roots <- function(packages, lib.loc, project_dirs, roots, prefer) {
    rows <- list()
    for (path in project_dirs) {
        rows[[length(rows) + 1L]] <- skill_package_root(path, "source")
    }
    for (lib in lib.loc) {
        names <- if (is.null(packages)) list.dirs(lib, recursive = FALSE) else file.path(lib,
            packages)
        for (path in names) {
            if (file.exists(file.path(path, "DESCRIPTION"))) {
                rows[[length(rows) + 1L]] <- skill_package_root(path,
                    "installed")
            }
        }
    }
    for (id in names(roots)) {
        rows[[length(rows) + 1L]] <- data.frame(owner = paste0("root:", id),
            package = "", version = "", origin = "root", path = roots[[id]],
            stringsAsFactors = FALSE)
    }
    if (!length(rows)) return(data.frame())
    result <- do.call(rbind, rows)
    if (is.null(result) || !nrow(result)) return(data.frame())
    result <- result[!duplicated(paste(result$owner, skill_path_key(result$path))),, drop = FALSE]
    order <- order(match(result$origin, c(prefer, "root")), seq_len(nrow(result)))
    selected <- order[!duplicated(result$owner[order])]
    result$selected <- seq_len(nrow(result)) %in% selected
    rownames(result) <- NULL
    result
}
