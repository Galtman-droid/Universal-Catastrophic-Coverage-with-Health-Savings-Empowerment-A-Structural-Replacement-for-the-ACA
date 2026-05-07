# ============================================================
# combine_all_scripts_into_one_document.R
# UCC/HSE Provider Impact Model
# Combines all numbered R scripts into one readable document
# ============================================================

# ---- USER SETTINGS ----

# Set this to the folder containing your R scripts.
# If this script is inside the Scripts folder, use "."
scripts_dir <- "Scripts"

# Output folder
output_dir <- "Output"

# Output file names
combined_md_file <- file.path(output_dir, "UCC_HSE_Provider_Impact_All_Scripts_Combined.md")
combined_r_file  <- file.path(output_dir, "UCC_HSE_Provider_Impact_All_Scripts_Combined.R")

# Whether to include only numbered scripts like 00_setup.R, 08_extract_...
only_numbered_scripts <- TRUE


# ---- SETUP ----

if (!dir.exists(scripts_dir)) {
  stop("Scripts folder not found: ", scripts_dir)
}

if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

# Get all R scripts
script_files <- list.files(
  path = scripts_dir,
  pattern = "\\.R$",
  full.names = TRUE
)

if (only_numbered_scripts) {
  script_files <- script_files[
    grepl("^[0-9]+[A-Za-z]*_", basename(script_files)) |
      grepl("^[0-9]+_", basename(script_files))
  ]
}

if (length(script_files) == 0) {
  stop("No R scripts found in: ", scripts_dir)
}


# ---- SORT FILES BY NUMERIC PREFIX ----

get_script_order <- function(path) {
  fname <- basename(path)
  
  # Extract starting number, including cases like 08A, 13B, etc.
  prefix <- sub("^([0-9]+)([A-Za-z]*).*", "\\1|\\2", fname)
  parts <- strsplit(prefix, "\\|")[[1]]
  
  num_part <- suppressWarnings(as.numeric(parts[1]))
  letter_part <- ifelse(length(parts) > 1, parts[2], "")
  
  if (is.na(num_part)) num_part <- 9999
  
  # Convert letter suffix to small decimal order:
  # 08A after 08, before 09
  letter_score <- ifelse(
    letter_part == "",
    0,
    match(toupper(letter_part), LETTERS) / 100
  )
  
  num_part + letter_score
}

script_order <- vapply(script_files, get_script_order, numeric(1))
script_files <- script_files[order(script_order, basename(script_files))]


# ---- COMBINE INTO MARKDOWN DOCUMENT ----

md_lines <- c(
  "# UCC/HSE Provider Impact Model — Combined R Scripts",
  "",
  paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  "",
  paste0("Scripts folder: `", normalizePath(scripts_dir, winslash = "/"), "`"),
  "",
  "## Included Scripts",
  "",
  paste0(seq_along(script_files), ". `", basename(script_files), "`"),
  "",
  "---",
  ""
)

for (f in script_files) {
  fname <- basename(f)
  code_lines <- readLines(f, warn = FALSE)
  
  md_lines <- c(
    md_lines,
    paste0("# ", fname),
    "",
    "```r",
    code_lines,
    "```",
    "",
    "---",
    ""
  )
}

writeLines(md_lines, combined_md_file, useBytes = TRUE)


# ---- COMBINE INTO ONE R FILE ----
# This preserves code as executable R, with file headers inserted as comments.

r_lines <- c(
  "# ============================================================",
  "# UCC/HSE Provider Impact Model — Combined R Scripts",
  paste0("# Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  paste0("# Scripts folder: ", normalizePath(scripts_dir, winslash = "/")),
  "# ============================================================",
  "",
  "# Included scripts:",
  paste0("# ", seq_along(script_files), ". ", basename(script_files)),
  "",
  ""
)

for (f in script_files) {
  fname <- basename(f)
  code_lines <- readLines(f, warn = FALSE)
  
  r_lines <- c(
    r_lines,
    "",
    "# ============================================================",
    paste0("# BEGIN SCRIPT: ", fname),
    "# ============================================================",
    "",
    code_lines,
    "",
    "# ============================================================",
    paste0("# END SCRIPT: ", fname),
    "# ============================================================",
    ""
  )
}

writeLines(r_lines, combined_r_file, useBytes = TRUE)


# ---- PRINT SUMMARY ----

cat("\n============================================================\n")
cat("SCRIPT COMBINATION COMPLETE\n")
cat("============================================================\n")
cat("Scripts combined:", length(script_files), "\n\n")

cat("Included scripts in order:\n")
for (i in seq_along(script_files)) {
  cat(sprintf("%02d. %s\n", i, basename(script_files[i])))
}

cat("\nSaved Markdown document:\n")
cat(normalizePath(combined_md_file, winslash = "/"), "\n")

cat("\nSaved combined R file:\n")
cat(normalizePath(combined_r_file, winslash = "/"), "\n")
cat("============================================================\n")