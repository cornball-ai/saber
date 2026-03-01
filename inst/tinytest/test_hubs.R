# Tests for hubs.R

library(basalt)

# --- Setup ---
hubs_dir <- tempfile("hubs")

# --- hub: create a hub ---

path <- hub("test_concept", "# Test\n\n[[basalt::query]]\n[[basalt::status]]",
            hubs_dir = hubs_dir)
expect_true(file.exists(path))
expect_true(grepl("test_concept\\.md$", path))

# --- hubs: list hubs ---

h <- hubs(hubs_dir = hubs_dir)
expect_true(is.data.frame(h))
expect_equal(nrow(h), 1L)
expect_equal(h$name, "test_concept")
expect_true(grepl("basalt::query", h$links))
expect_true(grepl("basalt::status", h$links))

# --- hub: update existing ---

hub("test_concept", "# Updated\n\n[[basalt::briefing]]",
    hubs_dir = hubs_dir)
h2 <- hubs(hubs_dir = hubs_dir)
expect_equal(nrow(h2), 1L)
expect_true(grepl("basalt::briefing", h2$links))

# --- Multiple hubs ---

hub("other_concept", "# Other\n\n[[torch::nn_linear]]",
    hubs_dir = hubs_dir)
h3 <- hubs(hubs_dir = hubs_dir)
expect_equal(nrow(h3), 2L)

# --- Empty hubs dir ---

empty_dir <- tempfile("empty_hubs")
h4 <- hubs(hubs_dir = empty_dir)
expect_equal(nrow(h4), 0L)

# --- Cleanup ---
unlink(c(hubs_dir, empty_dir), recursive = TRUE)
