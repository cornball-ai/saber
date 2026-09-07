# Read just the frontmatter; this deliberately is not a general YAML parser.
skill_metadata <- function(path) {
    con <- file(path, "rt", encoding = "UTF-8")
    on.exit(close(con))
    first <- readLines(con, n = 1L, warn = FALSE)
    if (!identical(sub("^\ufeff", "", first), "---")) {
        stop("Missing skill frontmatter.", call. = FALSE)
    }
    header <- character()
    repeat {
        line <- readLines(con, n = 1L, warn = FALSE)
        if (!length(line)) stop("Unterminated skill frontmatter.",
                                call. = FALSE)
        if (identical(trimws(line), "---")) break
        header <- c(header, line)
        if (sum(nchar(header, type = "bytes")) > 65536L) {
            stop("Skill frontmatter exceeds 64 KiB.", call. = FALSE)
        }
    }
    fields <- lapply(c("name", "description"), function(key) {
        hit <- grep(paste0("^", key, ":[[:blank:]]*"), header)
        if (length(hit) != 1L) {
            stop("Skill requires one name and one description.", call. = FALSE)
        }
        value <- sub(paste0("^", key, ":[[:blank:]]*"), "", header[hit])
        following <- character()
        i <- hit + 1L
        while (i <= length(header) && grepl("^([[:blank:]]|$)", header[i])) {
            following <- c(following, trimws(header[i]))
            i <- i + 1L
        }
        skill_scalar(value, following)
    })
    names(fields) <- c("name", "description")
    if (!grepl("^[a-z0-9]+(-[a-z0-9]+)*$", fields$name) ||
        nchar(fields$name) > 64L || !nzchar(fields$description)) {
        stop("Invalid skill name or empty description.", call. = FALSE)
    }
    fields
}

skill_scalar <- function(value, following) {
    value <- trimws(value)
    if (grepl("^[>|][-+]?$", value)) {
        value <- paste(following, collapse = " ")
    } else if (startsWith(value, "'")) {
        if (nchar(value) < 2L || !endsWith(value, "'")) {
            stop("Unsupported quoted skill metadata.", call. = FALSE)
        }
        value <- gsub("''", "'", substring(value, 2L, nchar(value) - 1L),
                      fixed = TRUE)
    } else if (startsWith(value, '"')) {
        if (nchar(value) < 2L || !endsWith(value, '"')) {
            stop("Unsupported quoted skill metadata.", call. = FALSE)
        }
        value <- tryCatch(scan(text = value, what = "", sep = "\n", quote = '"',
                               allowEscapes = TRUE, quiet = TRUE),
                          error = function(e) character())
        if (length(value) != 1L) stop("Invalid quoted metadata.", call. = FALSE)
    } else {
        if (!nzchar(value) || grepl("^[!&*[{>|]", value)) {
            stop("Unsupported skill metadata value.", call. = FALSE)
        }
        value <- sub("[[:blank:]]+#.*$", "", value)
        value <- paste(c(value, following), collapse = " ")
    }
    trimws(gsub("[[:space:]]+", " ", value))
}
