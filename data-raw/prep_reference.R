# Run after any ANA app release that updates reference.json.
# Fetches the canonical reference from the ANA app repo and writes the
# internal ana_reference dataset to R/sysdata.rda.

url <- paste0(
  "https://raw.githubusercontent.com/gnoblet/ANA_app_svelte/main/",
  "static/data/reference.json"
)
tmp <- tempfile(fileext = ".json")
download.file(url, tmp, quiet = TRUE)
ana_reference <- jsonlite::read_json(tmp, simplifyVector = FALSE)
usethis::use_data(ana_reference, internal = TRUE, overwrite = TRUE)
