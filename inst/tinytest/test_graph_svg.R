# Tests for graph_svg.R

library(saber)

edges <- data.frame(from = c("a", "a"), to = c("b", "c"),
                    stringsAsFactors = FALSE)
svg <- graph_svg(edges)

expect_true(is.character(svg))
expect_true(any(grepl("^<svg", svg)))
expect_true(any(grepl("</svg>$", svg)))
expect_equal(sum(grepl("<circle ", svg)), 3L)
expect_equal(sum(grepl("<line ", svg)), 2L)
expect_true(any(grepl("<title>a</title>", svg)))

# Deterministic layout
svg1 <- graph_svg(edges, seed = 42L)
svg2 <- graph_svg(edges, seed = 42L)
expect_equal(svg1, svg2)

svg3 <- graph_svg(edges, seed = 99L)
expect_false(identical(svg1, svg3))

# Hrefs wrap in anchors
nodes <- data.frame(id = c("a", "b", "c"),
                    label = c("Alpha", "Beta", "Gamma"),
                    href = c("a.html", "b.html", NA_character_),
                    stringsAsFactors = FALSE)
svg <- graph_svg(edges, nodes)
expect_true(any(grepl('xlink:href="a.html"', svg, fixed = TRUE)))
expect_equal(sum(grepl("<a ", svg)), 2L)

# XML escaping
edges2 <- data.frame(from = "x<y", to = "z&w", stringsAsFactors = FALSE)
svg <- graph_svg(edges2)
expect_true(any(grepl("<title>x&lt;y</title>", svg)))
expect_true(any(grepl("<title>z&amp;w</title>", svg)))

# Custom tooltip column overrides label-based tooltip
nodes3 <- data.frame(id = c("a", "b", "c"),
                     label = c("a", "b", "c"),
                     href = NA_character_,
                     tooltip = c("Alpha node\nversion 1.0",
                                 "Beta node\nversion 2.0",
                                 NA_character_),
                     stringsAsFactors = FALSE)
svg <- graph_svg(edges, nodes3)
expect_true(any(grepl("Alpha node", svg, fixed = TRUE)))
expect_true(any(grepl("version 1.0", svg, fixed = TRUE)))
# NA tooltip falls back to label
expect_true(any(grepl("<title>c</title>", svg)))

# Unknown node id -> clear error
expect_error(graph_svg(edges,
                       nodes = data.frame(id = c("a", "b"), label = c("a", "b"),
                                          href = NA_character_,
                                          stringsAsFactors = FALSE)),
             "unknown node id")

# Empty edges
svg <- graph_svg(edges = data.frame(from = character(), to = character(),
                                    stringsAsFactors = FALSE),
                 nodes = data.frame(id = c("solo1", "solo2"),
                                    label = c("solo1", "solo2"),
                                    href = NA_character_,
                                    stringsAsFactors = FALSE))
expect_equal(sum(grepl("<line ", svg)), 0L)
expect_equal(sum(grepl("<circle ", svg)), 2L)
