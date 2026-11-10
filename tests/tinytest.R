if (requireNamespace("tinytest", quietly = TRUE)) {
    # Keep every R_user_dir() write, including transitive ones, inside the
    # check's temporary area.
    Sys.setenv(R_USER_CACHE_DIR = tempfile("saber_cache_"),
               R_USER_DATA_DIR = tempfile("saber_data_"),
               R_USER_CONFIG_DIR = tempfile("saber_config_"))
    tinytest::test_package("saber")
}
