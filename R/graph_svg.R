#' @title Force-directed graph rendering
#' @description Render a graph as static SVG using a base R
#'   Fruchterman-Reingold force simulation.

#' Render a graph as static SVG
#'
#' Runs a Fruchterman-Reingold force simulation to lay out nodes, then
#' emits SVG with baked coordinates. Output is interactive via native
#' browser features: hover tooltips from \code{<title>} elements, click
#' navigation from \code{<a xlink:href>} wrappers, CSS \code{:hover}
#' highlighting. No JavaScript.
#'
#' Suitable for graphs up to roughly a few hundred nodes. The repulsion
#' step is vectorized via \code{outer()} but allocates an
#' \code{n x n} matrix per iteration; larger graphs should pre-filter.
#'
#' @param edges Data frame with \code{from} and \code{to} columns
#'   holding node ids.
#' @param nodes Optional data frame with \code{id}, \code{label},
#'   \code{href} columns. Optionally a \code{tooltip} column (plain
#'   text, may contain newlines) that overrides the default hover
#'   text (which is the label). \code{id} must cover every node
#'   mentioned in \code{edges}. If \code{NULL}, ids from \code{edges}
#'   are used as labels with no hrefs or tooltips.
#' @param width SVG viewport width in pixels.
#' @param height SVG viewport height in pixels.
#' @param iterations Force-simulation steps. 50 is usually enough.
#' @param seed Integer seed for the random initial layout (output is
#'   deterministic given the same seed).
#' @return Character vector, one SVG element per line. Write with
#'   \code{writeLines()}.
#' @examples
#' edges <- data.frame(from = c("a", "a", "b"),
#'                     to = c("b", "c", "c"))
#' svg <- graph_svg(edges)
#' writeLines(svg, tempfile(fileext = ".svg"))
#' @export
graph_svg <- function(edges, nodes = NULL, width = 1200L, height = 900L,
                      iterations = 50L, seed = 1L) {
    ids <- unique(c(edges$from, edges$to))
    if (is.null(nodes)) {
        nodes <- data.frame(id = ids, label = ids, href = NA_character_,
                            stringsAsFactors = FALSE)
    }
    if (!all(ids %in% nodes$id)) {
        missing <- setdiff(ids, nodes$id)
        stop("Edge refers to unknown node id: ",
             paste(head(missing, 5L), collapse = ", "))
    }

    n <- nrow(nodes)
    from_i <- match(edges$from, nodes$id)
    to_i <- match(edges$to, nodes$id)

    set.seed(seed)
    x <- runif(n, width / 4, 3 * width / 4)
    y <- runif(n, height / 4, 3 * height / 4)
    # FR's ideal edge length. Cap at min-dim/4 so small graphs don't
    # stretch to the viewport bounds.
    k <- min(sqrt(width * height / max(n, 1L)), min(width, height) / 4)
    temp <- width / 20
    cx <- width / 2
    cy <- height / 2
    # Gravity pulls nodes toward the center each iteration. Without it,
    # repulsion wins and nodes pile up on the clamp at the edges.
    gravity <- 0.05
    margin <- 40

    for (iter in seq_len(iterations)) {
        dx_m <- outer(x, x, "-")
        dy_m <- outer(y, y, "-")
        dist_m <- sqrt(dx_m ^ 2 + dy_m ^ 2) + 1e-6
        rep_f <- k ^ 2 / dist_m
        diag(rep_f) <- 0
        dx <- rowSums(dx_m / dist_m * rep_f)
        dy <- rowSums(dy_m / dist_m * rep_f)

        if (length(from_i)) {
            evx <- x[from_i] - x[to_i]
            evy <- y[from_i] - y[to_i]
            edist <- sqrt(evx ^ 2 + evy ^ 2) + 1e-6
            att_f <- edist ^ 2 / k
            ax <- evx / edist * att_f
            ay <- evy / edist * att_f
            for (e in seq_along(from_i)) {
                dx[from_i[e]] <- dx[from_i[e]] - ax[e]
                dy[from_i[e]] <- dy[from_i[e]] - ay[e]
                dx[to_i[e]] <- dx[to_i[e]] + ax[e]
                dy[to_i[e]] <- dy[to_i[e]] + ay[e]
            }
        }

        dx <- dx - (x - cx) * gravity * k
        dy <- dy - (y - cy) * gravity * k

        disp <- sqrt(dx ^ 2 + dy ^ 2) + 1e-6
        x <- x + dx / disp * pmin(disp, temp)
        y <- y + dy / disp * pmin(disp, temp)
        x <- pmin(pmax(x, margin), width - margin)
        y <- pmin(pmax(y, margin), height - margin)
        temp <- temp * 0.95
    }

    out <- c(
             sprintf('<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 %d %d">',
                     width, height),
             "<style>",
             "  .node { fill: #4c78a8; stroke: #fff; stroke-width: 1.5; cursor: pointer; }",
             "  .node:hover { fill: #f58518; }",
             "  .edge { stroke: #999; stroke-opacity: 0.4; }",
             "  .label { font: 11px sans-serif; pointer-events: none; fill: #333; }",
             "</style>"
    )

    for (e in seq_along(from_i)) {
        out <- c(out, sprintf(
                              '<line class="edge" x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f"/>',
                              x[from_i[e]], y[from_i[e]], x[to_i[e]], y[to_i[e]]))
    }

    has_tooltip <- "tooltip" %in% names(nodes)
    for (i in seq_len(n)) {
        label <- xml_escape(as.character(nodes$label[i]))
        tip_raw <- if (has_tooltip && !is.na(nodes$tooltip[i]) &&
            nzchar(nodes$tooltip[i])) {
            nodes$tooltip[i]
        } else {
            nodes$label[i]
        }
        tip <- xml_escape(as.character(tip_raw))
        # Preserve newlines in tooltip via XML numeric entity so the
        # SVG stays on one line on disk; browsers render &#10; as a
        # line break in native tooltip rendering.
        tip <- gsub("\n", "&#10;", tip, fixed = TRUE)
        node <- sprintf(paste0(
                               '<circle class="node" cx="%.1f" cy="%.1f" r="6"><title>%s</title></circle>',
                               '<text class="label" x="%.1f" y="%.1f">%s</text>'),
                        x[i], y[i], tip,
                        x[i] + 8, y[i] + 4, label)
        href <- nodes$href[i]
        if (!is.na(href) && nzchar(href)) {
            node <- sprintf('<a xlink:href="%s">%s</a>', xml_escape(href), node)
        }
        out <- c(out, node)
    }

    c(out, "</svg>")
}

#' Escape text for safe inclusion in SVG/XML
#' @noRd
xml_escape <- function(s) {
    s <- gsub("&", "&amp;", s, fixed = TRUE)
    s <- gsub("<", "&lt;", s, fixed = TRUE)
    s <- gsub(">", "&gt;", s, fixed = TRUE)
    s <- gsub('"', "&quot;", s, fixed = TRUE)
    s
}

