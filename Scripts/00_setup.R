# Scripts/00_setup.R
# UCC/HSE Provider Impact Model setup
# Version: FY2024 HCRIS build
#
# Purpose:
#   Shared setup file for the UCC/HSE HCRIS provider-impact model.
#   This script defines packages, project paths, input files, output folders,
#   and build-year labels used by all downstream scripts.
#
# Repository note:
#   This version is portable. It assumes the user has opened the RStudio
#   project from the repository root, or has otherwise set the working
#   directory to the repository root before sourcing this script.
#
#   Do NOT rename the path variables below unless all downstream scripts
#   are updated as well.

# ============================================================
# 1. Package setup
# ============================================================

required_packages <- c(
  "data.table",
  "readr",
  "readxl",
  "openxlsx",
  "writexl",
  "dplyr",
  "tidyr",
  "stringr",
  "lubridate",
  "janitor",
  "here",
  "tools"
)

installed <- rownames(installed.packages())

missing_packages <- setdiff(required_packages, installed)

if (length(missing_packages) > 0) {
  message("Installing missing packages: ", paste(missing_packages, collapse = ", "))
  install.packages(missing_packages, dependencies = TRUE)
}

invisible(lapply(required_packages, library, character.only = TRUE))

# ============================================================
# 2. Project paths
# ============================================================

# Portable project root.
#
# Preferred use:
#   Open the repository's .Rproj file in RStudio before running the scripts.
#
# Why this matters:
#   The old setup used a hardcoded path on Bennett's local machine.
#   That worked locally but would fail for anyone cloning the Git repository.
#
# This keeps all downstream object names unchanged while making the model portable.

path_project_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)

# Safety check: make sure the working directory is actually the repository root.
# If this fails, open the .Rproj file or setwd() to the repository root.

if (!dir.exists(file.path(path_project_root, "Scripts"))) {
  stop(
    "Project root appears incorrect. The folder 'Scripts' was not found.\n",
    "Open the repository .Rproj file in RStudio, or set the working directory to the repository root.\n",
    "Current working directory is: ", path_project_root
  )
}

# FY2024 raw HCRIS folder.
#
# Raw CMS HCRIS files are not expected to be committed to GitHub.
# To rerun the full raw-data pipeline, place the FY2024 files here:
#
#   FY2024/2024 Hospital Fiscal Reports HCRIS/
#
# Required raw files:
#   HOSP10_2024_alpha.csv
#   HOSP10_2024_nmrc.csv
#   HOSP10_2024_rpt.csv

path_hcris_raw_2024 <- file.path(
  path_project_root,
  "FY2024",
  "2024 Hospital Fiscal Reports HCRIS"
)

# HCRIS documentation folder.
# This can contain CMS worksheet documentation, variable notes, and project notes.

path_hcris_doc <- file.path(
  path_project_root,
  "HCRIS ModelingDocumentation"
)

# Core project folders.

path_scripts <- file.path(path_project_root, "Scripts")
path_processed <- file.path(path_project_root, "Processed")
path_processed_public <- file.path(path_project_root, "Processed_Public")
path_output <- file.path(path_project_root, "Output")

# Optional organized output folders.
# Downstream scripts may or may not use these directly, but defining them here
# makes the repository structure clearer and keeps future scripts consistent.

path_output_tables <- file.path(path_output, "Table7_Publication")
path_output_figures <- file.path(path_output, "Table7_Compact_Publication_Figures")
path_output_images <- file.path(path_output, "Table7_Table_Images")
path_output_intermediate <- file.path(path_output, "intermediate")
path_output_temp <- file.path(path_output, "temp")

# ============================================================
# 3. Create output folders if missing
# ============================================================

dir.create(path_processed, showWarnings = FALSE, recursive = TRUE)
dir.create(path_processed_public, showWarnings = FALSE, recursive = TRUE)
dir.create(path_output, showWarnings = FALSE, recursive = TRUE)

dir.create(path_output_tables, showWarnings = FALSE, recursive = TRUE)
dir.create(path_output_figures, showWarnings = FALSE, recursive = TRUE)
dir.create(path_output_images, showWarnings = FALSE, recursive = TRUE)
dir.create(path_output_intermediate, showWarnings = FALSE, recursive = TRUE)
dir.create(path_output_temp, showWarnings = FALSE, recursive = TRUE)

# ============================================================
# 4. File paths for FY2024 HCRIS
# ============================================================

file_hcris_alpha <- file.path(path_hcris_raw_2024, "HOSP10_2024_alpha.csv")
file_hcris_nmrc  <- file.path(path_hcris_raw_2024, "HOSP10_2024_nmrc.csv")
file_hcris_rpt   <- file.path(path_hcris_raw_2024, "HOSP10_2024_rpt.csv")

# ============================================================
# 5. Build year label
# ============================================================

hcris_year <- 2024
hcris_year_label <- "2024"

# ============================================================
# 6. Raw-file safety checks
# ============================================================

# This setup script checks for raw HCRIS files because the full pipeline depends
# on them. If a user is reproducing only from Processed_Public master .rds files,
# they can either skip the raw-ingestion scripts or set require_raw_hcris <- FALSE.

require_raw_hcris <- TRUE

if (require_raw_hcris) {
  
  required_files <- c(
    file_hcris_alpha,
    file_hcris_nmrc,
    file_hcris_rpt
  )
  
  missing_files <- required_files[!file.exists(required_files)]
  
  if (length(missing_files) > 0) {
    stop(
      "Missing required FY2024 HCRIS files:\n",
      paste(missing_files, collapse = "\n"),
      "\n\nTo rerun the full raw-data pipeline, download the FY2024 CMS HCRIS files and place them in:\n",
      path_hcris_raw_2024,
      "\n\nRequired files:\n",
      "HOSP10_2024_alpha.csv\n",
      "HOSP10_2024_nmrc.csv\n",
      "HOSP10_2024_rpt.csv\n\n",
      "If you are reproducing only from curated Processed_Public master .rds files, ",
      "set require_raw_hcris <- FALSE in Scripts/00_setup.R or use the processed-file workflow."
    )
  }
}

if (!dir.exists(path_hcris_doc)) {
  warning(
    "HCRIS documentation folder not found: ",
    path_hcris_doc,
    "\nThis is not fatal unless a downstream script requires local documentation files."
  )
}

# ============================================================
# 7. Print setup summary
# ============================================================

cat("\n============================================================\n")
cat("UCC/HSE Provider Impact Model setup complete\n")
cat("============================================================\n")
cat("Build year:                 ", hcris_year, "\n")
cat("Project root:               ", path_project_root, "\n")
cat("HCRIS FY2024 raw folder:    ", path_hcris_raw_2024, "\n")
cat("HCRIS documentation folder: ", path_hcris_doc, "\n")
cat("Scripts folder:             ", path_scripts, "\n")
cat("Processed folder:           ", path_processed, "\n")
cat("Processed public folder:    ", path_processed_public, "\n")
cat("Output folder:              ", path_output, "\n")
cat("Output tables folder:       ", path_output_tables, "\n")
cat("Output figures folder:      ", path_output_figures, "\n")
cat("Output images folder:       ", path_output_images, "\n")
cat("Alpha file:                 ", file_hcris_alpha, "\n")
cat("NMRC file:                  ", file_hcris_nmrc, "\n")
cat("RPT file:                   ", file_hcris_rpt, "\n")
cat("Require raw HCRIS files:    ", require_raw_hcris, "\n")
cat("============================================================\n\n")