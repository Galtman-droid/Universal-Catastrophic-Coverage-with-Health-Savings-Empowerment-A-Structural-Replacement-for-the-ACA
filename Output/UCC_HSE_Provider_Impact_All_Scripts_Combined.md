# UCC/HSE Provider Impact Model — Combined R Scripts

Generated: 2026-05-06 12:44:27

Scripts folder: `C:/Users/Bennett/OneDrive/Desktop/Buisnesses/Political letters/Universal Catastraphic Coverage/Scripts`

## Included Scripts

1. `00_install_required_packages.R`
2. `00_setup.R`
3. `02_load_full_hcris.R`
4. `04_create_rpt_base.R`
5. `05_create_provider_master.R`
6. `05A_inspect_provider_identity_fields.R`
7. `05B_target_provider_identity_mapping.R`
8. `05C_inspect_S200001_identity_block.R`
9. `06_extract_beds_capacity.R`
10. `06A_inspect_S3_capacity_columns.R`
11. `06B_validate_S3_utilization_mapping.R`
12. `07_extract_s10_uncompensated_care.R`
13. `08_extract_g2_g3_revenue_expense.R`
14. `08A_diagnose_revenue_failures.R`
15. `08B_diagnose_childrens_cah_revenue_failures.R`
16. `09_validate_provider_classification.R`
17. `10_create_stabilization_eligibility.R`
18. `11_create_provider_impact_scenarios.R`
19. `11A_audit_provider_impact_coverage_and_exposure.R`
20. `12_format_table7_publication_outputs.R`
21. `13_provider_transition_protection_sensitivity.R`
22. `13B_enhanced_rural_access_sensitivity.R`
23. `13C_behavioral_psychiatric_sensitivity.R`
24. `14_create_table7_access_protection_summary.R`
25. `15_make_table7_publication_grade_tables.R`
26. `16_make_table7_publication_table_images.R`
27. `17_make_table7_compact_publication_figures.R`

---

# 00_install_required_packages.R

```r
# Scripts/00_install_required_packages.R
# Rebuild / refresh the R package library needed for the UCC/HSE HCRIS model.
#
# Run this from the project root:
# source("Scripts/00_install_required_packages.R")

cat("\n============================================================\n")
cat("REBUILD / REFRESH REQUIRED R PACKAGES\n")
cat("============================================================\n\n")

# ============================================================
# 1. Required CRAN packages
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

# Packages that may already exist as base/recommended packages.
# install.packages() will skip base packages automatically if unavailable on CRAN,
# but keeping tools in the list is harmless because it is usually already installed.
required_packages <- unique(required_packages)

# ============================================================
# 2. Choose CRAN mirror
# ============================================================

options(repos = c(CRAN = "https://cloud.r-project.org"))

# ============================================================
# 3. Report current library paths
# ============================================================

cat("R version:\n")
print(R.version.string)

cat("\nLibrary paths:\n")
print(.libPaths())

cat("\nRequired packages:\n")
print(required_packages)

# ============================================================
# 4. Install missing packages
# ============================================================

installed <- rownames(installed.packages())

missing_packages <- setdiff(required_packages, installed)

if (length(missing_packages) > 0) {
  cat("\nInstalling missing packages:\n")
  print(missing_packages)
  
  install.packages(
    missing_packages,
    dependencies = TRUE
  )
} else {
  cat("\nNo missing packages detected.\n")
}

# ============================================================
# 5. Optional package refresh
# ============================================================

# Set this to TRUE only if you want to reinstall all required packages even if present.
force_reinstall <- FALSE

if (force_reinstall == TRUE) {
  cat("\nForce reinstall is TRUE. Reinstalling required packages:\n")
  print(required_packages)
  
  install.packages(
    required_packages,
    dependencies = TRUE
  )
} else {
  cat("\nForce reinstall is FALSE. Existing packages were not reinstalled.\n")
}

# ============================================================
# 6. Load-test packages
# ============================================================

cat("\nLoad-testing required packages:\n")

load_results <- data.frame(
  package = character(),
  loaded = logical(),
  version = character(),
  error = character(),
  stringsAsFactors = FALSE
)

for (pkg in required_packages) {
  result <- tryCatch(
    {
      suppressPackageStartupMessages(
        library(pkg, character.only = TRUE)
      )
      
      pkg_version <- as.character(utils::packageVersion(pkg))
      
      data.frame(
        package = pkg,
        loaded = TRUE,
        version = pkg_version,
        error = "",
        stringsAsFactors = FALSE
      )
    },
    error = function(e) {
      data.frame(
        package = pkg,
        loaded = FALSE,
        version = NA_character_,
        error = conditionMessage(e),
        stringsAsFactors = FALSE
      )
    }
  )
  
  load_results <- rbind(load_results, result)
}

print(load_results)

# ============================================================
# 7. Stop if anything failed
# ============================================================

failed <- load_results[load_results$loaded == FALSE, ]

if (nrow(failed) > 0) {
  cat("\nSome packages failed to load:\n")
  print(failed)
  
  stop("Package rebuild incomplete. Fix failed packages above before rerunning the model.")
}

# ============================================================
# 8. Session info
# ============================================================

cat("\nSession info:\n")
print(sessionInfo())

cat("\n============================================================\n")
cat("R PACKAGE SETUP COMPLETE\n")
cat("============================================================\n")
```

---

# 00_setup.R

```r
# Scripts/00_setup.R
# UCC/HSE Provider Impact Model setup
# Version: FY2024 HCRIS build

# ============================================================
# 1. Package setup
# ============================================================

required_packages <- c(
  "data.table",
  "readr",
  "readxl",
  "openxlsx",
  "stringr",
  "lubridate",
  "janitor",
  "dplyr"
)

installed <- rownames(installed.packages())

for (pkg in required_packages) {
  if (!pkg %in% installed) {
    install.packages(pkg)
  }
}

invisible(lapply(required_packages, library, character.only = TRUE))

# ============================================================
# 2. Project paths
# ============================================================

path_project_root <- "C:/Users/Bennett/OneDrive/Desktop/Buisnesses/Political letters/Universal Catastraphic Coverage"

# FY2024 raw HCRIS folder from your screenshot
path_hcris_raw_2024 <- file.path(
  path_project_root,
  "FY2024",
  "2024 Hospital Fiscal Reports HCRIS"
)

# Keep your existing documentation folder
path_hcris_doc <- file.path(
  path_project_root,
  "HCRIS ModelingDocumentation"
)

path_scripts <- file.path(path_project_root, "Scripts")
path_processed <- file.path(path_project_root, "Processed")
path_output <- file.path(path_project_root, "Output")

# ============================================================
# 3. Create output folders if missing
# ============================================================

dir.create(path_processed, showWarnings = FALSE, recursive = TRUE)
dir.create(path_output, showWarnings = FALSE, recursive = TRUE)

# ============================================================
# 4. File paths for FY2024 HCRIS
# ============================================================

file_hcris_alpha <- file.path(path_hcris_raw_2024, "HOSP10_2024_alpha.csv")
file_hcris_nmrc  <- file.path(path_hcris_raw_2024, "HOSP10_2024_nmrc.csv")
file_hcris_rpt   <- file.path(path_hcris_raw_2024, "HOSP10_2024_rpt.csv")

# ============================================================
# 5. Safety checks
# ============================================================

required_files <- c(
  file_hcris_alpha,
  file_hcris_nmrc,
  file_hcris_rpt
)

missing_files <- required_files[!file.exists(required_files)]

if (length(missing_files) > 0) {
  stop(
    "Missing required FY2024 HCRIS files:\n",
    paste(missing_files, collapse = "\n")
  )
}

if (!dir.exists(path_hcris_doc)) {
  warning("HCRIS documentation folder not found: ", path_hcris_doc)
}

# ============================================================
# 6. Build year label
# ============================================================

hcris_year <- 2024
hcris_year_label <- "2024"

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
cat("Output folder:              ", path_output, "\n")
cat("Alpha file:                 ", file_hcris_alpha, "\n")
cat("NMRC file:                  ", file_hcris_nmrc, "\n")
cat("RPT file:                   ", file_hcris_rpt, "\n")
cat("============================================================\n\n")
```

---

# 02_load_full_hcris.R

```r
# Scripts/02_load_full_hcris.R
# Load full CMS HCRIS hospital cost-report files
# Corrected for CMS files that do NOT include header rows.
#
# Inputs expected from 00_setup.R:
#   file_hcris_alpha
#   file_hcris_nmrc
#   file_hcris_rpt
#   path_processed
#   path_output
#   hcris_year_label
#
# Outputs:
#   Processed/hcris_YYYY_alpha.rds
#   Processed/hcris_YYYY_nmrc.rds
#   Processed/hcris_YYYY_rpt.rds
#   Output/hcris_YYYY_load_summary.csv

source("Scripts/00_setup.R")

cat("\n============================================================\n")
cat("LOAD FULL HCRIS FILES\n")
cat("============================================================\n")
cat("Build year:", hcris_year_label, "\n\n")

# ============================================================
# 1. Safety checks
# ============================================================

required_files <- c(
  alpha = file_hcris_alpha,
  nmrc  = file_hcris_nmrc,
  rpt   = file_hcris_rpt
)

missing_files <- required_files[!file.exists(required_files)]

if (length(missing_files) > 0) {
  stop(
    "Missing HCRIS input files:\n",
    paste(names(missing_files), missing_files, sep = ": ", collapse = "\n")
  )
}

# ============================================================
# 2. CMS HCRIS column names
# ============================================================

alpha_cols <- c(
  "rpt_rec_num",
  "wksht_cd",
  "line_num",
  "clmn_num",
  "itm_alphnmrc_itm_txt"
)

nmrc_cols <- c(
  "rpt_rec_num",
  "wksht_cd",
  "line_num",
  "clmn_num",
  "itm_val_num"
)

# Hospital 2552-10 RPT file has 18 fields.
# These names match the structure we used downstream in the FY2025 model.
rpt_cols <- c(
  "rpt_rec_num",
  "prvdr_ctrl_type_cd",
  "prvdr_num",
  "npi",
  "rpt_stus_cd",
  "fy_bgn_dt",
  "fy_end_dt",
  "proc_dt",
  "initl_rpt_sw",
  "last_rpt_sw",
  "trnsmtl_num",
  "fi_num",
  "adr_vndr_cd",
  "fi_creat_dt",
  "util_cd",
  "npr_dt",
  "spec_ind",
  "fi_rcpt_dt"
)

# ============================================================
# 3. Helper functions
# ============================================================

pad_left <- function(x, width) {
  stringr::str_pad(as.character(x), width = width, side = "left", pad = "0")
}

print_basic_profile <- function(dt, dt_name) {
  cat("\n------------------------------------------------------------\n")
  cat(dt_name, "profile\n")
  cat("------------------------------------------------------------\n")
  cat("Rows:   ", format(nrow(dt), big.mark = ","), "\n")
  cat("Columns:", ncol(dt), "\n")
  cat("Column names:\n")
  print(names(dt))
}

parse_hcris_date <- function(x) {
  x_chr <- as.character(x)
  
  out <- suppressWarnings(lubridate::ymd(x_chr))
  
  if (all(is.na(out))) {
    out <- suppressWarnings(lubridate::mdy(x_chr))
  }
  
  if (all(is.na(out))) {
    out <- suppressWarnings(lubridate::as_date(as.numeric(x_chr), origin = "1899-12-30"))
  }
  
  out
}

# ============================================================
# 4. Load raw CSV files without headers
# ============================================================

cat("\nReading ALPHA file:\n", file_hcris_alpha, "\n", sep = "")

alpha <- data.table::fread(
  file_hcris_alpha,
  header = FALSE,
  col.names = alpha_cols,
  showProgress = TRUE,
  na.strings = c("", "NA", "NULL")
)

cat("\nReading NMRC file:\n", file_hcris_nmrc, "\n", sep = "")

nmrc <- data.table::fread(
  file_hcris_nmrc,
  header = FALSE,
  col.names = nmrc_cols,
  showProgress = TRUE,
  na.strings = c("", "NA", "NULL")
)

cat("\nReading RPT file:\n", file_hcris_rpt, "\n", sep = "")

rpt <- data.table::fread(
  file_hcris_rpt,
  header = FALSE,
  col.names = rpt_cols,
  showProgress = TRUE,
  na.strings = c("", "NA", "NULL")
)

print_basic_profile(alpha, "ALPHA")
print_basic_profile(nmrc, "NMRC")
print_basic_profile(rpt, "RPT")

# ============================================================
# 5. Normalize key fields
# ============================================================

alpha[, rpt_rec_num := as.integer(rpt_rec_num)]
nmrc[,  rpt_rec_num := as.integer(rpt_rec_num)]
rpt[,   rpt_rec_num := as.integer(rpt_rec_num)]

alpha[, wksht_cd := stringr::str_trim(as.character(wksht_cd))]
nmrc[,  wksht_cd := stringr::str_trim(as.character(wksht_cd))]

alpha[, line_num_chr := pad_left(line_num, 5)]
alpha[, clmn_num_chr := pad_left(clmn_num, 5)]

nmrc[, line_num_chr := pad_left(line_num, 5)]
nmrc[, clmn_num_chr := pad_left(clmn_num, 5)]

nmrc[, itm_val_num := suppressWarnings(as.numeric(itm_val_num))]

alpha[
  ,
  itm_alphnmrc_itm_txt := stringr::str_squish(as.character(itm_alphnmrc_itm_txt))
]

rpt[
  ,
  prvdr_num_chr := stringr::str_pad(
    as.character(prvdr_num),
    width = 6,
    side = "left",
    pad = "0"
  )
]

# ============================================================
# 6. Parse RPT dates and report days
# ============================================================

date_cols <- c("fy_bgn_dt", "fy_end_dt", "proc_dt", "fi_creat_dt", "npr_dt", "fi_rcpt_dt")

for (dc in intersect(date_cols, names(rpt))) {
  rpt[, paste0(dc, "_parsed") := parse_hcris_date(get(dc))]
}

if (all(c("fy_bgn_dt_parsed", "fy_end_dt_parsed") %in% names(rpt))) {
  rpt[
    ,
    report_days := as.integer(fy_end_dt_parsed - fy_bgn_dt_parsed) + 1L
  ]
}

# ============================================================
# 7. Basic validation summaries
# ============================================================

cat("\n============================================================\n")
cat("BASIC VALIDATION SUMMARIES\n")
cat("============================================================\n")

cat("\nUnique report record numbers:\n")
cat("ALPHA:", data.table::uniqueN(alpha$rpt_rec_num), "\n")
cat("NMRC: ", data.table::uniqueN(nmrc$rpt_rec_num), "\n")
cat("RPT:  ", data.table::uniqueN(rpt$rpt_rec_num), "\n")

cat("\nWorksheet counts, ALPHA top 25:\n")
print(alpha[, .N, by = wksht_cd][order(-N)][1:25])

cat("\nWorksheet counts, NMRC top 25:\n")
print(nmrc[, .N, by = wksht_cd][order(-N)][1:25])

cat("\nRPT status counts:\n")
print(rpt[, .N, by = rpt_stus_cd][order(rpt_stus_cd)])

cat("\nProvider control type counts:\n")
print(rpt[, .N, by = prvdr_ctrl_type_cd][order(prvdr_ctrl_type_cd)])

cat("\nReport days summary:\n")
print(summary(rpt$report_days))

cat("\nFirst 10 RPT records:\n")
print(rpt[
  1:10,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    rpt_stus_cd,
    fy_bgn_dt,
    fy_end_dt,
    fy_bgn_dt_parsed,
    fy_end_dt_parsed,
    report_days
  )
])

# ============================================================
# 8. Save processed RDS files
# ============================================================

alpha_rds <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_alpha.rds")
)

nmrc_rds <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_nmrc.rds")
)

rpt_rds <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_rpt.rds")
)

saveRDS(alpha, alpha_rds)
saveRDS(nmrc, nmrc_rds)
saveRDS(rpt, rpt_rds)

# ============================================================
# 9. Save load summary
# ============================================================

load_summary <- data.table::data.table(
  hcris_year = hcris_year_label,
  table = c("alpha", "nmrc", "rpt"),
  source_file = c(file_hcris_alpha, file_hcris_nmrc, file_hcris_rpt),
  rows = c(nrow(alpha), nrow(nmrc), nrow(rpt)),
  columns = c(ncol(alpha), ncol(nmrc), ncol(rpt)),
  unique_rpt_rec_num = c(
    data.table::uniqueN(alpha$rpt_rec_num),
    data.table::uniqueN(nmrc$rpt_rec_num),
    data.table::uniqueN(rpt$rpt_rec_num)
  ),
  output_rds = c(alpha_rds, nmrc_rds, rpt_rds)
)

summary_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_load_summary.csv")
)

data.table::fwrite(load_summary, summary_csv)

# ============================================================
# 10. Final output
# ============================================================

cat("\n============================================================\n")
cat("HCRIS LOAD COMPLETE\n")
cat("============================================================\n")

cat("\nSaved RDS files:\n")
cat(alpha_rds, "\n")
cat(nmrc_rds, "\n")
cat(rpt_rds, "\n")

cat("\nSaved summary:\n")
cat(summary_csv, "\n")

cat("\nLoad summary:\n")
print(load_summary)

cat("\n============================================================\n")
```

---

# 04_create_rpt_base.R

```r
# Scripts/04_create_rpt_base.R
# Create HCRIS report/provider base table from RPT file
# Compatible with year-flexible setup from Scripts/00_setup.R
#
# Input:
#   Processed/hcris_YYYY_rpt.rds
#
# Outputs:
#   Processed/hcris_YYYY_rpt_base.rds
#   Output/hcris_YYYY_rpt_base.csv

source("Scripts/00_setup.R")

cat("\n============================================================\n")
cat("CREATE HCRIS RPT BASE\n")
cat("============================================================\n")
cat("Build year:", hcris_year_label, "\n\n")

# ============================================================
# 1. Load RPT file
# ============================================================

rpt_file <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_rpt.rds")
)

if (!file.exists(rpt_file)) {
  stop("Missing processed RPT file: ", rpt_file)
}

rpt <- readRDS(rpt_file)

cat("Loaded RPT file:\n")
cat(rpt_file, "\n")
cat("Rows:", nrow(rpt), "\n")
cat("Columns:", ncol(rpt), "\n")

# ============================================================
# 2. Basic safety checks
# ============================================================

required_cols <- c(
  "rpt_rec_num",
  "prvdr_num_chr",
  "prvdr_ctrl_type_cd",
  "rpt_stus_cd",
  "fy_bgn_dt",
  "fy_end_dt",
  "fy_bgn_dt_parsed",
  "fy_end_dt_parsed",
  "report_days"
)

missing_cols <- setdiff(required_cols, names(rpt))

if (length(missing_cols) > 0) {
  stop(
    "RPT file is missing required columns:\n",
    paste(missing_cols, collapse = "\n")
  )
}

# ============================================================
# 3. Deduplicate at report-record level
# ============================================================

rows_before <- nrow(rpt)

rpt_base <- unique(rpt, by = "rpt_rec_num")

rows_after <- nrow(rpt_base)

cat("\nRows before unique():", rows_before, "\n")
cat("Rows after unique(): ", rows_after, "\n")
cat("Rows removed:        ", rows_before - rows_after, "\n")

# ============================================================
# 4. Report status labels
# ============================================================

rpt_base[
  ,
  rpt_status_label := data.table::fcase(
    rpt_stus_cd == 1, "As submitted",
    rpt_stus_cd == 2, "Settled without audit",
    rpt_stus_cd == 3, "Settled with audit",
    rpt_stus_cd == 4, "Reopened",
    rpt_stus_cd == 5, "Amended",
    default = "Unknown / check"
  )
]

# ============================================================
# 5. Provider control / facility-type labels
# ============================================================

# For CMS hospital 2552-10 files, prvdr_ctrl_type_cd is the provider-control/facility-type code.
# We use the same labels used in the FY2025 build.

rpt_base[
  ,
  facility_type := data.table::fcase(
    prvdr_ctrl_type_cd == 1,  "Short Term (General and Specialty) Hospitals",
    prvdr_ctrl_type_cd == 2,  "Long-Term Hospitals (Excluded from PPS)",
    prvdr_ctrl_type_cd == 3,  "Religious Non-Medical Health Care Institutions",
    prvdr_ctrl_type_cd == 4,  "Psychiatric Hospitals (Excluded from PPS)",
    prvdr_ctrl_type_cd == 5,  "Rehabilitation Hospitals (Excluded from PPS)",
    prvdr_ctrl_type_cd == 6,  "Children's Hospitals (Excluded from PPS)",
    prvdr_ctrl_type_cd == 7,  "Rural Primary Care Hospitals",
    prvdr_ctrl_type_cd == 8,  "Other Hospitals",
    prvdr_ctrl_type_cd == 9,  "Other",
    prvdr_ctrl_type_cd == 10, "Critical Access Hospitals",
    prvdr_ctrl_type_cd == 11, "Hospital-Based Rural Health Clinics",
    prvdr_ctrl_type_cd == 12, "Freestanding Rural Health Clinics",
    prvdr_ctrl_type_cd == 13, "Federally Qualified Health Centers",
    default = "Unknown / check"
  )
]

# ============================================================
# 6. Provider model class
# ============================================================

rpt_base[
  ,
  provider_model_class := data.table::fcase(
    prvdr_ctrl_type_cd == 1,  "Short-term acute/general hospital",
    prvdr_ctrl_type_cd == 6,  "Children's hospital",
    prvdr_ctrl_type_cd == 7,  "Rural primary care hospital",
    prvdr_ctrl_type_cd == 10, "Critical access hospital",
    prvdr_ctrl_type_cd == 2,  "Long-term hospital",
    prvdr_ctrl_type_cd == 4,  "Psychiatric hospital",
    prvdr_ctrl_type_cd == 5,  "Rehabilitation hospital",
    prvdr_ctrl_type_cd %in% c(11, 12), "Rural health clinic",
    prvdr_ctrl_type_cd == 13, "Federally qualified health center",
    default = "Other / not primary hospital model"
  )
]

# ============================================================
# 7. Inclusion flags
# ============================================================

# Full-year report: allow 364-366 to handle leap years and minor report-date differences.
rpt_base[
  ,
  full_year_report_flag :=
    !is.na(report_days) &
    report_days >= 364 &
    report_days <= 366
]

# Broad candidate flag for provider-impact modeling.
rpt_base[
  ,
  provider_model_candidate :=
    provider_model_class %in% c(
      "Short-term acute/general hospital",
      "Children's hospital",
      "Rural primary care hospital",
      "Critical access hospital",
      "Long-term hospital",
      "Psychiatric hospital",
      "Rehabilitation hospital"
    )
]

# Main hospital-scoring universe for first-pass model.
# This is intentionally somewhat broad for FY2024 because CAHs appear explicitly.
rpt_base[
  ,
  acute_or_rural_include_v1 :=
    provider_model_class %in% c(
      "Short-term acute/general hospital",
      "Children's hospital",
      "Rural primary care hospital",
      "Critical access hospital"
    )
]

# Current backbone inclusion:
# full-year + core provider class + usable provider number.
rpt_base[
  ,
  provider_backbone_include_v1 :=
    full_year_report_flag == TRUE &
    acute_or_rural_include_v1 == TRUE &
    !is.na(prvdr_num_chr)
]

# ============================================================
# 8. State extraction from provider number
# ============================================================

# Medicare provider numbers/CCNs usually begin with a 2-digit state code.
rpt_base[
  ,
  prvdr_state_code := substr(prvdr_num_chr, 1, 2)
]

# This is a light label only. We can later replace with official POS/CMS state data.
state_code_lookup <- data.table::data.table(
  prvdr_state_code = sprintf("%02d", 1:99),
  state_code_numeric = 1:99
)

rpt_base <- merge(
  rpt_base,
  state_code_lookup,
  by = "prvdr_state_code",
  all.x = TRUE
)

# ============================================================
# 9. Keep useful columns first
# ============================================================

front_cols <- c(
  "rpt_rec_num",
  "prvdr_num_chr",
  "prvdr_state_code",
  "state_code_numeric",
  "npi",
  "prvdr_ctrl_type_cd",
  "facility_type",
  "provider_model_class",
  "rpt_stus_cd",
  "rpt_status_label",
  "fy_bgn_dt",
  "fy_end_dt",
  "fy_bgn_dt_parsed",
  "fy_end_dt_parsed",
  "report_days",
  "full_year_report_flag",
  "provider_model_candidate",
  "acute_or_rural_include_v1",
  "provider_backbone_include_v1"
)

front_cols <- intersect(front_cols, names(rpt_base))
other_cols <- setdiff(names(rpt_base), front_cols)

data.table::setcolorder(rpt_base, c(front_cols, other_cols))

# ============================================================
# 10. Save outputs
# ============================================================

rpt_base_rds <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_rpt_base.rds")
)

rpt_base_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_rpt_base.csv")
)

saveRDS(rpt_base, rpt_base_rds)
data.table::fwrite(rpt_base, rpt_base_csv)

# ============================================================
# 11. Print summaries
# ============================================================

cat("\n============================================================\n")
cat("RPT BASE CREATED\n")
cat("============================================================\n")

cat("\nRows:", nrow(rpt_base), "\n")
cat("Unique rpt_rec_num:", data.table::uniqueN(rpt_base$rpt_rec_num), "\n")
cat("Unique provider numbers:", data.table::uniqueN(rpt_base$prvdr_num_chr), "\n")

cat("\nFacility type distribution:\n")
print(rpt_base[, .N, by = facility_type][order(-N)])

cat("\nProvider model class distribution:\n")
print(rpt_base[, .N, by = provider_model_class][order(-N)])

cat("\nFull-year report flag:\n")
print(rpt_base[, .N, by = full_year_report_flag][order(full_year_report_flag)])

cat("\nProvider model candidate flag:\n")
print(rpt_base[, .N, by = provider_model_candidate][order(provider_model_candidate)])

cat("\nAcute/rural include flag:\n")
print(rpt_base[, .N, by = acute_or_rural_include_v1][order(acute_or_rural_include_v1)])

cat("\nProvider backbone include flag:\n")
print(rpt_base[, .N, by = provider_backbone_include_v1][order(provider_backbone_include_v1)])

cat("\nReport status labels:\n")
print(rpt_base[, .N, by = rpt_status_label][order(-N)])

cat("\nReport days summary by inclusion flag:\n")
print(rpt_base[
  ,
  .(
    n = .N,
    min_days = min(report_days, na.rm = TRUE),
    median_days = median(report_days, na.rm = TRUE),
    mean_days = mean(report_days, na.rm = TRUE),
    max_days = max(report_days, na.rm = TRUE)
  ),
  by = provider_backbone_include_v1
][order(provider_backbone_include_v1)])

cat("\nTop provider classes included in backbone:\n")
print(rpt_base[
  provider_backbone_include_v1 == TRUE,
  .N,
  by = provider_model_class
][order(-N)])

cat("\nSaved:\n")
cat(rpt_base_rds, "\n")
cat(rpt_base_csv, "\n")

cat("\n============================================================\n")
```

---

# 05_create_provider_master.R

```r
# Scripts/05_create_provider_master.R
# Create HCRIS provider master table from RPT base + corrected S200001 identity fields
# Compatible with year-flexible setup from Scripts/00_setup.R
#
# Inputs:
#   Processed/hcris_YYYY_rpt_base.rds
#   Processed/hcris_YYYY_alpha.rds
#
# Outputs:
#   Processed/hcris_YYYY_provider_master.rds
#   Output/hcris_YYYY_provider_master.csv
#   Output/hcris_YYYY_provider_identity_quality.csv
#
# Confirmed FY2024 identity mapping:
#   S200001 L00100 C00100 = street address line 1
#   S200001 L00100 C00200 = street address line 2 / secondary address
#   S200001 L00200 C00100 = city
#   S200001 L00200 C00200 = state
#   S200001 L00200 C00300 = ZIP
#   S200001 L00200 C00400 = county
#   S200001 L00300 C00100 = provider name
#   S200001 L00300 C00200 = provider number

source("Scripts/00_setup.R")

cat("\n============================================================\n")
cat("CREATE HCRIS PROVIDER MASTER\n")
cat("============================================================\n")
cat("Build year:", hcris_year_label, "\n\n")

# ============================================================
# 1. Load inputs
# ============================================================

rpt_base_file <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_rpt_base.rds")
)

alpha_file <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_alpha.rds")
)

if (!file.exists(rpt_base_file)) {
  stop("Missing RPT base file: ", rpt_base_file)
}

if (!file.exists(alpha_file)) {
  stop("Missing ALPHA file: ", alpha_file)
}

rpt_base <- readRDS(rpt_base_file)
alpha <- readRDS(alpha_file)

cat("Loaded:\n")
cat(rpt_base_file, "\n")
cat(alpha_file, "\n")

cat("\nRPT base rows:", nrow(rpt_base), "\n")
cat("ALPHA rows:", nrow(alpha), "\n")

# ============================================================
# 2. Safety checks
# ============================================================

required_rpt_cols <- c(
  "rpt_rec_num",
  "prvdr_num_chr",
  "provider_model_class",
  "provider_backbone_include_v1"
)

required_alpha_cols <- c(
  "rpt_rec_num",
  "wksht_cd",
  "line_num_chr",
  "clmn_num_chr",
  "itm_alphnmrc_itm_txt"
)

missing_rpt <- setdiff(required_rpt_cols, names(rpt_base))
missing_alpha <- setdiff(required_alpha_cols, names(alpha))

if (length(missing_rpt) > 0) {
  stop(
    "RPT base missing required columns:\n",
    paste(missing_rpt, collapse = "\n")
  )
}

if (length(missing_alpha) > 0) {
  stop(
    "ALPHA missing required columns:\n",
    paste(missing_alpha, collapse = "\n")
  )
}

# ============================================================
# 3. Extract S200001 identity block
# ============================================================

identity_long <- alpha[
  wksht_cd == "S200001" &
    line_num_chr %in% c("00100", "00200", "00300") &
    clmn_num_chr %in% c("00100", "00200", "00300", "00400") &
    !is.na(itm_alphnmrc_itm_txt) &
    itm_alphnmrc_itm_txt != "",
  .(
    rpt_rec_num,
    line_num_chr,
    clmn_num_chr,
    value = itm_alphnmrc_itm_txt
  )
]

identity_long[
  ,
  identity_field := data.table::fcase(
    line_num_chr == "00100" & clmn_num_chr == "00100", "street_address_1",
    line_num_chr == "00100" & clmn_num_chr == "00200", "street_address_2",
    line_num_chr == "00200" & clmn_num_chr == "00100", "city",
    line_num_chr == "00200" & clmn_num_chr == "00200", "state_abbrev",
    line_num_chr == "00200" & clmn_num_chr == "00300", "zip_code",
    line_num_chr == "00200" & clmn_num_chr == "00400", "county",
    line_num_chr == "00300" & clmn_num_chr == "00100", "provider_name",
    line_num_chr == "00300" & clmn_num_chr == "00200", "provider_number_alpha",
    default = NA_character_
  )
]

identity_long <- identity_long[!is.na(identity_field)]

# If duplicate report-field rows exist, keep first nonmissing value.
identity_long_dedup <- identity_long[
  ,
  .(
    value = value[which(!is.na(value) & value != "")[1]]
  ),
  by = .(rpt_rec_num, identity_field)
]

provider_identity <- data.table::dcast(
  identity_long_dedup,
  rpt_rec_num ~ identity_field,
  value.var = "value"
)

# Add combined address field.
provider_identity[
  ,
  street_address := data.table::fifelse(
    !is.na(street_address_2) & street_address_2 != "",
    paste(street_address_1, street_address_2),
    street_address_1
  )
]

# Normalize ZIP.
provider_identity[
  ,
  zip_code := stringr::str_trim(as.character(zip_code))
]

provider_identity[
  ,
  zip_code := data.table::fifelse(
    zip_code %in% c("-", "--", "00000", "NA"),
    NA_character_,
    zip_code
  )
]

# Normalize state.
provider_identity[
  ,
  state_abbrev := stringr::str_to_upper(stringr::str_trim(as.character(state_abbrev)))
]

# ============================================================
# 4. Merge with RPT base
# ============================================================

provider_master <- merge(
  rpt_base,
  provider_identity[
    ,
    .(
      rpt_rec_num,
      provider_name,
      street_address,
      street_address_1,
      street_address_2,
      city,
      state_abbrev,
      zip_code,
      county,
      provider_number_alpha
    )
  ],
  by = "rpt_rec_num",
  all.x = TRUE
)

# ============================================================
# 5. Add validation / quality flags
# ============================================================

provider_master[
  ,
  provider_name_missing_flag :=
    is.na(provider_name) | provider_name == ""
]

provider_master[
  ,
  address_missing_flag :=
    is.na(street_address_1) | street_address_1 == ""
]

provider_master[
  ,
  city_missing_flag :=
    is.na(city) | city == ""
]

provider_master[
  ,
  state_missing_flag :=
    is.na(state_abbrev) | state_abbrev == ""
]

provider_master[
  ,
  zip_missing_flag :=
    is.na(zip_code) | zip_code == ""
]

provider_master[
  ,
  alpha_provider_number_matches_rpt :=
    !is.na(provider_number_alpha) &
    provider_number_alpha == prvdr_num_chr
]

provider_master[
  ,
  identity_complete_flag :=
    provider_name_missing_flag == FALSE &
    address_missing_flag == FALSE &
    city_missing_flag == FALSE &
    state_missing_flag == FALSE &
    zip_missing_flag == FALSE
]

# ============================================================
# 6. Keep useful columns first
# ============================================================

front_cols <- c(
  "rpt_rec_num",
  "prvdr_num_chr",
  "provider_number_alpha",
  "alpha_provider_number_matches_rpt",
  "provider_name",
  "street_address",
  "street_address_1",
  "street_address_2",
  "city",
  "state_abbrev",
  "zip_code",
  "county",
  "prvdr_state_code",
  "state_code_numeric",
  "npi",
  "prvdr_ctrl_type_cd",
  "facility_type",
  "provider_model_class",
  "rpt_stus_cd",
  "rpt_status_label",
  "fy_bgn_dt",
  "fy_end_dt",
  "fy_bgn_dt_parsed",
  "fy_end_dt_parsed",
  "report_days",
  "full_year_report_flag",
  "provider_model_candidate",
  "acute_or_rural_include_v1",
  "provider_backbone_include_v1",
  "identity_complete_flag",
  "provider_name_missing_flag",
  "address_missing_flag",
  "city_missing_flag",
  "state_missing_flag",
  "zip_missing_flag"
)

front_cols <- intersect(front_cols, names(provider_master))
other_cols <- setdiff(names(provider_master), front_cols)

data.table::setcolorder(provider_master, c(front_cols, other_cols))

# ============================================================
# 7. Save outputs
# ============================================================

provider_master_rds <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_provider_master.rds")
)

provider_master_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_provider_master.csv")
)

saveRDS(provider_master, provider_master_rds)
data.table::fwrite(provider_master, provider_master_csv)

provider_identity_quality <- provider_master[
  ,
  .(
    reports = .N,
    provider_name_missing = sum(provider_name_missing_flag, na.rm = TRUE),
    address_missing = sum(address_missing_flag, na.rm = TRUE),
    city_missing = sum(city_missing_flag, na.rm = TRUE),
    state_missing = sum(state_missing_flag, na.rm = TRUE),
    zip_missing = sum(zip_missing_flag, na.rm = TRUE),
    identity_complete = sum(identity_complete_flag, na.rm = TRUE),
    alpha_provider_number_matches = sum(alpha_provider_number_matches_rpt, na.rm = TRUE)
  ),
  by = .(provider_backbone_include_v1, provider_model_class)
][order(provider_backbone_include_v1, provider_model_class)]

quality_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_provider_identity_quality.csv")
)

data.table::fwrite(provider_identity_quality, quality_csv)

# ============================================================
# 8. Print summaries
# ============================================================

cat("\n============================================================\n")
cat("PROVIDER MASTER CREATED\n")
cat("============================================================\n")

cat("\nRows:", nrow(provider_master), "\n")
cat("Unique rpt_rec_num:", data.table::uniqueN(provider_master$rpt_rec_num), "\n")
cat("Unique provider numbers:", data.table::uniqueN(provider_master$prvdr_num_chr), "\n")

cat("\nIdentity field missingness, all reports:\n")
print(provider_master[
  ,
  .(
    n = .N,
    provider_name_missing = sum(provider_name_missing_flag, na.rm = TRUE),
    address_missing = sum(address_missing_flag, na.rm = TRUE),
    city_missing = sum(city_missing_flag, na.rm = TRUE),
    state_missing = sum(state_missing_flag, na.rm = TRUE),
    zip_missing = sum(zip_missing_flag, na.rm = TRUE),
    identity_complete = sum(identity_complete_flag, na.rm = TRUE),
    alpha_provider_number_matches = sum(alpha_provider_number_matches_rpt, na.rm = TRUE)
  )
])

cat("\nIdentity field missingness, backbone-included reports:\n")
print(provider_master[
  provider_backbone_include_v1 == TRUE,
  .(
    n = .N,
    provider_name_missing = sum(provider_name_missing_flag, na.rm = TRUE),
    address_missing = sum(address_missing_flag, na.rm = TRUE),
    city_missing = sum(city_missing_flag, na.rm = TRUE),
    state_missing = sum(state_missing_flag, na.rm = TRUE),
    zip_missing = sum(zip_missing_flag, na.rm = TRUE),
    identity_complete = sum(identity_complete_flag, na.rm = TRUE),
    alpha_provider_number_matches = sum(alpha_provider_number_matches_rpt, na.rm = TRUE)
  )
])

cat("\nBackbone-included provider classes:\n")
print(provider_master[
  provider_backbone_include_v1 == TRUE,
  .N,
  by = provider_model_class
][order(-N)])

cat("\nSample backbone-included providers:\n")
print(provider_master[
  provider_backbone_include_v1 == TRUE,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_number_alpha,
    alpha_provider_number_matches_rpt,
    provider_name,
    street_address,
    city,
    state_abbrev,
    zip_code,
    county,
    provider_model_class,
    report_days,
    rpt_status_label
  )
][1:30])

cat("\nProvider identity quality by class:\n")
print(provider_identity_quality)

cat("\nSaved:\n")
cat(provider_master_rds, "\n")
cat(provider_master_csv, "\n")
cat(quality_csv, "\n")

cat("\n============================================================\n")
```

---

# 05A_inspect_provider_identity_fields.R

```r
# Scripts/05A_inspect_provider_identity_fields.R
# Inspect ALPHA fields to identify correct provider name/address/city/state/ZIP mappings
# for FY2024 HCRIS.

source("Scripts/00_setup.R")

cat("\n============================================================\n")
cat("INSPECT PROVIDER IDENTITY FIELDS\n")
cat("============================================================\n")
cat("Build year:", hcris_year_label, "\n\n")

rpt_base <- readRDS(
  file.path(path_processed, paste0("hcris_", hcris_year_label, "_rpt_base.rds"))
)

alpha <- readRDS(
  file.path(path_processed, paste0("hcris_", hcris_year_label, "_alpha.rds"))
)

# Use only backbone-included providers so the examples are relevant.
included_reports <- rpt_base[
  provider_backbone_include_v1 == TRUE,
  .(rpt_rec_num, prvdr_num_chr, provider_model_class)
]

alpha_included <- merge(
  alpha,
  included_reports,
  by = "rpt_rec_num",
  all.x = FALSE
)

# Keep text fields with meaningful values.
alpha_text <- alpha_included[
  !is.na(itm_alphnmrc_itm_txt) &
    itm_alphnmrc_itm_txt != ""
]

# Create profile of every ALPHA field among included providers.
field_profile <- alpha_text[
  ,
  .(
    n_rows = .N,
    n_reports = uniqueN(rpt_rec_num),
    n_distinct_values = uniqueN(itm_alphnmrc_itm_txt),
    
    sample_1 = itm_alphnmrc_itm_txt[1],
    sample_2 = itm_alphnmrc_itm_txt[pmin(.N, 2)],
    sample_3 = itm_alphnmrc_itm_txt[pmin(.N, 3)],
    sample_4 = itm_alphnmrc_itm_txt[pmin(.N, 4)],
    sample_5 = itm_alphnmrc_itm_txt[pmin(.N, 5)]
  ),
  by = .(wksht_cd, line_num_chr, clmn_num_chr)
][order(wksht_cd, line_num_chr, clmn_num_chr)]

# Add simple heuristic flags.
field_profile[
  ,
  likely_state_field :=
    n_distinct_values <= 60 &
    stringr::str_detect(sample_1, "^[A-Z]{2}$")
]

field_profile[
  ,
  likely_zip_field :=
    stringr::str_detect(sample_1, "^[0-9]{5}(-[0-9]{4})?$")
]

field_profile[
  ,
  likely_date_or_flag :=
    stringr::str_detect(sample_1, "^[0-9]{2}/[0-9]{2}/[0-9]{4}$") |
    sample_1 %in% c("Y", "N", "X", "F", "U", "A", "B", "C", "1", "2", "3", "4", "5")
]

field_profile[
  ,
  likely_name_or_address :=
    n_reports > 100 &
    n_distinct_values > 100 &
    !likely_state_field &
    !likely_zip_field &
    !likely_date_or_flag
]

profile_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_alpha_identity_full_field_profile.csv")
)

data.table::fwrite(field_profile, profile_csv)

cat("\nLikely name/address/city fields:\n")
print(field_profile[
  likely_name_or_address == TRUE,
  .(
    wksht_cd,
    line_num_chr,
    clmn_num_chr,
    n_reports,
    n_distinct_values,
    sample_1,
    sample_2,
    sample_3,
    sample_4,
    sample_5
  )
][1:200])

cat("\nLikely state fields:\n")
print(field_profile[
  likely_state_field == TRUE,
  .(
    wksht_cd,
    line_num_chr,
    clmn_num_chr,
    n_reports,
    n_distinct_values,
    sample_1,
    sample_2,
    sample_3,
    sample_4,
    sample_5
  )
][1:100])

cat("\nLikely ZIP fields:\n")
print(field_profile[
  likely_zip_field == TRUE,
  .(
    wksht_cd,
    line_num_chr,
    clmn_num_chr,
    n_reports,
    n_distinct_values,
    sample_1,
    sample_2,
    sample_3,
    sample_4,
    sample_5
  )
][1:100])

# Inspect a few known included reports in long form.
sample_reports <- included_reports[1:10, rpt_rec_num]

sample_alpha_long <- alpha_included[
  rpt_rec_num %in% sample_reports &
    !is.na(itm_alphnmrc_itm_txt) &
    itm_alphnmrc_itm_txt != "",
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_model_class,
    wksht_cd,
    line_num_chr,
    clmn_num_chr,
    value = itm_alphnmrc_itm_txt
  )
][order(rpt_rec_num, wksht_cd, line_num_chr, clmn_num_chr)]

sample_long_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_sample_provider_alpha_long.csv")
)

data.table::fwrite(sample_alpha_long, sample_long_csv)

cat("\nSample provider ALPHA long view, first 300 rows:\n")
print(sample_alpha_long[1:300])

cat("\nSaved:\n")
cat(profile_csv, "\n")
cat(sample_long_csv, "\n")

cat("\n============================================================\n")
cat("Provider identity inspection complete.\n")
cat("============================================================\n")
```

---

# 05B_target_provider_identity_mapping.R

```r
# Scripts/05B_target_provider_identity_mapping.R
# Targeted inspection of likely provider identity fields for FY2024 HCRIS.
#
# Goal:
#   Identify exact ALPHA worksheet/line/column locations for:
#     provider name
#     street address
#     city
#     state
#     ZIP
#
# This script does NOT create the provider master.
# It only prints a focused view so we can map Script 5 correctly.

source("Scripts/00_setup.R")

cat("\n============================================================\n")
cat("TARGET PROVIDER IDENTITY MAPPING INSPECTION\n")
cat("============================================================\n")
cat("Build year:", hcris_year_label, "\n\n")

rpt_base <- readRDS(
  file.path(path_processed, paste0("hcris_", hcris_year_label, "_rpt_base.rds"))
)

alpha <- readRDS(
  file.path(path_processed, paste0("hcris_", hcris_year_label, "_alpha.rds"))
)

# Use a small set of backbone-included providers from different classes.
sample_reports <- rpt_base[
  provider_backbone_include_v1 == TRUE,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_model_class,
    facility_type,
    rpt_status_label
  )
][1:20]

cat("\nSample reports selected:\n")
print(sample_reports)

# Pull only S-family worksheets, because identity fields should be in S worksheets.
sample_s_alpha <- merge(
  alpha[
    rpt_rec_num %in% sample_reports$rpt_rec_num &
      stringr::str_detect(wksht_cd, "^S") &
      !is.na(itm_alphnmrc_itm_txt) &
      itm_alphnmrc_itm_txt != "",
    .(
      rpt_rec_num,
      wksht_cd,
      line_num_chr,
      clmn_num_chr,
      value = itm_alphnmrc_itm_txt
    )
  ],
  sample_reports,
  by = "rpt_rec_num",
  all.x = TRUE
)

sample_s_alpha <- sample_s_alpha[
  order(rpt_rec_num, wksht_cd, line_num_chr, clmn_num_chr)
]

# Save full targeted long view.
sample_s_alpha_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_target_sample_S_alpha_long.csv")
)

data.table::fwrite(sample_s_alpha, sample_s_alpha_csv)

cat("\nTargeted S-family ALPHA long view, first 500 rows:\n")
print(sample_s_alpha[1:500])

# Now produce a compact profile only for S000001, S200001, S200002.
# These are the most likely places for core cost-report/provider metadata.
target_profile <- alpha[
  stringr::str_detect(wksht_cd, "^S(000001|200001|200002)$") &
    !is.na(itm_alphnmrc_itm_txt) &
    itm_alphnmrc_itm_txt != "",
  .(
    n_rows = .N,
    n_reports = uniqueN(rpt_rec_num),
    n_distinct_values = uniqueN(itm_alphnmrc_itm_txt),
    sample_1 = itm_alphnmrc_itm_txt[1],
    sample_2 = itm_alphnmrc_itm_txt[pmin(.N, 2)],
    sample_3 = itm_alphnmrc_itm_txt[pmin(.N, 3)],
    sample_4 = itm_alphnmrc_itm_txt[pmin(.N, 4)],
    sample_5 = itm_alphnmrc_itm_txt[pmin(.N, 5)],
    sample_6 = itm_alphnmrc_itm_txt[pmin(.N, 6)],
    sample_7 = itm_alphnmrc_itm_txt[pmin(.N, 7)],
    sample_8 = itm_alphnmrc_itm_txt[pmin(.N, 8)],
    sample_9 = itm_alphnmrc_itm_txt[pmin(.N, 9)],
    sample_10 = itm_alphnmrc_itm_txt[pmin(.N, 10)]
  ),
  by = .(wksht_cd, line_num_chr, clmn_num_chr)
][order(wksht_cd, line_num_chr, clmn_num_chr)]

target_profile_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_target_S000001_S200001_S200002_profile.csv")
)

data.table::fwrite(target_profile, target_profile_csv)

cat("\nTarget profile for S000001 / S200001 / S200002:\n")
print(target_profile)

# Look for known identity-like values based on the bad sample output.
# These should help locate which line/column actually holds hospital name/city/state.
known_terms <- c(
  "MARY S HARPER",
  "TUSCALOOSA",
  "OSF SAINT ANTHONYS",
  "ALTON",
  "MT EDGECUMBE",
  "JUNEAU",
  "USA HEALTH",
  "MOBILE",
  "ADVENTHEALTH OCALA",
  "OCALA"
)

known_hits <- alpha[
  !is.na(itm_alphnmrc_itm_txt) &
    stringr::str_detect(
      stringr::str_to_upper(itm_alphnmrc_itm_txt),
      paste(known_terms, collapse = "|")
    ),
  .(
    rpt_rec_num,
    wksht_cd,
    line_num_chr,
    clmn_num_chr,
    value = itm_alphnmrc_itm_txt
  )
]

known_hits <- merge(
  known_hits,
  rpt_base[
    ,
    .(
      rpt_rec_num,
      prvdr_num_chr,
      provider_model_class,
      facility_type,
      provider_backbone_include_v1
    )
  ],
  by = "rpt_rec_num",
  all.x = TRUE
)

known_hits <- known_hits[
  order(rpt_rec_num, wksht_cd, line_num_chr, clmn_num_chr)
]

known_hits_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_known_identity_term_hits.csv")
)

data.table::fwrite(known_hits, known_hits_csv)

cat("\nKnown identity term hits:\n")
print(known_hits[1:300])

cat("\nSaved:\n")
cat(sample_s_alpha_csv, "\n")
cat(target_profile_csv, "\n")
cat(known_hits_csv, "\n")

cat("\n============================================================\n")
cat("Target identity inspection complete.\n")
cat("============================================================\n")
```

---

# 05C_inspect_S200001_identity_block.R

```r
# Scripts/05C_inspect_S200001_identity_block.R
# Focused inspection of S200001 identity block.
#
# Goal:
#   Confirm exact mapping for provider name, street address, city, state, ZIP.

source("Scripts/00_setup.R")

cat("\n============================================================\n")
cat("INSPECT S200001 IDENTITY BLOCK\n")
cat("============================================================\n")
cat("Build year:", hcris_year_label, "\n\n")

rpt_base <- readRDS(
  file.path(path_processed, paste0("hcris_", hcris_year_label, "_rpt_base.rds"))
)

alpha <- readRDS(
  file.path(path_processed, paste0("hcris_", hcris_year_label, "_alpha.rds"))
)

sample_reports <- rpt_base[
  provider_backbone_include_v1 == TRUE,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_model_class,
    facility_type,
    rpt_status_label
  )
][1:30]

s200_identity_block <- merge(
  alpha[
    rpt_rec_num %in% sample_reports$rpt_rec_num &
      wksht_cd == "S200001" &
      line_num_chr >= "00100" &
      line_num_chr <= "00800" &
      !is.na(itm_alphnmrc_itm_txt) &
      itm_alphnmrc_itm_txt != "",
    .(
      rpt_rec_num,
      line_num_chr,
      clmn_num_chr,
      value = itm_alphnmrc_itm_txt
    )
  ],
  sample_reports,
  by = "rpt_rec_num",
  all.x = TRUE
)

s200_identity_block <- s200_identity_block[
  order(rpt_rec_num, line_num_chr, clmn_num_chr)
]

cat("\nS200001 identity block for sample reports:\n")
print(s200_identity_block)

# Compact field profile for all backbone-included reports.
included_reports <- rpt_base[
  provider_backbone_include_v1 == TRUE,
  .(rpt_rec_num)
]

s200_profile <- alpha[
  rpt_rec_num %in% included_reports$rpt_rec_num &
    wksht_cd == "S200001" &
    line_num_chr >= "00100" &
    line_num_chr <= "00800" &
    !is.na(itm_alphnmrc_itm_txt) &
    itm_alphnmrc_itm_txt != "",
  .(
    n_rows = .N,
    n_reports = uniqueN(rpt_rec_num),
    n_distinct_values = uniqueN(itm_alphnmrc_itm_txt),
    sample_1 = itm_alphnmrc_itm_txt[1],
    sample_2 = itm_alphnmrc_itm_txt[pmin(.N, 2)],
    sample_3 = itm_alphnmrc_itm_txt[pmin(.N, 3)],
    sample_4 = itm_alphnmrc_itm_txt[pmin(.N, 4)],
    sample_5 = itm_alphnmrc_itm_txt[pmin(.N, 5)],
    sample_6 = itm_alphnmrc_itm_txt[pmin(.N, 6)],
    sample_7 = itm_alphnmrc_itm_txt[pmin(.N, 7)],
    sample_8 = itm_alphnmrc_itm_txt[pmin(.N, 8)],
    sample_9 = itm_alphnmrc_itm_txt[pmin(.N, 9)],
    sample_10 = itm_alphnmrc_itm_txt[pmin(.N, 10)]
  ),
  by = .(wksht_cd, line_num_chr, clmn_num_chr)
][order(line_num_chr, clmn_num_chr)]

cat("\nS200001 identity block profile, all backbone reports:\n")
print(s200_profile)

s200_identity_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_S200001_identity_block_sample.csv")
)

s200_profile_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_S200001_identity_block_profile.csv")
)

data.table::fwrite(s200_identity_block, s200_identity_csv)
data.table::fwrite(s200_profile, s200_profile_csv)

cat("\nSaved:\n")
cat(s200_identity_csv, "\n")
cat(s200_profile_csv, "\n")

cat("\n============================================================\n")
cat("S200001 identity block inspection complete.\n")
cat("============================================================\n")
```

---

# 06_extract_beds_capacity.R

```r
# Scripts/06_extract_beds_capacity.R
# Extract hospital beds / bed-days / validated utilization capacity fields from HCRIS NMRC
# and merge onto the FY2024 provider master.
#
# Compatible with year-flexible setup from Scripts/00_setup.R
#
# Inputs:
#   Processed/hcris_YYYY_provider_master.rds
#   Processed/hcris_YYYY_nmrc.rds
#
# Outputs:
#   Processed/hcris_YYYY_beds_capacity.rds
#   Processed/hcris_YYYY_provider_master_with_beds.rds
#   Output/hcris_YYYY_beds_capacity.csv
#   Output/hcris_YYYY_provider_master_with_beds.csv
#   Output/hcris_YYYY_beds_capacity_profile.csv
#
# Confirmed FY2024 S-3 Part I capacity mapping:
#   S300001 L00100 C00200 = adult/peds beds
#   S300001 L00100 C00300 = adult/peds bed-days available
#   S300001 L00100 C00800 = adult/peds inpatient/patient days candidate
#   S300001 L00100 C00600 = adult/peds discharges candidate
#   S300001 L00100 C00700 = adult/peds utilization context field
#
#   S300001 L01400 C00200 = total hospital beds
#   S300001 L01400 C00300 = total hospital bed-days available
#   S300001 L01400 C00800 = validated total hospital inpatient/patient days
#   S300001 L01400 C00600 = validated total hospital discharges
#   S300001 L01400 C00700 = utilization context field
#   S300001 L01400 C01000 = reported utilization/ALOS-related metric
#
# Validation note:
#   Script 06B identified L01400_C00800 paired with L01400_C00600 as the most
#   credible total utilization mapping. The pair produced realistic aggregate
#   occupancy and ALOS values:
#     weighted occupancy ~0.708
#     weighted ALOS ~5.42
#     median occupancy ~0.618
#     median ALOS ~4.24
#
# We use line 01400 as the preferred total hospital line when present,
# and fall back to line 00100 when line 01400 is missing.

source("Scripts/00_setup.R")

cat("\n============================================================\n")
cat("EXTRACT HCRIS BEDS / CAPACITY VARIABLES\n")
cat("============================================================\n")
cat("Build year:", hcris_year_label, "\n\n")

# ============================================================
# 1. Load inputs
# ============================================================

provider_master_file <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_provider_master.rds")
)

nmrc_file <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_nmrc.rds")
)

if (!file.exists(provider_master_file)) {
  stop("Missing provider master file: ", provider_master_file)
}

if (!file.exists(nmrc_file)) {
  stop("Missing NMRC file: ", nmrc_file)
}

provider_master <- readRDS(provider_master_file)
nmrc <- readRDS(nmrc_file)

cat("Loaded:\n")
cat(provider_master_file, "\n")
cat(nmrc_file, "\n")

cat("\nProvider master rows:", nrow(provider_master), "\n")
cat("NMRC rows:", nrow(nmrc), "\n")

# ============================================================
# 2. Safety checks
# ============================================================

required_provider_cols <- c(
  "rpt_rec_num",
  "prvdr_num_chr",
  "provider_name",
  "provider_model_class",
  "provider_backbone_include_v1"
)

required_nmrc_cols <- c(
  "rpt_rec_num",
  "wksht_cd",
  "line_num_chr",
  "clmn_num_chr",
  "itm_val_num"
)

missing_provider <- setdiff(required_provider_cols, names(provider_master))
missing_nmrc <- setdiff(required_nmrc_cols, names(nmrc))

if (length(missing_provider) > 0) {
  stop(
    "Provider master missing required columns:\n",
    paste(missing_provider, collapse = "\n")
  )
}

if (length(missing_nmrc) > 0) {
  stop(
    "NMRC missing required columns:\n",
    paste(missing_nmrc, collapse = "\n")
  )
}

# ============================================================
# 3. Included provider universe
# ============================================================

included_providers <- provider_master[
  provider_backbone_include_v1 == TRUE,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    city,
    state_abbrev,
    provider_model_class,
    facility_type
  )
]

cat("\nBackbone-included providers:", nrow(included_providers), "\n")
print(included_providers[, .N, by = provider_model_class][order(-N)])

# ============================================================
# 4. Extract S-3 Part I capacity block
# ============================================================

s3_capacity_long <- nmrc[
  rpt_rec_num %in% included_providers$rpt_rec_num &
    wksht_cd == "S300001" &
    line_num_chr >= "00100" &
    line_num_chr <= "02000" &
    !is.na(itm_val_num)
]

s3_capacity_long <- merge(
  s3_capacity_long,
  included_providers,
  by = "rpt_rec_num",
  all.x = TRUE
)

# ============================================================
# 5. Profile S-3 block
# ============================================================

s3_profile <- s3_capacity_long[
  ,
  .(
    n_rows = .N,
    n_reports = data.table::uniqueN(rpt_rec_num),
    nonmissing_values = sum(!is.na(itm_val_num)),
    min_value = suppressWarnings(min(itm_val_num, na.rm = TRUE)),
    median_value = suppressWarnings(median(itm_val_num, na.rm = TRUE)),
    mean_value = suppressWarnings(mean(itm_val_num, na.rm = TRUE)),
    max_value = suppressWarnings(max(itm_val_num, na.rm = TRUE))
  ),
  by = .(wksht_cd, line_num_chr, clmn_num_chr)
][order(line_num_chr, clmn_num_chr)]

for (cc in c("min_value", "median_value", "mean_value", "max_value")) {
  s3_profile[
    is.infinite(get(cc)),
    (cc) := NA_real_
  ]
}

profile_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_beds_capacity_profile.csv")
)

data.table::fwrite(s3_profile, profile_csv)

cat("\nS-3 capacity profile, first 150 rows:\n")
print(s3_profile[1:150])

# ============================================================
# 6. Create wide S-3 table
# ============================================================

s3_capacity_long[
  ,
  field_key := paste0("S300001_L", line_num_chr, "_C", clmn_num_chr)
]

s3_wide_long <- s3_capacity_long[
  ,
  .(
    value = suppressWarnings(sum(itm_val_num, na.rm = TRUE))
  ),
  by = .(rpt_rec_num, field_key)
]

s3_capacity_wide <- data.table::dcast(
  s3_wide_long,
  rpt_rec_num ~ field_key,
  value.var = "value"
)

# ============================================================
# 7. Helper functions
# ============================================================

get_existing_numeric <- function(dt, colname) {
  if (colname %in% names(dt)) {
    return(as.numeric(dt[[colname]]))
  }
  
  rep(NA_real_, nrow(dt))
}

coalesce_numeric <- function(...) {
  vals <- list(...)
  out <- vals[[1]]
  
  if (length(vals) > 1) {
    for (v in vals[-1]) {
      out <- data.table::fifelse(
        is.na(out) | out == 0,
        v,
        out
      )
    }
  }
  
  out
}

# ============================================================
# 8. Extract corrected capacity and utilization fields
# ============================================================

beds_capacity <- copy(s3_capacity_wide)

# -----------------------------
# Adult/peds line: S300001 L00100
# -----------------------------

beds_capacity[
  ,
  adult_peds_beds :=
    get_existing_numeric(beds_capacity, "S300001_L00100_C00200")
]

beds_capacity[
  ,
  adult_peds_bed_days_available :=
    get_existing_numeric(beds_capacity, "S300001_L00100_C00300")
]

beds_capacity[
  ,
  adult_peds_inpatient_days :=
    get_existing_numeric(beds_capacity, "S300001_L00100_C00800")
]

beds_capacity[
  ,
  adult_peds_discharges :=
    get_existing_numeric(beds_capacity, "S300001_L00100_C00600")
]

beds_capacity[
  ,
  adult_peds_utilization_context_c007 :=
    get_existing_numeric(beds_capacity, "S300001_L00100_C00700")
]

beds_capacity[
  ,
  adult_peds_utilization_context_c015 :=
    get_existing_numeric(beds_capacity, "S300001_L00100_C01500")
]

# -----------------------------
# Total hospital line: S300001 L01400
# -----------------------------

beds_capacity[
  ,
  total_line_beds :=
    get_existing_numeric(beds_capacity, "S300001_L01400_C00200")
]

beds_capacity[
  ,
  total_line_bed_days_available :=
    get_existing_numeric(beds_capacity, "S300001_L01400_C00300")
]

beds_capacity[
  ,
  total_line_inpatient_days :=
    get_existing_numeric(beds_capacity, "S300001_L01400_C00800")
]

beds_capacity[
  ,
  total_line_discharges :=
    get_existing_numeric(beds_capacity, "S300001_L01400_C00600")
]

beds_capacity[
  ,
  total_line_utilization_context_c007 :=
    get_existing_numeric(beds_capacity, "S300001_L01400_C00700")
]

beds_capacity[
  ,
  total_line_utilization_context_c015 :=
    get_existing_numeric(beds_capacity, "S300001_L01400_C01500")
]

beds_capacity[
  ,
  total_line_reported_alos_metric :=
    get_existing_numeric(beds_capacity, "S300001_L01400_C01000")
]

# -----------------------------
# Preferred hospital fields:
# use total line if present; otherwise adult/peds fallback.
# -----------------------------

beds_capacity[
  ,
  hospital_beds :=
    coalesce_numeric(total_line_beds, adult_peds_beds)
]

beds_capacity[
  ,
  hospital_bed_days_available :=
    coalesce_numeric(total_line_bed_days_available, adult_peds_bed_days_available)
]

beds_capacity[
  ,
  hospital_inpatient_days :=
    coalesce_numeric(total_line_inpatient_days, adult_peds_inpatient_days)
]

beds_capacity[
  ,
  hospital_discharges :=
    coalesce_numeric(total_line_discharges, adult_peds_discharges)
]

beds_capacity[
  ,
  hospital_utilization_context_c007 :=
    coalesce_numeric(
      total_line_utilization_context_c007,
      adult_peds_utilization_context_c007
    )
]

beds_capacity[
  ,
  hospital_utilization_context_c015 :=
    coalesce_numeric(
      total_line_utilization_context_c015,
      adult_peds_utilization_context_c015
    )
]

# -----------------------------
# Derived metrics
# -----------------------------

beds_capacity[
  ,
  occupancy_rate :=
    hospital_inpatient_days / hospital_bed_days_available
]

beds_capacity[
  ,
  average_length_of_stay :=
    hospital_inpatient_days / hospital_discharges
]

# -----------------------------
# Validation flags
# -----------------------------

beds_capacity[
  ,
  beds_capacity_complete_flag :=
    !is.na(hospital_beds) &
    hospital_beds > 0 &
    !is.na(hospital_bed_days_available) &
    hospital_bed_days_available > 0
]

beds_capacity[
  ,
  utilization_complete_flag :=
    beds_capacity_complete_flag == TRUE &
    !is.na(hospital_inpatient_days) &
    hospital_inpatient_days >= 0 &
    !is.na(hospital_discharges) &
    hospital_discharges > 0
]

beds_capacity[
  ,
  occupancy_rate_plausible_flag :=
    utilization_complete_flag == TRUE &
    !is.na(occupancy_rate) &
    occupancy_rate >= 0 &
    occupancy_rate <= 1.05
]

beds_capacity[
  ,
  average_length_of_stay_plausible_flag :=
    utilization_complete_flag == TRUE &
    !is.na(average_length_of_stay) &
    average_length_of_stay >= 1 &
    average_length_of_stay <= 30
]

beds_capacity[
  ,
  utilization_plausible_flag :=
    utilization_complete_flag == TRUE &
    occupancy_rate_plausible_flag == TRUE &
    average_length_of_stay_plausible_flag == TRUE
]

beds_capacity[
  ,
  bed_days_consistent_with_beds_flag :=
    !is.na(hospital_beds) &
    !is.na(hospital_bed_days_available) &
    hospital_beds > 0 &
    hospital_bed_days_available > 0 &
    hospital_bed_days_available >= hospital_beds * 300 &
    hospital_bed_days_available <= hospital_beds * 370
]

# ============================================================
# 9. Merge with provider master
# ============================================================

capacity_core <- beds_capacity[
  ,
  .(
    rpt_rec_num,
    
    adult_peds_beds,
    adult_peds_bed_days_available,
    adult_peds_inpatient_days,
    adult_peds_discharges,
    adult_peds_utilization_context_c007,
    adult_peds_utilization_context_c015,
    
    total_line_beds,
    total_line_bed_days_available,
    total_line_inpatient_days,
    total_line_discharges,
    total_line_utilization_context_c007,
    total_line_utilization_context_c015,
    total_line_reported_alos_metric,
    
    hospital_beds,
    hospital_bed_days_available,
    hospital_inpatient_days,
    hospital_discharges,
    hospital_utilization_context_c007,
    hospital_utilization_context_c015,
    
    occupancy_rate,
    average_length_of_stay,
    
    beds_capacity_complete_flag,
    utilization_complete_flag,
    occupancy_rate_plausible_flag,
    average_length_of_stay_plausible_flag,
    utilization_plausible_flag,
    bed_days_consistent_with_beds_flag
  )
]

provider_master_with_beds <- merge(
  provider_master,
  capacity_core,
  by = "rpt_rec_num",
  all.x = TRUE
)

flag_cols <- c(
  "beds_capacity_complete_flag",
  "utilization_complete_flag",
  "occupancy_rate_plausible_flag",
  "average_length_of_stay_plausible_flag",
  "utilization_plausible_flag",
  "bed_days_consistent_with_beds_flag"
)

for (fc in flag_cols) {
  provider_master_with_beds[
    is.na(get(fc)),
    (fc) := FALSE
  ]
}

# ============================================================
# 10. Save outputs
# ============================================================

beds_capacity_rds <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_beds_capacity.rds")
)

provider_master_with_beds_rds <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_provider_master_with_beds.rds")
)

beds_capacity_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_beds_capacity.csv")
)

provider_master_with_beds_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_provider_master_with_beds.csv")
)

saveRDS(beds_capacity, beds_capacity_rds)
saveRDS(provider_master_with_beds, provider_master_with_beds_rds)

data.table::fwrite(beds_capacity, beds_capacity_csv)
data.table::fwrite(provider_master_with_beds, provider_master_with_beds_csv)

# ============================================================
# 11. Print summaries
# ============================================================

cat("\n============================================================\n")
cat("BEDS / CAPACITY EXTRACTION COMPLETE\n")
cat("============================================================\n")

cat("\nRows in beds capacity table:", nrow(beds_capacity), "\n")
cat("Rows in provider master with beds:", nrow(provider_master_with_beds), "\n")

cat("\nBeds/capacity completion, all reports:\n")
print(provider_master_with_beds[
  ,
  .N,
  by = beds_capacity_complete_flag
][order(beds_capacity_complete_flag)])

cat("\nBeds/capacity completion, backbone-included reports:\n")
print(provider_master_with_beds[
  provider_backbone_include_v1 == TRUE,
  .N,
  by = beds_capacity_complete_flag
][order(beds_capacity_complete_flag)])

cat("\nUtilization completion/plausibility, backbone-included reports:\n")
print(provider_master_with_beds[
  provider_backbone_include_v1 == TRUE,
  .(
    providers = .N,
    beds_complete = sum(beds_capacity_complete_flag, na.rm = TRUE),
    utilization_complete = sum(utilization_complete_flag, na.rm = TRUE),
    occupancy_plausible = sum(occupancy_rate_plausible_flag, na.rm = TRUE),
    alos_plausible = sum(average_length_of_stay_plausible_flag, na.rm = TRUE),
    utilization_plausible = sum(utilization_plausible_flag, na.rm = TRUE),
    bed_days_consistent = sum(bed_days_consistent_with_beds_flag, na.rm = TRUE)
  )
])

cat("\nBeds/capacity and utilization by provider class, backbone-included:\n")
print(provider_master_with_beds[
  provider_backbone_include_v1 == TRUE,
  .(
    providers = .N,
    complete_beds_capacity = sum(beds_capacity_complete_flag, na.rm = TRUE),
    missing_beds_capacity = sum(!beds_capacity_complete_flag, na.rm = TRUE),
    utilization_complete = sum(utilization_complete_flag, na.rm = TRUE),
    utilization_plausible = sum(utilization_plausible_flag, na.rm = TRUE),
    
    total_beds = sum(hospital_beds, na.rm = TRUE),
    median_beds = median(hospital_beds, na.rm = TRUE),
    
    total_bed_days_available = sum(hospital_bed_days_available, na.rm = TRUE),
    total_inpatient_days = sum(hospital_inpatient_days, na.rm = TRUE),
    total_discharges = sum(hospital_discharges, na.rm = TRUE),
    
    weighted_occupancy_rate =
      sum(hospital_inpatient_days, na.rm = TRUE) /
      sum(hospital_bed_days_available, na.rm = TRUE),
    
    weighted_average_length_of_stay =
      sum(hospital_inpatient_days, na.rm = TRUE) /
      sum(hospital_discharges, na.rm = TRUE),
    
    median_occupancy_rate = median(occupancy_rate, na.rm = TRUE),
    median_average_length_of_stay = median(average_length_of_stay, na.rm = TRUE)
  ),
  by = provider_model_class
][order(-providers)])

cat("\nDistribution of hospital beds, backbone-included with capacity complete:\n")
print(summary(provider_master_with_beds[
  provider_backbone_include_v1 == TRUE &
    beds_capacity_complete_flag == TRUE,
  hospital_beds
]))

cat("\nDistribution of occupancy rate, backbone-included with utilization complete:\n")
print(summary(provider_master_with_beds[
  provider_backbone_include_v1 == TRUE &
    utilization_complete_flag == TRUE,
  occupancy_rate
]))

cat("\nDistribution of average length of stay, backbone-included with utilization complete:\n")
print(summary(provider_master_with_beds[
  provider_backbone_include_v1 == TRUE &
    utilization_complete_flag == TRUE,
  average_length_of_stay
]))

cat("\nSample backbone-included providers with beds/utilization:\n")
print(provider_master_with_beds[
  provider_backbone_include_v1 == TRUE,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    city,
    state_abbrev,
    provider_model_class,
    hospital_beds,
    hospital_bed_days_available,
    hospital_inpatient_days,
    hospital_discharges,
    occupancy_rate,
    average_length_of_stay,
    total_line_reported_alos_metric,
    beds_capacity_complete_flag,
    utilization_complete_flag,
    utilization_plausible_flag
  )
][1:30])

cat("\nPotential mapping checks / outliers:\n")

cat("\nProviders with occupancy_rate > 1.05 among backbone-included:\n")
occ_outliers <- provider_master_with_beds[
  provider_backbone_include_v1 == TRUE &
    utilization_complete_flag == TRUE &
    occupancy_rate > 1.05,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    provider_model_class,
    hospital_beds,
    hospital_bed_days_available,
    hospital_inpatient_days,
    hospital_discharges,
    occupancy_rate,
    average_length_of_stay
  )
]

if (nrow(occ_outliers) == 0) {
  cat("None\n")
} else {
  print(occ_outliers[1:50])
}

cat("\nProviders with average_length_of_stay < 1 or > 30 among backbone-included:\n")
alos_outliers <- provider_master_with_beds[
  provider_backbone_include_v1 == TRUE &
    utilization_complete_flag == TRUE &
    (average_length_of_stay < 1 | average_length_of_stay > 30),
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    provider_model_class,
    hospital_beds,
    hospital_bed_days_available,
    hospital_inpatient_days,
    hospital_discharges,
    occupancy_rate,
    average_length_of_stay
  )
]

if (nrow(alos_outliers) == 0) {
  cat("None\n")
} else {
  print(alos_outliers[1:50])
}

cat("\nProviders with hospital_beds > 2000 among backbone-included:\n")
bed_outliers <- provider_master_with_beds[
  provider_backbone_include_v1 == TRUE &
    beds_capacity_complete_flag == TRUE &
    hospital_beds > 2000,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    provider_model_class,
    hospital_beds,
    hospital_bed_days_available,
    hospital_inpatient_days,
    occupancy_rate
  )
]

if (nrow(bed_outliers) == 0) {
  cat("None\n")
} else {
  print(bed_outliers[1:50])
}

cat("\nSaved:\n")
cat(beds_capacity_rds, "\n")
cat(provider_master_with_beds_rds, "\n")
cat(beds_capacity_csv, "\n")
cat(provider_master_with_beds_csv, "\n")
cat(profile_csv, "\n")

cat("\n============================================================\n")
```

---

# 06A_inspect_S3_capacity_columns.R

```r
# Scripts/06A_inspect_S3_capacity_columns.R
# Focused inspection of S-3 Part I capacity/utilization columns.
#
# Goal:
#   Confirm exact columns for:
#     beds
#     bed-days available
#     inpatient days
#     discharges
#
# We already suspect:
#   S300001 L00100 C00200 = beds
#   S300001 L00100 C00300 = bed-days available

source("Scripts/00_setup.R")

cat("\n============================================================\n")
cat("INSPECT S-3 CAPACITY COLUMNS\n")
cat("============================================================\n")
cat("Build year:", hcris_year_label, "\n\n")

provider_master <- readRDS(
  file.path(path_processed, paste0("hcris_", hcris_year_label, "_provider_master.rds"))
)

nmrc <- readRDS(
  file.path(path_processed, paste0("hcris_", hcris_year_label, "_nmrc.rds"))
)

included <- provider_master[
  provider_backbone_include_v1 == TRUE,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    city,
    state_abbrev,
    provider_model_class
  )
]

# Use first 30 included providers for readable long-form inspection.
sample_reports <- included[1:30]

s3_sample <- merge(
  nmrc[
    rpt_rec_num %in% sample_reports$rpt_rec_num &
      wksht_cd == "S300001" &
      line_num_chr >= "00100" &
      line_num_chr <= "01500" &
      !is.na(itm_val_num),
    .(
      rpt_rec_num,
      wksht_cd,
      line_num_chr,
      clmn_num_chr,
      value = itm_val_num
    )
  ],
  sample_reports,
  by = "rpt_rec_num",
  all.x = TRUE
)

s3_sample <- s3_sample[
  order(rpt_rec_num, line_num_chr, clmn_num_chr)
]

cat("\nS300001 sample long view, first 500 rows:\n")
print(s3_sample[1:500])

# Full profile for backbone providers.
s3_profile <- nmrc[
  rpt_rec_num %in% included$rpt_rec_num &
    wksht_cd == "S300001" &
    line_num_chr >= "00100" &
    line_num_chr <= "01500" &
    !is.na(itm_val_num),
  .(
    n_rows = .N,
    n_reports = uniqueN(rpt_rec_num),
    min_value = suppressWarnings(min(itm_val_num, na.rm = TRUE)),
    p25_value = suppressWarnings(quantile(itm_val_num, 0.25, na.rm = TRUE)),
    median_value = suppressWarnings(median(itm_val_num, na.rm = TRUE)),
    mean_value = suppressWarnings(mean(itm_val_num, na.rm = TRUE)),
    p75_value = suppressWarnings(quantile(itm_val_num, 0.75, na.rm = TRUE)),
    max_value = suppressWarnings(max(itm_val_num, na.rm = TRUE))
  ),
  by = .(wksht_cd, line_num_chr, clmn_num_chr)
][order(line_num_chr, clmn_num_chr)]

cat("\nS300001 profile for lines 00100-01500, all backbone providers:\n")
print(s3_profile)

# Wide view for first 30 providers, easier to visually inspect.
s3_sample[
  ,
  field_key := paste0("L", line_num_chr, "_C", clmn_num_chr)
]

s3_sample_wide <- data.table::dcast(
  s3_sample,
  rpt_rec_num + prvdr_num_chr + provider_name + city + state_abbrev + provider_model_class ~ field_key,
  value.var = "value"
)

cat("\nS300001 sample wide view:\n")
print(s3_sample_wide)

# Save outputs.
sample_long_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_S300001_capacity_sample_long.csv")
)

sample_wide_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_S300001_capacity_sample_wide.csv")
)

profile_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_S300001_capacity_profile_lines_001_015.csv")
)

data.table::fwrite(s3_sample, sample_long_csv)
data.table::fwrite(s3_sample_wide, sample_wide_csv)
data.table::fwrite(s3_profile, profile_csv)

cat("\nSaved:\n")
cat(sample_long_csv, "\n")
cat(sample_wide_csv, "\n")
cat(profile_csv, "\n")

cat("\n============================================================\n")
cat("S-3 capacity inspection complete.\n")
cat("============================================================\n")
```

---

# 06B_validate_S3_utilization_mapping.R

```r
# Scripts/06B_validate_S3_utilization_mapping.R
# Validate HCRIS Worksheet S-3 Part I utilization mapping.
#
# Purpose:
#   We already validated that:
#     S300001 L01400 C00200 = total beds
#     S300001 L01400 C00300 = total bed-days available
#
#   But the prior mapping for:
#     inpatient days
#     discharges
#     occupancy rate
#     average length of stay
#   produced implausible values.
#
# This script systematically inspects S300001 columns and identifies which columns
# produce plausible utilization metrics when paired with validated beds and
# bed-days available.
#
# Inputs:
#   Processed/hcris_YYYY_provider_master.rds
#   Processed/hcris_YYYY_nmrc.rds
#
# Outputs:
#   Output/hcris_YYYY_S3_utilization_candidate_metrics.csv
#   Output/hcris_YYYY_S3_utilization_candidate_summary.csv
#   Output/hcris_YYYY_S3_utilization_candidate_sample.csv

source("Scripts/00_setup.R")

cat("\n============================================================\n")
cat("VALIDATE S-3 UTILIZATION MAPPING\n")
cat("============================================================\n")
cat("Build year:", hcris_year_label, "\n\n")

# ============================================================
# 1. Load inputs
# ============================================================

provider_master_file <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_provider_master.rds")
)

nmrc_file <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_nmrc.rds")
)

if (!file.exists(provider_master_file)) {
  stop("Missing provider master file: ", provider_master_file)
}

if (!file.exists(nmrc_file)) {
  stop("Missing NMRC file: ", nmrc_file)
}

provider_master <- readRDS(provider_master_file)
nmrc <- readRDS(nmrc_file)

included <- provider_master[
  provider_backbone_include_v1 == TRUE,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    city,
    state_abbrev,
    provider_model_class
  )
]

cat("Backbone-included providers:", nrow(included), "\n")
print(included[, .N, by = provider_model_class][order(-N)])

# ============================================================
# 2. Create wide S300001 table for included providers
# ============================================================

s3_long <- nmrc[
  rpt_rec_num %in% included$rpt_rec_num &
    wksht_cd == "S300001" &
    line_num_chr >= "00100" &
    line_num_chr <= "02000" &
    !is.na(itm_val_num),
  .(
    rpt_rec_num,
    line_num_chr,
    clmn_num_chr,
    value = itm_val_num
  )
]

s3_long[
  ,
  field_key := paste0("L", line_num_chr, "_C", clmn_num_chr)
]

s3_wide <- data.table::dcast(
  s3_long,
  rpt_rec_num ~ field_key,
  value.var = "value",
  fun.aggregate = sum,
  fill = NA_real_
)

s3_wide <- merge(
  included,
  s3_wide,
  by = "rpt_rec_num",
  all.x = TRUE
)

# ============================================================
# 3. Validated beds / bed-days base
# ============================================================

get_num <- function(dt, colname) {
  if (colname %in% names(dt)) {
    return(as.numeric(dt[[colname]]))
  }
  rep(NA_real_, nrow(dt))
}

coalesce_num <- function(a, b) {
  data.table::fifelse(is.na(a) | a == 0, b, a)
}

# Preferred total line is L01400. Fallback is L00100.
s3_wide[
  ,
  validated_beds :=
    coalesce_num(
      get_num(s3_wide, "L01400_C00200"),
      get_num(s3_wide, "L00100_C00200")
    )
]

s3_wide[
  ,
  validated_bed_days_available :=
    coalesce_num(
      get_num(s3_wide, "L01400_C00300"),
      get_num(s3_wide, "L00100_C00300")
    )
]

s3_wide[
  ,
  bed_base_valid :=
    !is.na(validated_beds) &
    validated_beds > 0 &
    !is.na(validated_bed_days_available) &
    validated_bed_days_available > 0 &
    validated_bed_days_available >= validated_beds * 300 &
    validated_bed_days_available <= validated_beds * 370
]

cat("\nValidated bed base:\n")
print(s3_wide[, .N, by = bed_base_valid][order(bed_base_valid)])

# ============================================================
# 4. Build candidate utilization columns
# ============================================================

# Candidate utilization fields from lines that appear to contain total or subtotal
# utilization fields.
candidate_fields <- grep(
  "^L(00100|00700|01400|01500)_C[0-9]{5}$",
  names(s3_wide),
  value = TRUE
)

# Exclude known non-utilization / structural fields.
candidate_fields <- setdiff(
  candidate_fields,
  c(
    "L00100_C00100",
    "L00100_C00200",
    "L00100_C00300",
    "L00700_C00100",
    "L00700_C00200",
    "L00700_C00300",
    "L01400_C00100",
    "L01400_C00200",
    "L01400_C00300",
    "L01500_C00100",
    "L01500_C00200",
    "L01500_C00300"
  )
)

cat("\nCandidate utilization fields:\n")
print(candidate_fields)

# ============================================================
# 5. Evaluate each candidate as inpatient-days field
# ============================================================

candidate_metrics_list <- list()

for (field in candidate_fields) {
  tmp <- copy(s3_wide)
  
  tmp[
    ,
    candidate_field := field
  ]
  
  tmp[
    ,
    candidate_value := get_num(tmp, field)
  ]
  
  tmp[
    ,
    implied_occupancy :=
      candidate_value / validated_bed_days_available
  ]
  
  tmp[
    ,
    plausible_inpatient_days :=
      bed_base_valid == TRUE &
      !is.na(candidate_value) &
      candidate_value >= 0 &
      candidate_value <= validated_bed_days_available * 1.05 &
      implied_occupancy >= 0 &
      implied_occupancy <= 1.05
  ]
  
  candidate_summary <- tmp[
    bed_base_valid == TRUE,
    .(
      providers_with_value = sum(!is.na(candidate_value)),
      providers_plausible = sum(plausible_inpatient_days, na.rm = TRUE),
      pct_plausible_among_with_value =
        sum(plausible_inpatient_days, na.rm = TRUE) /
        sum(!is.na(candidate_value)),
      
      total_candidate_value = sum(candidate_value, na.rm = TRUE),
      total_bed_days_available = sum(validated_bed_days_available, na.rm = TRUE),
      implied_weighted_occupancy =
        sum(candidate_value, na.rm = TRUE) /
        sum(validated_bed_days_available, na.rm = TRUE),
      
      median_candidate_value = median(candidate_value, na.rm = TRUE),
      median_implied_occupancy = median(implied_occupancy, na.rm = TRUE),
      p25_implied_occupancy =
        as.numeric(quantile(implied_occupancy, 0.25, na.rm = TRUE)),
      p75_implied_occupancy =
        as.numeric(quantile(implied_occupancy, 0.75, na.rm = TRUE)),
      min_implied_occupancy = min(implied_occupancy, na.rm = TRUE),
      max_implied_occupancy = max(implied_occupancy, na.rm = TRUE)
    )
  ]
  
  candidate_summary[
    ,
    candidate_field := field
  ]
  
  candidate_metrics_list[[field]] <- candidate_summary
}

candidate_summary_all <- data.table::rbindlist(
  candidate_metrics_list,
  fill = TRUE
)

# Clean Inf values.
for (cc in names(candidate_summary_all)) {
  if (is.numeric(candidate_summary_all[[cc]])) {
    candidate_summary_all[
      is.infinite(get(cc)),
      (cc) := NA_real_
    ]
  }
}

data.table::setcolorder(
  candidate_summary_all,
  c(
    "candidate_field",
    setdiff(names(candidate_summary_all), "candidate_field")
  )
)

candidate_summary_all <- candidate_summary_all[
  order(
    -providers_plausible,
    -pct_plausible_among_with_value,
    abs(implied_weighted_occupancy - 0.55)
  )
]

cat("\nCandidate inpatient-days field summary:\n")
print(candidate_summary_all)

# ============================================================
# 6. Evaluate likely inpatient-days and discharge pairings
# ============================================================

# We test pairings where one field is used as inpatient days and another as discharges.
# Plausible ALOS range is intentionally broad:
#   1.0 to 30 days overall, because children's, psych, CAH, swing-bed, and specialty
#   reporting can vary.
#
# We also compute by-class values so we can see whether a mapping is only plausible
# for one provider class.

pair_metrics_list <- list()
pair_id <- 0L

for (days_field in candidate_fields) {
  for (discharge_field in candidate_fields) {
    if (days_field == discharge_field) next
    
    pair_id <- pair_id + 1L
    
    tmp <- copy(s3_wide)
    
    tmp[, days_field_name := days_field]
    tmp[, discharge_field_name := discharge_field]
    
    tmp[, candidate_days := get_num(tmp, days_field)]
    tmp[, candidate_discharges := get_num(tmp, discharge_field)]
    
    tmp[, implied_occupancy := candidate_days / validated_bed_days_available]
    tmp[, implied_alos := candidate_days / candidate_discharges]
    
    tmp[
      ,
      plausible_pair :=
        bed_base_valid == TRUE &
        !is.na(candidate_days) &
        !is.na(candidate_discharges) &
        candidate_days >= 0 &
        candidate_discharges > 0 &
        candidate_days <= validated_bed_days_available * 1.05 &
        implied_occupancy >= 0 &
        implied_occupancy <= 1.05 &
        implied_alos >= 1 &
        implied_alos <= 30
    ]
    
    pair_summary <- tmp[
      bed_base_valid == TRUE,
      .(
        providers_with_both =
          sum(!is.na(candidate_days) & !is.na(candidate_discharges)),
        providers_plausible_pair = sum(plausible_pair, na.rm = TRUE),
        pct_plausible_pair =
          sum(plausible_pair, na.rm = TRUE) /
          sum(!is.na(candidate_days) & !is.na(candidate_discharges)),
        
        total_candidate_days = sum(candidate_days, na.rm = TRUE),
        total_candidate_discharges = sum(candidate_discharges, na.rm = TRUE),
        weighted_occupancy =
          sum(candidate_days, na.rm = TRUE) /
          sum(validated_bed_days_available, na.rm = TRUE),
        weighted_alos =
          sum(candidate_days, na.rm = TRUE) /
          sum(candidate_discharges, na.rm = TRUE),
        
        median_occupancy = median(implied_occupancy, na.rm = TRUE),
        median_alos = median(implied_alos, na.rm = TRUE),
        p25_alos = as.numeric(quantile(implied_alos, 0.25, na.rm = TRUE)),
        p75_alos = as.numeric(quantile(implied_alos, 0.75, na.rm = TRUE))
      )
    ]
    
    pair_summary[, days_field := days_field]
    pair_summary[, discharge_field := discharge_field]
    
    pair_metrics_list[[pair_id]] <- pair_summary
  }
}

pair_summary_all <- data.table::rbindlist(pair_metrics_list, fill = TRUE)

for (cc in names(pair_summary_all)) {
  if (is.numeric(pair_summary_all[[cc]])) {
    pair_summary_all[
      is.infinite(get(cc)),
      (cc) := NA_real_
    ]
  }
}

data.table::setcolorder(
  pair_summary_all,
  c(
    "days_field",
    "discharge_field",
    setdiff(names(pair_summary_all), c("days_field", "discharge_field"))
  )
)

pair_summary_all <- pair_summary_all[
  order(
    -providers_plausible_pair,
    -pct_plausible_pair,
    abs(weighted_occupancy - 0.55),
    abs(weighted_alos - 5)
  )
]

cat("\nTop candidate inpatient-days/discharge pairings:\n")
print(pair_summary_all[1:50])

# ============================================================
# 7. By-class view for top candidate pairings
# ============================================================

top_pairs <- pair_summary_all[1:min(.N, 10)]

by_class_list <- list()

for (i in seq_len(nrow(top_pairs))) {
  days_field <- top_pairs$days_field[i]
  discharge_field <- top_pairs$discharge_field[i]
  
  tmp <- copy(s3_wide)
  
  tmp[, days_field := days_field]
  tmp[, discharge_field := discharge_field]
  tmp[, candidate_days := get_num(tmp, days_field)]
  tmp[, candidate_discharges := get_num(tmp, discharge_field)]
  tmp[, implied_occupancy := candidate_days / validated_bed_days_available]
  tmp[, implied_alos := candidate_days / candidate_discharges]
  
  by_class <- tmp[
    bed_base_valid == TRUE,
    .(
      providers = .N,
      providers_with_both =
        sum(!is.na(candidate_days) & !is.na(candidate_discharges)),
      total_beds = sum(validated_beds, na.rm = TRUE),
      total_bed_days_available = sum(validated_bed_days_available, na.rm = TRUE),
      total_candidate_days = sum(candidate_days, na.rm = TRUE),
      total_candidate_discharges = sum(candidate_discharges, na.rm = TRUE),
      weighted_occupancy =
        sum(candidate_days, na.rm = TRUE) /
        sum(validated_bed_days_available, na.rm = TRUE),
      weighted_alos =
        sum(candidate_days, na.rm = TRUE) /
        sum(candidate_discharges, na.rm = TRUE),
      median_occupancy = median(implied_occupancy, na.rm = TRUE),
      median_alos = median(implied_alos, na.rm = TRUE)
    ),
    by = provider_model_class
  ]
  
  by_class[, days_field := days_field]
  by_class[, discharge_field := discharge_field]
  
  by_class_list[[i]] <- by_class
}

top_pairs_by_class <- data.table::rbindlist(by_class_list, fill = TRUE)

data.table::setcolorder(
  top_pairs_by_class,
  c(
    "days_field",
    "discharge_field",
    "provider_model_class",
    setdiff(
      names(top_pairs_by_class),
      c("days_field", "discharge_field", "provider_model_class")
    )
  )
)

cat("\nTop candidate pairings by provider class:\n")
print(top_pairs_by_class)

# ============================================================
# 8. Sample provider values for top pair
# ============================================================

best_days_field <- pair_summary_all$days_field[1]
best_discharge_field <- pair_summary_all$discharge_field[1]

sample_best <- copy(s3_wide)

sample_best[, best_days_field := best_days_field]
sample_best[, best_discharge_field := best_discharge_field]
sample_best[, candidate_days := get_num(sample_best, best_days_field)]
sample_best[, candidate_discharges := get_num(sample_best, best_discharge_field)]
sample_best[, implied_occupancy := candidate_days / validated_bed_days_available]
sample_best[, implied_alos := candidate_days / candidate_discharges]

sample_best_view <- sample_best[
  ,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    city,
    state_abbrev,
    provider_model_class,
    validated_beds,
    validated_bed_days_available,
    best_days_field,
    candidate_days,
    best_discharge_field,
    candidate_discharges,
    implied_occupancy,
    implied_alos
  )
][1:100]

cat("\nSample values using top candidate pair:\n")
print(sample_best_view)

# ============================================================
# 9. Save outputs
# ============================================================

candidate_metrics_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_S3_utilization_candidate_metrics.csv")
)

pair_summary_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_S3_utilization_candidate_pair_summary.csv")
)

top_pairs_by_class_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_S3_utilization_top_pairs_by_class.csv")
)

sample_best_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_S3_utilization_top_pair_sample.csv")
)

data.table::fwrite(candidate_summary_all, candidate_metrics_csv)
data.table::fwrite(pair_summary_all, pair_summary_csv)
data.table::fwrite(top_pairs_by_class, top_pairs_by_class_csv)
data.table::fwrite(sample_best_view, sample_best_csv)

cat("\nSaved:\n")
cat(candidate_metrics_csv, "\n")
cat(pair_summary_csv, "\n")
cat(top_pairs_by_class_csv, "\n")
cat(sample_best_csv, "\n")

cat("\n============================================================\n")
cat("S-3 utilization validation complete.\n")
cat("============================================================\n")
```

---

# 07_extract_s10_uncompensated_care.R

```r
# Scripts/07_extract_s10_uncompensated_care.R
# Extract HCRIS Worksheet S-10 charity care, bad debt, and uncompensated-care fields
# and merge onto the FY2024 provider master with beds.
#
# Compatible with year-flexible setup from Scripts/00_setup.R
#
# Inputs:
#   Processed/hcris_YYYY_provider_master_with_beds.rds
#   Processed/hcris_YYYY_nmrc.rds
#
# Outputs:
#   Processed/hcris_YYYY_s10_uncompensated_care.rds
#   Processed/hcris_YYYY_provider_master_with_s10.rds
#   Output/hcris_YYYY_s10_uncompensated_care.csv
#   Output/hcris_YYYY_provider_master_with_s10.csv
#   Output/hcris_YYYY_s10_profile.csv
#
# Target fields:
#   S-10 line 23, column 3 = charity care cost, expected
#   S-10 line 29          = bad debt cost, expected
#   S-10 line 30          = uncompensated care cost, expected
#   S-10 line 31          = total unreimbursed + uncompensated care, expected
#
# We extract broadly from S100001 and S100002 first, then validate candidate columns.
# If the exact column differs, the profile output will make that visible.

source("Scripts/00_setup.R")

cat("\n============================================================\n")
cat("EXTRACT HCRIS S-10 UNCOMPENSATED CARE VARIABLES\n")
cat("============================================================\n")
cat("Build year:", hcris_year_label, "\n\n")

# ============================================================
# 1. Load inputs
# ============================================================

provider_base_file <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_provider_master_with_beds.rds")
)

nmrc_file <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_nmrc.rds")
)

if (!file.exists(provider_base_file)) {
  stop("Missing provider master with beds file: ", provider_base_file)
}

if (!file.exists(nmrc_file)) {
  stop("Missing NMRC file: ", nmrc_file)
}

provider_base <- readRDS(provider_base_file)
nmrc <- readRDS(nmrc_file)

cat("Loaded:\n")
cat(provider_base_file, "\n")
cat(nmrc_file, "\n")

cat("\nProvider base rows:", nrow(provider_base), "\n")
cat("NMRC rows:", nrow(nmrc), "\n")

# ============================================================
# 2. Safety checks
# ============================================================

required_provider_cols <- c(
  "rpt_rec_num",
  "prvdr_num_chr",
  "provider_name",
  "provider_model_class",
  "provider_backbone_include_v1"
)

required_nmrc_cols <- c(
  "rpt_rec_num",
  "wksht_cd",
  "line_num_chr",
  "clmn_num_chr",
  "itm_val_num"
)

missing_provider <- setdiff(required_provider_cols, names(provider_base))
missing_nmrc <- setdiff(required_nmrc_cols, names(nmrc))

if (length(missing_provider) > 0) {
  stop(
    "Provider base missing required columns:\n",
    paste(missing_provider, collapse = "\n")
  )
}

if (length(missing_nmrc) > 0) {
  stop(
    "NMRC missing required columns:\n",
    paste(missing_nmrc, collapse = "\n")
  )
}

# ============================================================
# 3. Included provider universe
# ============================================================

included_providers <- provider_base[
  provider_backbone_include_v1 == TRUE,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    city,
    state_abbrev,
    provider_model_class,
    facility_type
  )
]

cat("\nBackbone-included providers:", nrow(included_providers), "\n")
print(included_providers[, .N, by = provider_model_class][order(-N)])

# ============================================================
# 4. Extract S-10 candidate numeric fields
# ============================================================

s10_long <- nmrc[
  rpt_rec_num %in% included_providers$rpt_rec_num &
    wksht_cd %in% c("S100001", "S100002") &
    line_num_chr >= "00100" &
    line_num_chr <= "04000" &
    !is.na(itm_val_num),
  .(
    rpt_rec_num,
    wksht_cd,
    line_num_chr,
    clmn_num_chr,
    itm_val_num
  )
]

s10_long <- merge(
  s10_long,
  included_providers,
  by = "rpt_rec_num",
  all.x = TRUE
)

cat("\nS-10 candidate rows:", nrow(s10_long), "\n")
cat("S-10 candidate reports:", data.table::uniqueN(s10_long$rpt_rec_num), "\n")

# ============================================================
# 5. Profile S-10 fields
# ============================================================

s10_profile <- s10_long[
  ,
  .(
    n_rows = .N,
    n_reports = uniqueN(rpt_rec_num),
    nonzero_reports = uniqueN(rpt_rec_num[!is.na(itm_val_num) & itm_val_num != 0]),
    min_value = suppressWarnings(min(itm_val_num, na.rm = TRUE)),
    p25_value = suppressWarnings(as.numeric(quantile(itm_val_num, 0.25, na.rm = TRUE))),
    median_value = suppressWarnings(median(itm_val_num, na.rm = TRUE)),
    mean_value = suppressWarnings(mean(itm_val_num, na.rm = TRUE)),
    p75_value = suppressWarnings(as.numeric(quantile(itm_val_num, 0.75, na.rm = TRUE))),
    max_value = suppressWarnings(max(itm_val_num, na.rm = TRUE)),
    total_value = sum(itm_val_num, na.rm = TRUE)
  ),
  by = .(wksht_cd, line_num_chr, clmn_num_chr)
][order(wksht_cd, line_num_chr, clmn_num_chr)]

for (cc in c("min_value", "p25_value", "median_value", "mean_value", "p75_value", "max_value")) {
  s10_profile[
    is.infinite(get(cc)),
    (cc) := NA_real_
  ]
}

s10_profile_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_s10_profile.csv")
)

data.table::fwrite(s10_profile, s10_profile_csv)

cat("\nS-10 profile around target lines 02300, 02900, 03000, 03100:\n")
print(s10_profile[
  line_num_chr %in% c("02300", "02900", "03000", "03100")
][order(wksht_cd, line_num_chr, clmn_num_chr)])

cat("\nS-10 profile first 150 rows:\n")
print(s10_profile[1:150])

# ============================================================
# 6. Create wide S-10 table
# ============================================================

s10_long[
  ,
  field_key := paste0(wksht_cd, "_L", line_num_chr, "_C", clmn_num_chr)
]

s10_wide_long <- s10_long[
  ,
  .(
    value = suppressWarnings(sum(itm_val_num, na.rm = TRUE))
  ),
  by = .(rpt_rec_num, field_key)
]

s10_wide <- data.table::dcast(
  s10_wide_long,
  rpt_rec_num ~ field_key,
  value.var = "value"
)

# ============================================================
# 7. Helpers
# ============================================================

get_existing_numeric <- function(dt, colname) {
  if (colname %in% names(dt)) {
    return(as.numeric(dt[[colname]]))
  }
  
  rep(NA_real_, nrow(dt))
}

coalesce_numeric <- function(...) {
  vals <- list(...)
  out <- vals[[1]]
  
  if (length(vals) > 1) {
    for (v in vals[-1]) {
      out <- data.table::fifelse(
        is.na(out),
        v,
        out
      )
    }
  }
  
  out
}

# ============================================================
# 8. Extract expected S-10 fields
# ============================================================

s10 <- copy(s10_wide)

# Charity care cost:
# expected S-10 line 23, column 3.
s10[
  ,
  charity_care_cost :=
    coalesce_numeric(
      get_existing_numeric(s10, "S100001_L02300_C00300"),
      get_existing_numeric(s10, "S100002_L02300_C00300")
    )
]

# Bad debt cost:
# expected line 29; column may vary, so retain multiple candidates.
s10[
  ,
  bad_debt_cost :=
    coalesce_numeric(
      get_existing_numeric(s10, "S100001_L02900_C00100"),
      get_existing_numeric(s10, "S100001_L02900_C00200"),
      get_existing_numeric(s10, "S100001_L02900_C00300"),
      get_existing_numeric(s10, "S100002_L02900_C00100"),
      get_existing_numeric(s10, "S100002_L02900_C00200"),
      get_existing_numeric(s10, "S100002_L02900_C00300")
    )
]

# Uncompensated care cost:
# expected line 30.
s10[
  ,
  uncompensated_care_cost :=
    coalesce_numeric(
      get_existing_numeric(s10, "S100001_L03000_C00100"),
      get_existing_numeric(s10, "S100001_L03000_C00200"),
      get_existing_numeric(s10, "S100001_L03000_C00300"),
      get_existing_numeric(s10, "S100002_L03000_C00100"),
      get_existing_numeric(s10, "S100002_L03000_C00200"),
      get_existing_numeric(s10, "S100002_L03000_C00300")
    )
]

# Total unreimbursed + uncompensated care:
# expected line 31.
s10[
  ,
  total_unreimbursed_and_uncompensated_cost :=
    coalesce_numeric(
      get_existing_numeric(s10, "S100001_L03100_C00100"),
      get_existing_numeric(s10, "S100001_L03100_C00200"),
      get_existing_numeric(s10, "S100001_L03100_C00300"),
      get_existing_numeric(s10, "S100002_L03100_C00100"),
      get_existing_numeric(s10, "S100002_L03100_C00200"),
      get_existing_numeric(s10, "S100002_L03100_C00300")
    )
]

# Replace true missing with NA, but keep zero as zero.
s10_core <- s10[
  ,
  .(
    rpt_rec_num,
    charity_care_cost,
    bad_debt_cost,
    uncompensated_care_cost,
    total_unreimbursed_and_uncompensated_cost
  )
]

# ============================================================
# 9. Validation equations / diagnostic checks
# ============================================================

# Expected identity in many S-10 structures:
# uncompensated care cost should be charity care cost + bad debt cost,
# or close to it, depending on worksheet definitions and additional adjustments.
s10_core[
  ,
  charity_plus_bad_debt :=
    fifelse(is.na(charity_care_cost), 0, charity_care_cost) +
    fifelse(is.na(bad_debt_cost), 0, bad_debt_cost)
]

s10_core[
  ,
  uc_minus_charity_bad_debt :=
    uncompensated_care_cost - charity_plus_bad_debt
]

s10_core[
  ,
  s10_any_data_flag :=
    !is.na(charity_care_cost) |
    !is.na(bad_debt_cost) |
    !is.na(uncompensated_care_cost) |
    !is.na(total_unreimbursed_and_uncompensated_cost)
]

s10_core[
  ,
  s10_core_complete_flag :=
    !is.na(uncompensated_care_cost) &
    !is.na(bad_debt_cost)
]

s10_core[
  ,
  uc_nonnegative_flag :=
    !is.na(uncompensated_care_cost) &
    uncompensated_care_cost >= 0
]

s10_core[
  ,
  bad_debt_nonnegative_flag :=
    !is.na(bad_debt_cost) &
    bad_debt_cost >= 0
]

s10_core[
  ,
  charity_nonnegative_flag :=
    !is.na(charity_care_cost) &
    charity_care_cost >= 0
]

s10_core[
  ,
  s10_use_for_model_flag :=
    s10_any_data_flag == TRUE &
    uc_nonnegative_flag == TRUE
]

# ============================================================
# 10. Merge with provider base
# ============================================================

provider_master_with_s10 <- merge(
  provider_base,
  s10_core,
  by = "rpt_rec_num",
  all.x = TRUE
)

flag_cols <- c(
  "s10_any_data_flag",
  "s10_core_complete_flag",
  "uc_nonnegative_flag",
  "bad_debt_nonnegative_flag",
  "charity_nonnegative_flag",
  "s10_use_for_model_flag"
)

for (fc in flag_cols) {
  provider_master_with_s10[
    is.na(get(fc)),
    (fc) := FALSE
  ]
}

# For model arithmetic later, keep raw and zero-filled versions separately.
provider_master_with_s10[
  ,
  charity_care_cost_model :=
    fifelse(is.na(charity_care_cost), 0, charity_care_cost)
]

provider_master_with_s10[
  ,
  bad_debt_cost_model :=
    fifelse(is.na(bad_debt_cost), 0, bad_debt_cost)
]

provider_master_with_s10[
  ,
  uncompensated_care_cost_model :=
    fifelse(is.na(uncompensated_care_cost), 0, uncompensated_care_cost)
]

provider_master_with_s10[
  ,
  total_unreimbursed_and_uncompensated_cost_model :=
    fifelse(
      is.na(total_unreimbursed_and_uncompensated_cost),
      0,
      total_unreimbursed_and_uncompensated_cost
    )
]

# ============================================================
# 11. Save outputs
# ============================================================

s10_rds <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_s10_uncompensated_care.rds")
)

provider_s10_rds <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_provider_master_with_s10.rds")
)

s10_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_s10_uncompensated_care.csv")
)

provider_s10_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_provider_master_with_s10.csv")
)

saveRDS(s10_core, s10_rds)
saveRDS(provider_master_with_s10, provider_s10_rds)

data.table::fwrite(s10_core, s10_csv)
data.table::fwrite(provider_master_with_s10, provider_s10_csv)

# ============================================================
# 12. Print summaries
# ============================================================

cat("\n============================================================\n")
cat("S-10 EXTRACTION COMPLETE\n")
cat("============================================================\n")

cat("\nRows in S-10 core table:", nrow(s10_core), "\n")
cat("Rows in provider master with S-10:", nrow(provider_master_with_s10), "\n")

cat("\nS-10 data availability, all reports:\n")
print(provider_master_with_s10[
  ,
  .N,
  by = s10_any_data_flag
][order(s10_any_data_flag)])

cat("\nS-10 data availability, backbone-included reports:\n")
print(provider_master_with_s10[
  provider_backbone_include_v1 == TRUE,
  .N,
  by = s10_any_data_flag
][order(s10_any_data_flag)])

cat("\nS-10 completeness / model usability, backbone-included reports:\n")
print(provider_master_with_s10[
  provider_backbone_include_v1 == TRUE,
  .(
    providers = .N,
    s10_any_data = sum(s10_any_data_flag, na.rm = TRUE),
    s10_core_complete = sum(s10_core_complete_flag, na.rm = TRUE),
    uc_nonnegative = sum(uc_nonnegative_flag, na.rm = TRUE),
    bad_debt_nonnegative = sum(bad_debt_nonnegative_flag, na.rm = TRUE),
    charity_nonnegative = sum(charity_nonnegative_flag, na.rm = TRUE),
    s10_use_for_model = sum(s10_use_for_model_flag, na.rm = TRUE)
  )
])

cat("\nS-10 totals by provider class, backbone-included:\n")
print(provider_master_with_s10[
  provider_backbone_include_v1 == TRUE,
  .(
    providers = .N,
    s10_any_data = sum(s10_any_data_flag, na.rm = TRUE),
    s10_use_for_model = sum(s10_use_for_model_flag, na.rm = TRUE),
    
    total_charity_care_cost =
      sum(charity_care_cost_model, na.rm = TRUE),
    
    total_bad_debt_cost =
      sum(bad_debt_cost_model, na.rm = TRUE),
    
    total_uncompensated_care_cost =
      sum(uncompensated_care_cost_model, na.rm = TRUE),
    
    total_unreimbursed_and_uncompensated_cost =
      sum(total_unreimbursed_and_uncompensated_cost_model, na.rm = TRUE),
    
    median_uncompensated_care_cost =
      median(uncompensated_care_cost, na.rm = TRUE),
    
    mean_uncompensated_care_cost =
      mean(uncompensated_care_cost, na.rm = TRUE)
  ),
  by = provider_model_class
][order(-providers)])

cat("\nDistribution of uncompensated care cost, backbone-included with S-10 model data:\n")
print(summary(provider_master_with_s10[
  provider_backbone_include_v1 == TRUE &
    s10_use_for_model_flag == TRUE,
  uncompensated_care_cost
]))

cat("\nLargest uncompensated-care cost providers, backbone-included:\n")
print(provider_master_with_s10[
  provider_backbone_include_v1 == TRUE &
    s10_use_for_model_flag == TRUE,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    city,
    state_abbrev,
    provider_model_class,
    charity_care_cost,
    bad_debt_cost,
    uncompensated_care_cost,
    total_unreimbursed_and_uncompensated_cost,
    uc_minus_charity_bad_debt
  )
][order(-uncompensated_care_cost)][1:30])

cat("\nS-10 validation: UC minus charity+bad debt, backbone-included:\n")
print(summary(provider_master_with_s10[
  provider_backbone_include_v1 == TRUE &
    s10_use_for_model_flag == TRUE,
  uc_minus_charity_bad_debt
]))

cat("\nPotential S-10 negative-value checks, backbone-included:\n")

negative_s10 <- provider_master_with_s10[
  provider_backbone_include_v1 == TRUE &
    (
      (!is.na(charity_care_cost) & charity_care_cost < 0) |
        (!is.na(bad_debt_cost) & bad_debt_cost < 0) |
        (!is.na(uncompensated_care_cost) & uncompensated_care_cost < 0)
    ),
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    provider_model_class,
    charity_care_cost,
    bad_debt_cost,
    uncompensated_care_cost
  )
]

if (nrow(negative_s10) == 0) {
  cat("None\n")
} else {
  print(negative_s10[1:50])
}

cat("\nSample backbone-included providers with S-10:\n")
print(provider_master_with_s10[
  provider_backbone_include_v1 == TRUE,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    city,
    state_abbrev,
    provider_model_class,
    charity_care_cost,
    bad_debt_cost,
    uncompensated_care_cost,
    total_unreimbursed_and_uncompensated_cost,
    s10_any_data_flag,
    s10_use_for_model_flag
  )
][1:30])

cat("\nSaved:\n")
cat(s10_rds, "\n")
cat(provider_s10_rds, "\n")
cat(s10_csv, "\n")
cat(provider_s10_csv, "\n")
cat(s10_profile_csv, "\n")

cat("\n============================================================\n")
```

---

# 08_extract_g2_g3_revenue_expense.R

```r
# Scripts/08_extract_g2_g3_revenue_expense.R
# Extract HCRIS Worksheet G-2 / G-3 revenue fields and merge onto the
# FY2024 provider master with S-10.
#
# This version keeps the standard acute G-2/G-3 extraction and adds three
# controlled fallback layers:
#   1. Rural primary care / IHS fallback
#   2. Name-validated children's fallback
#   3. Nonstandard total-revenue fallback for specialty / behavioral / rehab-like records
#
# Key correction from prior version:
#   The old specialty_g200000_l04300_fallback was too broad and allowed two
#   net-to-gross outliers above 1.50. This script renames that layer as a
#   nonstandard fallback and requires a fallback net-to-gross plausibility check.
#
# Also corrected:
#   Raw Children's hospital is not trusted by itself. Children's fallback is only
#   used when the provider name/facility type looks pediatric. Raw Children's
#   records that look behavioral/rehab/specialty are routed to the nonstandard
#   fallback instead of receiving the children's 45% OP exposure assumption.
#
# Inputs:
#   Processed/hcris_YYYY_provider_master_with_s10.rds
#   Processed/hcris_YYYY_nmrc.rds
#
# Outputs:
#   Processed/hcris_YYYY_g2_g3_revenue_expense.rds
#   Processed/hcris_YYYY_provider_master_with_financials.rds
#   Output/hcris_YYYY_g2_g3_revenue_expense.csv
#   Output/hcris_YYYY_provider_master_with_financials.csv
#   Output/hcris_YYYY_g2_g3_profile.csv

source("Scripts/00_setup.R")

cat("\n============================================================\n")
cat("EXTRACT HCRIS G-2 / G-3 REVENUE AND EXPENSE VARIABLES\n")
cat("============================================================\n")
cat("Build year:", hcris_year_label, "\n\n")

# ============================================================
# 0. Model assumptions for fallback exposure
# ============================================================

rural_fallback_outpatient_share_low  <- 0.20
rural_fallback_outpatient_share_base <- 0.30
rural_fallback_outpatient_share_high <- 0.40

children_fallback_outpatient_share_low  <- 0.30
children_fallback_outpatient_share_base <- 0.45
children_fallback_outpatient_share_high <- 0.60

nonstandard_fallback_outpatient_share_low  <- 0.05
nonstandard_fallback_outpatient_share_base <- 0.10
nonstandard_fallback_outpatient_share_high <- 0.15

fallback_net_to_gross_max <- 1.50
fallback_net_to_gross_min <- 0.00

# ============================================================
# 1. Load inputs
# ============================================================

provider_base_file <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_provider_master_with_s10.rds")
)

nmrc_file <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_nmrc.rds")
)

if (!file.exists(provider_base_file)) {
  stop("Missing provider master with S-10 file: ", provider_base_file)
}

if (!file.exists(nmrc_file)) {
  stop("Missing NMRC file: ", nmrc_file)
}

provider_base <- readRDS(provider_base_file)
nmrc <- readRDS(nmrc_file)

cat("Loaded:\n")
cat(provider_base_file, "\n")
cat(nmrc_file, "\n")

cat("\nProvider base rows:", nrow(provider_base), "\n")
cat("NMRC rows:", nrow(nmrc), "\n")

# ============================================================
# 2. Safety checks
# ============================================================

required_provider_cols <- c(
  "rpt_rec_num",
  "prvdr_num_chr",
  "provider_name",
  "provider_model_class",
  "provider_backbone_include_v1"
)

required_nmrc_cols <- c(
  "rpt_rec_num",
  "wksht_cd",
  "line_num_chr",
  "clmn_num_chr",
  "itm_val_num"
)

missing_provider <- setdiff(required_provider_cols, names(provider_base))
missing_nmrc <- setdiff(required_nmrc_cols, names(nmrc))

if (length(missing_provider) > 0) {
  stop("Provider base missing required columns:\n", paste(missing_provider, collapse = "\n"))
}

if (length(missing_nmrc) > 0) {
  stop("NMRC missing required columns:\n", paste(missing_nmrc, collapse = "\n"))
}

# Ensure common optional columns exist.
if (!"facility_type" %in% names(provider_base)) {
  provider_base[, facility_type := NA_character_]
}
if (!"city" %in% names(provider_base)) {
  provider_base[, city := NA_character_]
}
if (!"state_abbrev" %in% names(provider_base)) {
  provider_base[, state_abbrev := NA_character_]
}
if (!"hospital_beds" %in% names(provider_base)) {
  provider_base[, hospital_beds := NA_real_]
}

# ============================================================
# 3. Included provider universe and provisional name flags
# ============================================================

provider_base[
  ,
  provider_name_upper := stringr::str_to_upper(provider_name)
]

provider_base[
  ,
  facility_type_upper := stringr::str_to_upper(facility_type)
]

provider_base[
  ,
  provisional_children_name_flag :=
    stringr::str_detect(provider_name_upper, "CHILD|CHILDREN|PEDIATRIC|SHRINERS") |
    stringr::str_detect(facility_type_upper, "CHILDREN")
]

provider_base[
  ,
  provisional_behavioral_rehab_specialty_name_flag :=
    stringr::str_detect(
      provider_name_upper,
      paste(
        c(
          "PSYCH",
          "BEHAVIOR",
          "BEHAVIORAL",
          "MENTAL",
          "STATE HOSPITAL",
          "FORENSIC",
          "RECOVERY",
          "SANCTUARY",
          "GATEWAYS",
          "WILLOW ROCK",
          "CENTER FOR COGNITIVE",
          "HARMON HOSPITAL",
          "REHAB",
          "REHABILITATION",
          "VIBRA",
          "RESTORATIVE",
          "SPECIALTY",
          "LTCH",
          "LONG TERM",
          "LONG-TERM",
          "SURGICAL",
          "ORTHOPAEDIC",
          "ORTHOPEDIC",
          "ADVANCED CARE",
          "REUNION",
          "ENCOMPASS",
          "WARM SPRINGS"
        ),
        collapse = "|"
      )
    ) |
    stringr::str_detect(facility_type_upper, "PSYCHIATRIC|REHABILITATION|LONG-TERM|LONG TERM")
]

provider_base[
  ,
  provisional_rural_primary_flag :=
    provider_model_class == "Rural primary care hospital"
]

included_providers <- provider_base[
  provider_backbone_include_v1 == TRUE,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    city,
    state_abbrev,
    provider_model_class,
    facility_type,
    hospital_beds,
    provisional_children_name_flag,
    provisional_behavioral_rehab_specialty_name_flag,
    provisional_rural_primary_flag
  )
]

cat("\nBackbone-included providers:", nrow(included_providers), "\n")
print(included_providers[, .N, by = provider_model_class][order(-N)])

cat("\nProvisional name flags among backbone providers:\n")
print(included_providers[
  ,
  .(
    providers = .N,
    provisional_children_name = sum(provisional_children_name_flag, na.rm = TRUE),
    provisional_behavioral_rehab_specialty = sum(provisional_behavioral_rehab_specialty_name_flag, na.rm = TRUE),
    provisional_rural_primary = sum(provisional_rural_primary_flag, na.rm = TRUE)
  ),
  by = provider_model_class
][order(provider_model_class)])

# ============================================================
# 4. Extract broad G-family numeric fields
# ============================================================

g_long <- nmrc[
  rpt_rec_num %in% included_providers$rpt_rec_num &
    stringr::str_detect(wksht_cd, "^G") &
    line_num_chr >= "00100" &
    line_num_chr <= "05000" &
    !is.na(itm_val_num),
  .(
    rpt_rec_num,
    wksht_cd,
    line_num_chr,
    clmn_num_chr,
    itm_val_num
  )
]

g_long <- merge(
  g_long,
  included_providers,
  by = "rpt_rec_num",
  all.x = TRUE
)

cat("\nG-family candidate rows:", nrow(g_long), "\n")
cat("G-family candidate reports:", data.table::uniqueN(g_long$rpt_rec_num), "\n")

# ============================================================
# 5. Profile G fields
# ============================================================

g_profile <- g_long[
  ,
  .(
    n_rows = .N,
    n_reports = uniqueN(rpt_rec_num),
    nonzero_reports = uniqueN(rpt_rec_num[!is.na(itm_val_num) & itm_val_num != 0]),
    min_value = suppressWarnings(min(itm_val_num, na.rm = TRUE)),
    p25_value = suppressWarnings(as.numeric(quantile(itm_val_num, 0.25, na.rm = TRUE))),
    median_value = suppressWarnings(median(itm_val_num, na.rm = TRUE)),
    mean_value = suppressWarnings(mean(itm_val_num, na.rm = TRUE)),
    p75_value = suppressWarnings(as.numeric(quantile(itm_val_num, 0.75, na.rm = TRUE))),
    max_value = suppressWarnings(max(itm_val_num, na.rm = TRUE)),
    total_value = sum(itm_val_num, na.rm = TRUE)
  ),
  by = .(provider_model_class, wksht_cd, line_num_chr, clmn_num_chr)
][order(provider_model_class, wksht_cd, line_num_chr, clmn_num_chr)]

for (cc in c("min_value", "p25_value", "median_value", "mean_value", "p75_value", "max_value")) {
  g_profile[is.infinite(get(cc)), (cc) := NA_real_]
}

g_profile_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_g2_g3_profile.csv")
)

data.table::fwrite(g_profile, g_profile_csv)

cat("\nG-2 profile around standard acute line 02800:\n")
print(g_profile[
  wksht_cd == "G200000" &
    line_num_chr %in% c("02700", "02800", "02900")
][order(provider_model_class, wksht_cd, line_num_chr, clmn_num_chr)])

cat("\nG-3 profile around candidate lines 00100-01000:\n")
print(g_profile[
  wksht_cd %in% c("G300000", "G300001") &
    line_num_chr >= "00100" &
    line_num_chr <= "01000"
][order(provider_model_class, wksht_cd, line_num_chr, clmn_num_chr)])

cat("\nFallback field profile by raw provider class:\n")
print(g_profile[
  (
    (wksht_cd == "G200000" & line_num_chr %in% c("02800", "02900", "04300")) |
      (wksht_cd == "G300000" & line_num_chr %in% c("00100", "00300", "00400"))
  )
][order(provider_model_class, wksht_cd, line_num_chr, clmn_num_chr)])

# ============================================================
# 6. Create wide G table
# ============================================================

g_long[
  ,
  field_key := paste0(wksht_cd, "_L", line_num_chr, "_C", clmn_num_chr)
]

g_wide_long <- g_long[
  ,
  .(value = suppressWarnings(sum(itm_val_num, na.rm = TRUE))),
  by = .(rpt_rec_num, field_key)
]

g_wide <- data.table::dcast(
  g_wide_long,
  rpt_rec_num ~ field_key,
  value.var = "value"
)

# ============================================================
# 7. Helpers
# ============================================================

get_existing_numeric <- function(dt, colname) {
  if (colname %in% names(dt)) {
    return(as.numeric(dt[[colname]]))
  }
  rep(NA_real_, nrow(dt))
}

coalesce_numeric <- function(...) {
  vals <- list(...)
  out <- vals[[1]]
  if (length(vals) > 1) {
    for (v in vals[-1]) {
      out <- data.table::fifelse(is.na(out), v, out)
    }
  }
  out
}

safe_ratio <- function(num, den) {
  data.table::fifelse(
    !is.na(num) & !is.na(den) & den != 0,
    num / den,
    NA_real_
  )
}

# ============================================================
# 8. Extract standard and fallback G fields
# ============================================================

g_fin <- copy(g_wide)

# -----------------------------
# Standard acute-hospital G-2/G-3 fields
# -----------------------------

g_fin[, standard_gross_inpatient_patient_revenue := get_existing_numeric(g_fin, "G200000_L02800_C00100")]
g_fin[, standard_gross_outpatient_patient_revenue := get_existing_numeric(g_fin, "G200000_L02800_C00200")]
g_fin[, standard_gross_total_patient_revenue := get_existing_numeric(g_fin, "G200000_L02800_C00300")]

g_fin[
  ,
  standard_net_patient_revenue :=
    coalesce_numeric(
      get_existing_numeric(g_fin, "G300000_L00300_C00100"),
      get_existing_numeric(g_fin, "G300001_L00300_C00100")
    )
]

# Retained G-3 candidate fields for diagnostics only.
g_fin[
  ,
  g3_line_00400_c001 :=
    coalesce_numeric(
      get_existing_numeric(g_fin, "G300000_L00400_C00100"),
      get_existing_numeric(g_fin, "G300001_L00400_C00100")
    )
]

g_fin[
  ,
  g3_line_00500_c001 :=
    coalesce_numeric(
      get_existing_numeric(g_fin, "G300000_L00500_C00100"),
      get_existing_numeric(g_fin, "G300001_L00500_C00100")
    )
]

g_fin[
  ,
  g3_line_00600_c001 :=
    coalesce_numeric(
      get_existing_numeric(g_fin, "G300000_L00600_C00100"),
      get_existing_numeric(g_fin, "G300001_L00600_C00100")
    )
]

g_fin[
  ,
  g3_line_00700_c001 :=
    coalesce_numeric(
      get_existing_numeric(g_fin, "G300000_L00700_C00100"),
      get_existing_numeric(g_fin, "G300001_L00700_C00100")
    )
]

# -----------------------------
# Shared nonstandard fallback total-like fields
# -----------------------------

g_fin[, fallback_g200000_l04300_c002 := get_existing_numeric(g_fin, "G200000_L04300_C00200")]
g_fin[, fallback_g300000_l00400_c001 := get_existing_numeric(g_fin, "G300000_L00400_C00100")]
g_fin[, fallback_g200000_l02900_c002 := get_existing_numeric(g_fin, "G200000_L02900_C00200")]

g_fin[
  ,
  fallback_total_revenue :=
    coalesce_numeric(
      fallback_g200000_l04300_c002,
      fallback_g300000_l00400_c001,
      fallback_g200000_l02900_c002
    )
]

g_fin[
  ,
  fallback_crosscheck_ratio :=
    safe_ratio(fallback_g200000_l04300_c002, fallback_g300000_l00400_c001)
]

g_fin[
  ,
  fallback_crosscheck_plausible_flag :=
    is.na(fallback_crosscheck_ratio) |
    (fallback_crosscheck_ratio >= 0.95 & fallback_crosscheck_ratio <= 1.05)
]

# -----------------------------
# Children's total-only fallback fields
# -----------------------------

g_fin[, children_fallback_g200000_l02800_c003 := get_existing_numeric(g_fin, "G200000_L02800_C00300")]
g_fin[, children_fallback_g200000_l02800_c001 := get_existing_numeric(g_fin, "G200000_L02800_C00100")]
g_fin[, children_fallback_g300000_l00100_c001 := get_existing_numeric(g_fin, "G300000_L00100_C00100")]
g_fin[, children_fallback_g300000_l00300_c001 := get_existing_numeric(g_fin, "G300000_L00300_C00100")]

g_fin[
  ,
  children_fallback_total_revenue :=
    coalesce_numeric(
      children_fallback_g200000_l02800_c003,
      children_fallback_g200000_l02800_c001,
      children_fallback_g300000_l00100_c001
    )
]

g_fin[, children_fallback_net_patient_revenue := children_fallback_g300000_l00300_c001]

# ============================================================
# 9. Merge provider metadata before deciding method
# ============================================================

g_fin <- merge(
  provider_base[
    ,
    .(
      rpt_rec_num,
      provider_model_class,
      provider_backbone_include_v1,
      provider_name,
      city,
      state_abbrev,
      facility_type,
      hospital_beds,
      provisional_children_name_flag,
      provisional_behavioral_rehab_specialty_name_flag,
      provisional_rural_primary_flag
    )
  ],
  g_fin,
  by = "rpt_rec_num",
  all.y = TRUE
)

# ============================================================
# 10. Standard validation
# ============================================================

g_fin[
  ,
  standard_gross_revenue_sum_check :=
    standard_gross_inpatient_patient_revenue + standard_gross_outpatient_patient_revenue
]

g_fin[
  ,
  standard_gross_total_minus_inpatient_outpatient :=
    standard_gross_total_patient_revenue - standard_gross_revenue_sum_check
]

g_fin[
  ,
  standard_net_to_gross_ratio :=
    safe_ratio(standard_net_patient_revenue, standard_gross_total_patient_revenue)
]

g_fin[
  ,
  standard_outpatient_gross_share :=
    safe_ratio(standard_gross_outpatient_patient_revenue, standard_gross_total_patient_revenue)
]

g_fin[
  ,
  standard_inpatient_gross_share :=
    safe_ratio(standard_gross_inpatient_patient_revenue, standard_gross_total_patient_revenue)
]

g_fin[
  ,
  standard_net_outpatient_exposure_base :=
    standard_gross_outpatient_patient_revenue * standard_net_to_gross_ratio
]

g_fin[
  ,
  standard_g2_revenue_complete_flag :=
    !is.na(standard_gross_total_patient_revenue) &
    standard_gross_total_patient_revenue > 0 &
    !is.na(standard_gross_inpatient_patient_revenue) &
    !is.na(standard_gross_outpatient_patient_revenue)
]

g_fin[
  ,
  standard_g3_net_patient_revenue_complete_flag :=
    !is.na(standard_net_patient_revenue) & standard_net_patient_revenue > 0
]

g_fin[
  ,
  standard_net_to_gross_plausible_flag :=
    !is.na(standard_net_to_gross_ratio) &
    standard_net_to_gross_ratio > fallback_net_to_gross_min &
    standard_net_to_gross_ratio <= fallback_net_to_gross_max
]

g_fin[
  ,
  standard_gross_sum_check_plausible_flag :=
    !is.na(standard_gross_total_minus_inpatient_outpatient) &
    abs(standard_gross_total_minus_inpatient_outpatient) <=
    pmax(1, abs(standard_gross_total_patient_revenue) * 0.01)
]

g_fin[
  ,
  standard_revenue_use_for_model_flag :=
    standard_g2_revenue_complete_flag == TRUE &
    standard_g3_net_patient_revenue_complete_flag == TRUE &
    standard_net_to_gross_plausible_flag == TRUE &
    standard_gross_sum_check_plausible_flag == TRUE
]

# ============================================================
# 11. Rural fallback validation
# ============================================================

g_fin[, rural_primary_care_flag := provisional_rural_primary_flag == TRUE]

g_fin[
  ,
  rural_fallback_available_flag :=
    rural_primary_care_flag == TRUE &
    standard_revenue_use_for_model_flag == FALSE &
    !is.na(fallback_total_revenue) &
    fallback_total_revenue > 0
]

g_fin[
  ,
  rural_fallback_net_patient_revenue_proxy :=
    coalesce_numeric(standard_net_patient_revenue, fallback_total_revenue)
]

g_fin[
  ,
  rural_fallback_net_to_gross_ratio :=
    safe_ratio(rural_fallback_net_patient_revenue_proxy, fallback_total_revenue)
]

g_fin[
  ,
  rural_fallback_net_to_gross_plausible_flag :=
    rural_fallback_available_flag == TRUE &
    !is.na(rural_fallback_net_to_gross_ratio) &
    rural_fallback_net_to_gross_ratio > fallback_net_to_gross_min &
    rural_fallback_net_to_gross_ratio <= fallback_net_to_gross_max
]

g_fin[
  ,
  rural_fallback_use_for_model_flag :=
    rural_fallback_available_flag == TRUE &
    fallback_crosscheck_plausible_flag == TRUE &
    rural_fallback_net_to_gross_plausible_flag == TRUE
]

g_fin[
  ,
  rural_fallback_net_outpatient_exposure_low :=
    fifelse(rural_fallback_use_for_model_flag == TRUE, fallback_total_revenue * rural_fallback_outpatient_share_low, NA_real_)
]

g_fin[
  ,
  rural_fallback_net_outpatient_exposure_base :=
    fifelse(rural_fallback_use_for_model_flag == TRUE, fallback_total_revenue * rural_fallback_outpatient_share_base, NA_real_)
]

g_fin[
  ,
  rural_fallback_net_outpatient_exposure_high :=
    fifelse(rural_fallback_use_for_model_flag == TRUE, fallback_total_revenue * rural_fallback_outpatient_share_high, NA_real_)
]

# ============================================================
# 12. Children's fallback validation
# ============================================================

# Do not trust raw Children's hospital alone. Use pediatric name/facility signal.
g_fin[
  ,
  childrens_hospital_flag :=
    provisional_children_name_flag == TRUE
]

g_fin[
  ,
  children_total_only_fallback_available_flag :=
    childrens_hospital_flag == TRUE &
    standard_revenue_use_for_model_flag == FALSE &
    !is.na(children_fallback_total_revenue) &
    children_fallback_total_revenue > 0 &
    !is.na(children_fallback_net_patient_revenue) &
    children_fallback_net_patient_revenue > 0
]

g_fin[
  ,
  children_total_only_net_to_gross_ratio :=
    safe_ratio(children_fallback_net_patient_revenue, children_fallback_total_revenue)
]

g_fin[
  ,
  children_total_only_net_to_gross_plausible_flag :=
    children_total_only_fallback_available_flag == TRUE &
    !is.na(children_total_only_net_to_gross_ratio) &
    children_total_only_net_to_gross_ratio > fallback_net_to_gross_min &
    children_total_only_net_to_gross_ratio <= fallback_net_to_gross_max
]

g_fin[
  ,
  children_total_only_fallback_use_for_model_flag :=
    children_total_only_fallback_available_flag == TRUE &
    children_total_only_net_to_gross_plausible_flag == TRUE
]

g_fin[
  ,
  children_fallback_net_outpatient_exposure_low :=
    fifelse(
      children_total_only_fallback_use_for_model_flag == TRUE,
      children_fallback_net_patient_revenue * children_fallback_outpatient_share_low,
      NA_real_
    )
]

g_fin[
  ,
  children_fallback_net_outpatient_exposure_base :=
    fifelse(
      children_total_only_fallback_use_for_model_flag == TRUE,
      children_fallback_net_patient_revenue * children_fallback_outpatient_share_base,
      NA_real_
    )
]

g_fin[
  ,
  children_fallback_net_outpatient_exposure_high :=
    fifelse(
      children_total_only_fallback_use_for_model_flag == TRUE,
      children_fallback_net_patient_revenue * children_fallback_outpatient_share_high,
      NA_real_
    )
]

# ============================================================
# 13. Nonstandard total-revenue fallback validation
# ============================================================

# This is the corrected replacement for the overly broad specialty fallback.
# It is meant for raw CAH / behavioral / rehab / specialty-like records that lack
# standard split reporting but have internally consistent G200000 L04300 and
# G300000 L00400 total-like values.

g_fin[
  ,
  nonstandard_fallback_candidate_flag :=
    standard_revenue_use_for_model_flag == FALSE &
    rural_fallback_use_for_model_flag == FALSE &
    children_total_only_fallback_use_for_model_flag == FALSE &
    !is.na(fallback_total_revenue) &
    fallback_total_revenue > 0 &
    (
      provider_model_class == "Critical access hospital" |
        provisional_behavioral_rehab_specialty_name_flag == TRUE
    )
]

g_fin[
  ,
  nonstandard_fallback_net_patient_revenue_proxy :=
    coalesce_numeric(standard_net_patient_revenue, fallback_total_revenue)
]

g_fin[
  ,
  nonstandard_fallback_net_to_gross_ratio :=
    safe_ratio(nonstandard_fallback_net_patient_revenue_proxy, fallback_total_revenue)
]

g_fin[
  ,
  nonstandard_fallback_net_to_gross_plausible_flag :=
    nonstandard_fallback_candidate_flag == TRUE &
    !is.na(nonstandard_fallback_net_to_gross_ratio) &
    nonstandard_fallback_net_to_gross_ratio > fallback_net_to_gross_min &
    nonstandard_fallback_net_to_gross_ratio <= fallback_net_to_gross_max
]

g_fin[
  ,
  nonstandard_fallback_failed_plausibility_flag :=
    nonstandard_fallback_candidate_flag == TRUE &
    (
      fallback_crosscheck_plausible_flag == FALSE |
        nonstandard_fallback_net_to_gross_plausible_flag == FALSE
    )
]

g_fin[
  ,
  nonstandard_fallback_use_for_model_flag :=
    nonstandard_fallback_candidate_flag == TRUE &
    fallback_crosscheck_plausible_flag == TRUE &
    nonstandard_fallback_net_to_gross_plausible_flag == TRUE
]

g_fin[
  ,
  nonstandard_fallback_net_outpatient_exposure_low :=
    fifelse(
      nonstandard_fallback_use_for_model_flag == TRUE,
      fallback_total_revenue * nonstandard_fallback_outpatient_share_low,
      NA_real_
    )
]

g_fin[
  ,
  nonstandard_fallback_net_outpatient_exposure_base :=
    fifelse(
      nonstandard_fallback_use_for_model_flag == TRUE,
      fallback_total_revenue * nonstandard_fallback_outpatient_share_base,
      NA_real_
    )
]

g_fin[
  ,
  nonstandard_fallback_net_outpatient_exposure_high :=
    fifelse(
      nonstandard_fallback_use_for_model_flag == TRUE,
      fallback_total_revenue * nonstandard_fallback_outpatient_share_high,
      NA_real_
    )
]

# ============================================================
# 14. Final unified revenue fields
# ============================================================

g_fin[
  ,
  revenue_source_method := data.table::fcase(
    standard_revenue_use_for_model_flag == TRUE,
    "standard_g2_l028_split",
    
    rural_fallback_use_for_model_flag == TRUE,
    "rural_g200000_l04300_fallback",
    
    children_total_only_fallback_use_for_model_flag == TRUE,
    "children_total_only_fallback",
    
    nonstandard_fallback_use_for_model_flag == TRUE,
    "nonstandard_g200000_l04300_fallback",
    
    nonstandard_fallback_failed_plausibility_flag == TRUE,
    "nonstandard_fallback_failed_plausibility",
    
    !is.na(standard_gross_total_patient_revenue) &
      standard_gross_total_patient_revenue > 0 &
      standard_g3_net_patient_revenue_complete_flag == TRUE,
    "g2_total_only_no_outpatient_split",
    
    default = "missing_or_unusable"
  )
]

g_fin[
  ,
  revenue_use_for_model_flag :=
    revenue_source_method %in% c(
      "standard_g2_l028_split",
      "rural_g200000_l04300_fallback",
      "children_total_only_fallback",
      "nonstandard_g200000_l04300_fallback"
    )
]

g_fin[
  ,
  gross_total_patient_revenue := data.table::fcase(
    standard_revenue_use_for_model_flag == TRUE,
    standard_gross_total_patient_revenue,
    
    rural_fallback_use_for_model_flag == TRUE,
    fallback_total_revenue,
    
    children_total_only_fallback_use_for_model_flag == TRUE,
    children_fallback_total_revenue,
    
    nonstandard_fallback_use_for_model_flag == TRUE,
    fallback_total_revenue,
    
    default = standard_gross_total_patient_revenue
  )
]

g_fin[
  ,
  gross_inpatient_patient_revenue := data.table::fcase(
    standard_revenue_use_for_model_flag == TRUE,
    standard_gross_inpatient_patient_revenue,
    default = NA_real_
  )
]

g_fin[
  ,
  gross_outpatient_patient_revenue := data.table::fcase(
    standard_revenue_use_for_model_flag == TRUE,
    standard_gross_outpatient_patient_revenue,
    default = NA_real_
  )
]

g_fin[
  ,
  net_patient_revenue := data.table::fcase(
    standard_revenue_use_for_model_flag == TRUE,
    standard_net_patient_revenue,
    
    rural_fallback_use_for_model_flag == TRUE,
    rural_fallback_net_patient_revenue_proxy,
    
    children_total_only_fallback_use_for_model_flag == TRUE,
    children_fallback_net_patient_revenue,
    
    nonstandard_fallback_use_for_model_flag == TRUE,
    nonstandard_fallback_net_patient_revenue_proxy,
    
    default = standard_net_patient_revenue
  )
]

g_fin[, net_to_gross_ratio := safe_ratio(net_patient_revenue, gross_total_patient_revenue)]

g_fin[
  ,
  outpatient_gross_share := data.table::fcase(
    standard_revenue_use_for_model_flag == TRUE,
    standard_outpatient_gross_share,
    
    rural_fallback_use_for_model_flag == TRUE,
    rural_fallback_outpatient_share_base,
    
    children_total_only_fallback_use_for_model_flag == TRUE,
    children_fallback_outpatient_share_base,
    
    nonstandard_fallback_use_for_model_flag == TRUE,
    nonstandard_fallback_outpatient_share_base,
    
    default = NA_real_
  )
]

g_fin[
  ,
  inpatient_gross_share := data.table::fcase(
    standard_revenue_use_for_model_flag == TRUE,
    standard_inpatient_gross_share,
    
    rural_fallback_use_for_model_flag == TRUE,
    1 - rural_fallback_outpatient_share_base,
    
    children_total_only_fallback_use_for_model_flag == TRUE,
    1 - children_fallback_outpatient_share_base,
    
    nonstandard_fallback_use_for_model_flag == TRUE,
    1 - nonstandard_fallback_outpatient_share_base,
    
    default = NA_real_
  )
]

g_fin[
  ,
  net_outpatient_exposure_base := data.table::fcase(
    standard_revenue_use_for_model_flag == TRUE,
    standard_net_outpatient_exposure_base,
    
    rural_fallback_use_for_model_flag == TRUE,
    rural_fallback_net_outpatient_exposure_base,
    
    children_total_only_fallback_use_for_model_flag == TRUE,
    children_fallback_net_outpatient_exposure_base,
    
    nonstandard_fallback_use_for_model_flag == TRUE,
    nonstandard_fallback_net_outpatient_exposure_base,
    
    default = NA_real_
  )
]

g_fin[
  ,
  net_outpatient_exposure_low := data.table::fcase(
    standard_revenue_use_for_model_flag == TRUE,
    standard_net_outpatient_exposure_base,
    
    rural_fallback_use_for_model_flag == TRUE,
    rural_fallback_net_outpatient_exposure_low,
    
    children_total_only_fallback_use_for_model_flag == TRUE,
    children_fallback_net_outpatient_exposure_low,
    
    nonstandard_fallback_use_for_model_flag == TRUE,
    nonstandard_fallback_net_outpatient_exposure_low,
    
    default = NA_real_
  )
]

g_fin[
  ,
  net_outpatient_exposure_high := data.table::fcase(
    standard_revenue_use_for_model_flag == TRUE,
    standard_net_outpatient_exposure_base,
    
    rural_fallback_use_for_model_flag == TRUE,
    rural_fallback_net_outpatient_exposure_high,
    
    children_total_only_fallback_use_for_model_flag == TRUE,
    children_fallback_net_outpatient_exposure_high,
    
    nonstandard_fallback_use_for_model_flag == TRUE,
    nonstandard_fallback_net_outpatient_exposure_high,
    
    default = NA_real_
  )
]

# Backward-compatible aliases.
g_fin[, g2_revenue_complete_flag := standard_g2_revenue_complete_flag]
g_fin[, g3_net_patient_revenue_complete_flag := standard_g3_net_patient_revenue_complete_flag]

g_fin[
  ,
  net_to_gross_plausible_flag :=
    !is.na(net_to_gross_ratio) &
    net_to_gross_ratio > fallback_net_to_gross_min &
    net_to_gross_ratio <= fallback_net_to_gross_max
]

g_fin[, gross_sum_check_plausible_flag := standard_gross_sum_check_plausible_flag]
g_fin[, gross_revenue_sum_check := standard_gross_revenue_sum_check]
g_fin[, gross_total_minus_inpatient_outpatient := standard_gross_total_minus_inpatient_outpatient]

# ============================================================
# 15. Core financial table
# ============================================================

g_fin_core <- g_fin[
  ,
  .(
    rpt_rec_num,
    
    revenue_source_method,
    revenue_use_for_model_flag,
    
    standard_revenue_use_for_model_flag,
    rural_fallback_use_for_model_flag,
    children_total_only_fallback_use_for_model_flag,
    nonstandard_fallback_use_for_model_flag,
    
    rural_fallback_available_flag,
    children_total_only_fallback_available_flag,
    nonstandard_fallback_candidate_flag,
    nonstandard_fallback_failed_plausibility_flag,
    
    fallback_crosscheck_ratio,
    fallback_crosscheck_plausible_flag,
    rural_fallback_net_to_gross_ratio,
    rural_fallback_net_to_gross_plausible_flag,
    children_total_only_net_to_gross_ratio,
    children_total_only_net_to_gross_plausible_flag,
    nonstandard_fallback_net_to_gross_ratio,
    nonstandard_fallback_net_to_gross_plausible_flag,
    
    gross_inpatient_patient_revenue,
    gross_outpatient_patient_revenue,
    gross_total_patient_revenue,
    gross_revenue_sum_check,
    gross_total_minus_inpatient_outpatient,
    
    net_patient_revenue,
    net_to_gross_ratio,
    
    outpatient_gross_share,
    inpatient_gross_share,
    
    net_outpatient_exposure_base,
    net_outpatient_exposure_low,
    net_outpatient_exposure_high,
    
    standard_gross_inpatient_patient_revenue,
    standard_gross_outpatient_patient_revenue,
    standard_gross_total_patient_revenue,
    standard_net_patient_revenue,
    standard_net_to_gross_ratio,
    standard_outpatient_gross_share,
    standard_inpatient_gross_share,
    standard_net_outpatient_exposure_base,
    
    fallback_g200000_l04300_c002,
    fallback_g300000_l00400_c001,
    fallback_g200000_l02900_c002,
    fallback_total_revenue,
    
    rural_fallback_net_patient_revenue_proxy,
    rural_fallback_outpatient_share_low,
    rural_fallback_outpatient_share_base,
    rural_fallback_outpatient_share_high,
    rural_fallback_net_outpatient_exposure_low,
    rural_fallback_net_outpatient_exposure_base,
    rural_fallback_net_outpatient_exposure_high,
    
    children_fallback_g200000_l02800_c003,
    children_fallback_g200000_l02800_c001,
    children_fallback_g300000_l00100_c001,
    children_fallback_g300000_l00300_c001,
    children_fallback_total_revenue,
    children_fallback_net_patient_revenue,
    children_fallback_outpatient_share_low,
    children_fallback_outpatient_share_base,
    children_fallback_outpatient_share_high,
    children_fallback_net_outpatient_exposure_low,
    children_fallback_net_outpatient_exposure_base,
    children_fallback_net_outpatient_exposure_high,
    
    nonstandard_fallback_net_patient_revenue_proxy,
    nonstandard_fallback_outpatient_share_low,
    nonstandard_fallback_outpatient_share_base,
    nonstandard_fallback_outpatient_share_high,
    nonstandard_fallback_net_outpatient_exposure_low,
    nonstandard_fallback_net_outpatient_exposure_base,
    nonstandard_fallback_net_outpatient_exposure_high,
    
    g3_line_00400_c001,
    g3_line_00500_c001,
    g3_line_00600_c001,
    g3_line_00700_c001,
    
    g2_revenue_complete_flag,
    g3_net_patient_revenue_complete_flag,
    net_to_gross_plausible_flag,
    gross_sum_check_plausible_flag
  )
]

# ============================================================
# 16. Merge with provider base
# ============================================================

provider_master_with_financials <- merge(
  provider_base,
  g_fin_core,
  by = "rpt_rec_num",
  all.x = TRUE
)

flag_cols <- c(
  "revenue_use_for_model_flag",
  "standard_revenue_use_for_model_flag",
  "rural_fallback_use_for_model_flag",
  "children_total_only_fallback_use_for_model_flag",
  "nonstandard_fallback_use_for_model_flag",
  "rural_fallback_available_flag",
  "children_total_only_fallback_available_flag",
  "nonstandard_fallback_candidate_flag",
  "nonstandard_fallback_failed_plausibility_flag",
  "fallback_crosscheck_plausible_flag",
  "rural_fallback_net_to_gross_plausible_flag",
  "children_total_only_net_to_gross_plausible_flag",
  "nonstandard_fallback_net_to_gross_plausible_flag",
  "g2_revenue_complete_flag",
  "g3_net_patient_revenue_complete_flag",
  "net_to_gross_plausible_flag",
  "gross_sum_check_plausible_flag"
)

for (fc in flag_cols) {
  if (!fc %in% names(provider_master_with_financials)) {
    provider_master_with_financials[, (fc) := FALSE]
  }
  provider_master_with_financials[is.na(get(fc)), (fc) := FALSE]
}

provider_master_with_financials[
  is.na(revenue_source_method),
  revenue_source_method := "missing_or_unusable"
]

provider_master_with_financials[
  ,
  net_outpatient_exposure_base_model :=
    fifelse(
      is.na(net_outpatient_exposure_base) | revenue_use_for_model_flag == FALSE,
      0,
      net_outpatient_exposure_base
    )
]

provider_master_with_financials[
  ,
  net_outpatient_exposure_low_model :=
    fifelse(
      is.na(net_outpatient_exposure_low) | revenue_use_for_model_flag == FALSE,
      0,
      net_outpatient_exposure_low
    )
]

provider_master_with_financials[
  ,
  net_outpatient_exposure_high_model :=
    fifelse(
      is.na(net_outpatient_exposure_high) | revenue_use_for_model_flag == FALSE,
      0,
      net_outpatient_exposure_high
    )
]

provider_master_with_financials[
  ,
  gross_total_patient_revenue_model :=
    fifelse(
      is.na(gross_total_patient_revenue) | revenue_use_for_model_flag == FALSE,
      0,
      gross_total_patient_revenue
    )
]

provider_master_with_financials[
  ,
  gross_outpatient_patient_revenue_model :=
    fifelse(
      is.na(gross_outpatient_patient_revenue) |
        standard_revenue_use_for_model_flag == FALSE,
      0,
      gross_outpatient_patient_revenue
    )
]

provider_master_with_financials[
  ,
  net_patient_revenue_model :=
    fifelse(
      is.na(net_patient_revenue) | revenue_use_for_model_flag == FALSE,
      0,
      net_patient_revenue
    )
]

# ============================================================
# 17. Save outputs
# ============================================================

g_fin_rds <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_g2_g3_revenue_expense.rds")
)

provider_fin_rds <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_provider_master_with_financials.rds")
)

g_fin_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_g2_g3_revenue_expense.csv")
)

provider_fin_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_provider_master_with_financials.csv")
)

saveRDS(g_fin_core, g_fin_rds)
saveRDS(provider_master_with_financials, provider_fin_rds)

data.table::fwrite(g_fin_core, g_fin_csv)
data.table::fwrite(provider_master_with_financials, provider_fin_csv)

# ============================================================
# 18. Print summaries
# ============================================================

cat("\n============================================================\n")
cat("G-2 / G-3 REVENUE EXTRACTION COMPLETE\n")
cat("============================================================\n")

cat("\nRows in G financial table:", nrow(g_fin_core), "\n")
cat("Rows in provider master with financials:", nrow(provider_master_with_financials), "\n")

cat("\nRevenue source methods, all reports:\n")
print(provider_master_with_financials[
  ,
  .N,
  by = revenue_source_method
][order(-N)])

cat("\nRevenue source methods, backbone-included reports:\n")
print(provider_master_with_financials[
  provider_backbone_include_v1 == TRUE,
  .N,
  by = revenue_source_method
][order(-N)])

cat("\nRevenue availability, backbone-included reports:\n")
print(provider_master_with_financials[
  provider_backbone_include_v1 == TRUE,
  .N,
  by = revenue_use_for_model_flag
][order(revenue_use_for_model_flag)])

cat("\nRevenue completeness / validation, backbone-included reports:\n")
print(provider_master_with_financials[
  provider_backbone_include_v1 == TRUE,
  .(
    providers = .N,
    standard_revenue_use_for_model = sum(standard_revenue_use_for_model_flag, na.rm = TRUE),
    rural_fallback_available = sum(rural_fallback_available_flag, na.rm = TRUE),
    rural_fallback_use_for_model = sum(rural_fallback_use_for_model_flag, na.rm = TRUE),
    children_total_only_fallback_available = sum(children_total_only_fallback_available_flag, na.rm = TRUE),
    children_total_only_fallback_use_for_model = sum(children_total_only_fallback_use_for_model_flag, na.rm = TRUE),
    nonstandard_fallback_candidates = sum(nonstandard_fallback_candidate_flag, na.rm = TRUE),
    nonstandard_fallback_use_for_model = sum(nonstandard_fallback_use_for_model_flag, na.rm = TRUE),
    nonstandard_fallback_failed_plausibility = sum(nonstandard_fallback_failed_plausibility_flag, na.rm = TRUE),
    revenue_use_for_model = sum(revenue_use_for_model_flag, na.rm = TRUE),
    g2_complete = sum(g2_revenue_complete_flag, na.rm = TRUE),
    g3_npr_complete = sum(g3_net_patient_revenue_complete_flag, na.rm = TRUE),
    net_to_gross_plausible = sum(net_to_gross_plausible_flag, na.rm = TRUE),
    gross_sum_check_plausible = sum(gross_sum_check_plausible_flag, na.rm = TRUE)
  )
])

cat("\nRevenue source method by provider class, backbone-included:\n")
print(provider_master_with_financials[
  provider_backbone_include_v1 == TRUE,
  .N,
  by = .(provider_model_class, revenue_source_method)
][order(provider_model_class, -N)])

cat("\nRevenue totals by provider class, backbone-included:\n")
print(provider_master_with_financials[
  provider_backbone_include_v1 == TRUE,
  .(
    providers = .N,
    revenue_use_for_model = sum(revenue_use_for_model_flag, na.rm = TRUE),
    standard_revenue_use_for_model = sum(standard_revenue_use_for_model_flag, na.rm = TRUE),
    rural_fallback_use_for_model = sum(rural_fallback_use_for_model_flag, na.rm = TRUE),
    children_total_only_fallback_use_for_model = sum(children_total_only_fallback_use_for_model_flag, na.rm = TRUE),
    nonstandard_fallback_use_for_model = sum(nonstandard_fallback_use_for_model_flag, na.rm = TRUE),
    gross_inpatient_patient_revenue = sum(gross_inpatient_patient_revenue, na.rm = TRUE),
    gross_outpatient_patient_revenue = sum(gross_outpatient_patient_revenue, na.rm = TRUE),
    gross_total_patient_revenue = sum(gross_total_patient_revenue_model, na.rm = TRUE),
    net_patient_revenue = sum(net_patient_revenue_model, na.rm = TRUE),
    net_outpatient_exposure_base = sum(net_outpatient_exposure_base_model, na.rm = TRUE),
    net_outpatient_exposure_low = sum(net_outpatient_exposure_low_model, na.rm = TRUE),
    net_outpatient_exposure_high = sum(net_outpatient_exposure_high_model, na.rm = TRUE),
    weighted_net_to_gross_ratio =
      sum(net_patient_revenue_model, na.rm = TRUE) /
      sum(gross_total_patient_revenue_model, na.rm = TRUE),
    weighted_outpatient_exposure_share =
      sum(net_outpatient_exposure_base_model, na.rm = TRUE) /
      sum(net_patient_revenue_model, na.rm = TRUE)
  ),
  by = provider_model_class
][order(-providers)])

cat("\nNonstandard fallback detail, backbone-included:\n")
print(provider_master_with_financials[
  provider_backbone_include_v1 == TRUE &
    nonstandard_fallback_use_for_model_flag == TRUE,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    city,
    state_abbrev,
    provider_model_class,
    revenue_source_method,
    gross_total_patient_revenue,
    net_patient_revenue,
    net_to_gross_ratio,
    outpatient_gross_share,
    net_outpatient_exposure_base,
    fallback_total_revenue,
    fallback_crosscheck_ratio,
    nonstandard_fallback_net_to_gross_ratio
  )
][order(state_abbrev, provider_name)][1:120])

cat("\nFallback failed plausibility detail, backbone-included:\n")
print(provider_master_with_financials[
  provider_backbone_include_v1 == TRUE &
    nonstandard_fallback_failed_plausibility_flag == TRUE,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    city,
    state_abbrev,
    provider_model_class,
    gross_total_patient_revenue,
    net_patient_revenue,
    fallback_total_revenue,
    standard_net_patient_revenue,
    fallback_crosscheck_ratio,
    nonstandard_fallback_net_to_gross_ratio,
    revenue_source_method
  )
][order(-nonstandard_fallback_net_to_gross_ratio)])

cat("\nChildren's fallback detail, backbone-included:\n")
print(provider_master_with_financials[
  provider_backbone_include_v1 == TRUE &
    children_total_only_fallback_use_for_model_flag == TRUE,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    city,
    state_abbrev,
    provider_model_class,
    hospital_beds,
    revenue_source_method,
    gross_total_patient_revenue,
    net_patient_revenue,
    net_to_gross_ratio,
    outpatient_gross_share,
    net_outpatient_exposure_base,
    children_fallback_total_revenue,
    children_fallback_net_patient_revenue
  )
][order(state_abbrev, provider_name)])

cat("\nRural primary care detail after fallback:\n")
print(provider_master_with_financials[
  provider_backbone_include_v1 == TRUE &
    provider_model_class == "Rural primary care hospital",
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    city,
    state_abbrev,
    hospital_beds,
    revenue_source_method,
    revenue_use_for_model_flag,
    standard_revenue_use_for_model_flag,
    rural_fallback_use_for_model_flag,
    nonstandard_fallback_use_for_model_flag,
    gross_total_patient_revenue,
    net_patient_revenue,
    net_to_gross_ratio,
    outpatient_gross_share,
    net_outpatient_exposure_base,
    fallback_total_revenue
  )
][order(revenue_source_method, state_abbrev, provider_name)])

cat("\nDistribution of net-to-gross ratio, backbone-included with model revenue:\n")
print(summary(provider_master_with_financials[
  provider_backbone_include_v1 == TRUE &
    revenue_use_for_model_flag == TRUE,
  net_to_gross_ratio
]))

cat("\nDistribution of outpatient gross/exposure share, backbone-included with model revenue:\n")
print(summary(provider_master_with_financials[
  provider_backbone_include_v1 == TRUE &
    revenue_use_for_model_flag == TRUE,
  outpatient_gross_share
]))

cat("\nPotential revenue outliers / checks, backbone-included:\n")

bad_net_to_gross <- provider_master_with_financials[
  provider_backbone_include_v1 == TRUE &
    revenue_use_for_model_flag == TRUE &
    !is.na(net_to_gross_ratio) &
    (net_to_gross_ratio <= fallback_net_to_gross_min | net_to_gross_ratio > fallback_net_to_gross_max),
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    provider_model_class,
    revenue_source_method,
    gross_total_patient_revenue,
    net_patient_revenue,
    net_to_gross_ratio
  )
]

cat("\nModel-used net-to-gross ratio <=0 or >1.5:\n")
if (nrow(bad_net_to_gross) == 0) {
  cat("None\n")
} else {
  print(bad_net_to_gross)
}

bad_gross_sum <- provider_master_with_financials[
  provider_backbone_include_v1 == TRUE &
    standard_revenue_use_for_model_flag == TRUE &
    gross_sum_check_plausible_flag == FALSE,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    provider_model_class,
    revenue_source_method,
    gross_inpatient_patient_revenue,
    gross_outpatient_patient_revenue,
    gross_total_patient_revenue,
    gross_total_minus_inpatient_outpatient
  )
]

cat("\nStandard gross total not approximately inpatient + outpatient:\n")
if (nrow(bad_gross_sum) == 0) {
  cat("None\n")
} else {
  print(bad_gross_sum[1:50])
}

cat("\nSample backbone-included providers with financials:\n")
print(provider_master_with_financials[
  provider_backbone_include_v1 == TRUE,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    city,
    state_abbrev,
    provider_model_class,
    revenue_source_method,
    gross_inpatient_patient_revenue,
    gross_outpatient_patient_revenue,
    gross_total_patient_revenue,
    net_patient_revenue,
    net_to_gross_ratio,
    outpatient_gross_share,
    net_outpatient_exposure_base,
    revenue_use_for_model_flag
  )
][1:30])

cat("\nSaved:\n")
cat(g_fin_rds, "\n")
cat(provider_fin_rds, "\n")
cat(g_fin_csv, "\n")
cat(provider_fin_csv, "\n")
cat(g_profile_csv, "\n")

cat("\n============================================================\n")
```

---

# 08A_diagnose_revenue_failures.R

```r
# Scripts/08A_diagnose_revenue_failures.R
# Diagnose why backbone providers fail G-2/G-3 revenue extraction,
# especially Rural Primary Care Hospitals.
#
# Inputs:
#   Processed/hcris_YYYY_provider_master_with_financials.rds
#   Processed/hcris_YYYY_nmrc.rds
#
# Outputs:
#   Output/hcris_YYYY_revenue_failure_provider_list.csv
#   Output/hcris_YYYY_revenue_failure_g_worksheet_profile.csv
#   Output/hcris_YYYY_revenue_failure_sample_g_long.csv
#   Output/hcris_YYYY_rural_primary_care_revenue_diagnostic.csv

source("Scripts/00_setup.R")

cat("\n============================================================\n")
cat("DIAGNOSE G-2 / G-3 REVENUE FAILURES\n")
cat("============================================================\n")
cat("Build year:", hcris_year_label, "\n\n")

# ============================================================
# 1. Load inputs
# ============================================================

provider_fin_file <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_provider_master_with_financials.rds")
)

nmrc_file <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_nmrc.rds")
)

if (!file.exists(provider_fin_file)) {
  stop("Missing provider financial file: ", provider_fin_file)
}

if (!file.exists(nmrc_file)) {
  stop("Missing NMRC file: ", nmrc_file)
}

provider_fin <- readRDS(provider_fin_file)
nmrc <- readRDS(nmrc_file)

cat("Loaded:\n")
cat(provider_fin_file, "\n")
cat(nmrc_file, "\n")

# ============================================================
# 2. Define failed backbone providers
# ============================================================

failed_revenue <- provider_fin[
  provider_backbone_include_v1 == TRUE &
    revenue_use_for_model_flag == FALSE,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    city,
    state_abbrev,
    provider_model_class,
    facility_type,
    hospital_beds,
    hospital_bed_days_available,
    s10_any_data_flag,
    uncompensated_care_cost,
    gross_inpatient_patient_revenue,
    gross_outpatient_patient_revenue,
    gross_total_patient_revenue,
    net_patient_revenue,
    net_to_gross_ratio,
    g2_revenue_complete_flag,
    g3_net_patient_revenue_complete_flag,
    net_to_gross_plausible_flag,
    revenue_use_for_model_flag
  )
]

cat("\nFailed revenue providers by class:\n")
print(failed_revenue[, .N, by = provider_model_class][order(-N)])

cat("\nFailed revenue provider list:\n")
print(failed_revenue[order(provider_model_class, state_abbrev, provider_name)][1:200])

failure_list_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_revenue_failure_provider_list.csv")
)

data.table::fwrite(failed_revenue, failure_list_csv)

# ============================================================
# 3. Focus specifically on rural primary care hospitals
# ============================================================

rural_primary <- provider_fin[
  provider_backbone_include_v1 == TRUE &
    provider_model_class == "Rural primary care hospital",
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    city,
    state_abbrev,
    facility_type,
    hospital_beds,
    hospital_bed_days_available,
    s10_any_data_flag,
    uncompensated_care_cost,
    gross_inpatient_patient_revenue,
    gross_outpatient_patient_revenue,
    gross_total_patient_revenue,
    net_patient_revenue,
    net_to_gross_ratio,
    g2_revenue_complete_flag,
    g3_net_patient_revenue_complete_flag,
    net_to_gross_plausible_flag,
    revenue_use_for_model_flag
  )
]

cat("\nRural primary care hospital revenue diagnostic:\n")
print(rural_primary[order(revenue_use_for_model_flag, state_abbrev, provider_name)])

rural_diag_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_rural_primary_care_revenue_diagnostic.csv")
)

data.table::fwrite(rural_primary, rural_diag_csv)

# ============================================================
# 4. Pull all G-family worksheet rows for failed providers
# ============================================================

failed_g_long <- nmrc[
  rpt_rec_num %in% failed_revenue$rpt_rec_num &
    stringr::str_detect(wksht_cd, "^G") &
    !is.na(itm_val_num),
  .(
    rpt_rec_num,
    wksht_cd,
    line_num_chr,
    clmn_num_chr,
    itm_val_num
  )
]

failed_g_long <- merge(
  failed_g_long,
  failed_revenue[
    ,
    .(
      rpt_rec_num,
      prvdr_num_chr,
      provider_name,
      city,
      state_abbrev,
      provider_model_class
    )
  ],
  by = "rpt_rec_num",
  all.x = TRUE
)

cat("\nFailed providers with any G-family numeric data:", uniqueN(failed_g_long$rpt_rec_num), "\n")
cat("Failed providers total:", nrow(failed_revenue), "\n")

# ============================================================
# 5. Profile all G-family fields among failed providers
# ============================================================

failed_g_profile <- failed_g_long[
  ,
  .(
    n_rows = .N,
    n_reports = uniqueN(rpt_rec_num),
    nonzero_reports = uniqueN(rpt_rec_num[itm_val_num != 0]),
    min_value = suppressWarnings(min(itm_val_num, na.rm = TRUE)),
    p25_value = suppressWarnings(as.numeric(quantile(itm_val_num, 0.25, na.rm = TRUE))),
    median_value = suppressWarnings(median(itm_val_num, na.rm = TRUE)),
    mean_value = suppressWarnings(mean(itm_val_num, na.rm = TRUE)),
    p75_value = suppressWarnings(as.numeric(quantile(itm_val_num, 0.75, na.rm = TRUE))),
    max_value = suppressWarnings(max(itm_val_num, na.rm = TRUE)),
    total_value = sum(itm_val_num, na.rm = TRUE)
  ),
  by = .(provider_model_class, wksht_cd, line_num_chr, clmn_num_chr)
][order(provider_model_class, wksht_cd, line_num_chr, clmn_num_chr)]

for (cc in c("min_value", "p25_value", "median_value", "mean_value", "p75_value", "max_value")) {
  failed_g_profile[
    is.infinite(get(cc)),
    (cc) := NA_real_
  ]
}

cat("\nFailed-provider G worksheet profile, rural primary care only:\n")
print(failed_g_profile[
  provider_model_class == "Rural primary care hospital"
][1:250])

failed_g_profile_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_revenue_failure_g_worksheet_profile.csv")
)

data.table::fwrite(failed_g_profile, failed_g_profile_csv)

# ============================================================
# 6. Sample long G-family records for failed rural primary care hospitals
# ============================================================

failed_rural_reports <- failed_revenue[
  provider_model_class == "Rural primary care hospital",
  rpt_rec_num
]

sample_failed_rural_reports <- head(failed_rural_reports, 20)

failed_rural_g_sample <- failed_g_long[
  rpt_rec_num %in% sample_failed_rural_reports
][order(rpt_rec_num, wksht_cd, line_num_chr, clmn_num_chr)]

cat("\nSample G-family rows for failed rural primary care hospitals:\n")
print(failed_rural_g_sample[1:500])

sample_g_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_revenue_failure_sample_g_long.csv")
)

data.table::fwrite(failed_rural_g_sample, sample_g_csv)

# ============================================================
# 7. Look for alternative revenue-like fields
# ============================================================

# Heuristic: revenue-like candidates are positive numeric fields in G worksheets
# reported by many failed providers, especially rural primary care hospitals.
rural_alt_candidates <- failed_g_profile[
  provider_model_class == "Rural primary care hospital" &
    n_reports >= 10 &
    median_value > 100000,
  .(
    provider_model_class,
    wksht_cd,
    line_num_chr,
    clmn_num_chr,
    n_reports,
    median_value,
    mean_value,
    total_value,
    min_value,
    max_value
  )
][order(-n_reports, -median_value)]

cat("\nAlternative revenue-like candidate fields for failed rural primary care hospitals:\n")
print(rural_alt_candidates[1:100])

# ============================================================
# 8. Save and finish
# ============================================================

cat("\nSaved:\n")
cat(failure_list_csv, "\n")
cat(rural_diag_csv, "\n")
cat(failed_g_profile_csv, "\n")
cat(sample_g_csv, "\n")

cat("\n============================================================\n")
cat("Revenue failure diagnosis complete.\n")
cat("============================================================\n")
```

---

# 08B_diagnose_childrens_cah_revenue_failures.R

```r
# Scripts/08B_diagnose_childrens_cah_revenue_failures.R
# Diagnose revenue extraction gaps for Children's hospitals and current CAH-labeled providers.
#
# Purpose:
#   Script 08 now includes:
#     - standard G-2/G-3 revenue extraction
#     - rural primary care fallback
#     - children's total-only fallback
#
#   This diagnostic inspects:
#     - remaining children's and CAH-labeled gaps
#     - G-family candidate fields
#     - current CAH-labeled bucket contamination
#
# Inputs:
#   Processed/hcris_YYYY_provider_master_with_financials.rds
#   Processed/hcris_YYYY_nmrc.rds
#
# Outputs:
#   Output/hcris_YYYY_childrens_cah_revenue_gap_provider_list.csv
#   Output/hcris_YYYY_childrens_cah_g_family_profile.csv
#   Output/hcris_YYYY_childrens_cah_alt_revenue_candidates.csv
#   Output/hcris_YYYY_childrens_cah_sample_g_long.csv
#   Output/hcris_YYYY_cah_classification_screen.csv

source("Scripts/00_setup.R")

cat("\n============================================================\n")
cat("DIAGNOSE CHILDREN'S / CAH REVENUE FAILURES\n")
cat("============================================================\n")
cat("Build year:", hcris_year_label, "\n\n")

# ============================================================
# 1. Load inputs
# ============================================================

provider_fin_file <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_provider_master_with_financials.rds")
)

nmrc_file <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_nmrc.rds")
)

if (!file.exists(provider_fin_file)) {
  stop("Missing provider financial file: ", provider_fin_file)
}

if (!file.exists(nmrc_file)) {
  stop("Missing NMRC file: ", nmrc_file)
}

provider_fin <- readRDS(provider_fin_file)
nmrc <- readRDS(nmrc_file)

cat("Loaded:\n")
cat(provider_fin_file, "\n")
cat(nmrc_file, "\n")

# ============================================================
# 2. Define target providers
# ============================================================

target_classes <- c(
  "Children's hospital",
  "Critical access hospital"
)

target_providers <- provider_fin[
  provider_backbone_include_v1 == TRUE &
    provider_model_class %in% target_classes,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    city,
    state_abbrev,
    provider_model_class,
    facility_type,
    hospital_beds,
    hospital_bed_days_available,
    s10_any_data_flag,
    uncompensated_care_cost,
    revenue_source_method,
    revenue_use_for_model_flag,
    standard_revenue_use_for_model_flag,
    rural_fallback_use_for_model_flag,
    children_total_only_fallback_use_for_model_flag,
    gross_inpatient_patient_revenue,
    gross_outpatient_patient_revenue,
    gross_total_patient_revenue,
    net_patient_revenue,
    net_to_gross_ratio,
    outpatient_gross_share,
    net_outpatient_exposure_base,
    g2_revenue_complete_flag,
    g3_net_patient_revenue_complete_flag,
    net_to_gross_plausible_flag,
    gross_sum_check_plausible_flag
  )
]

cat("\nTarget provider counts by class:\n")
print(target_providers[, .N, by = provider_model_class][order(-N)])

cat("\nRevenue source method by target class:\n")
print(target_providers[
  ,
  .N,
  by = .(provider_model_class, revenue_source_method)
][order(provider_model_class, -N)])

# Gap providers:
#   - no model revenue, OR
#   - still only total revenue with no outpatient split and no fallback used.
gap_providers <- target_providers[
  revenue_use_for_model_flag == FALSE |
    revenue_source_method == "g2_total_only_no_outpatient_split"
]

cat("\nRevenue gap providers by class and method:\n")
print(gap_providers[
  ,
  .N,
  by = .(provider_model_class, revenue_source_method)
][order(provider_model_class, -N)])

cat("\nRevenue gap provider list:\n")
print(gap_providers[
  order(provider_model_class, revenue_source_method, state_abbrev, provider_name)
][1:250])

gap_provider_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_childrens_cah_revenue_gap_provider_list.csv")
)

data.table::fwrite(gap_providers, gap_provider_csv)

# ============================================================
# 3. Pull all G-family worksheet rows for target gap providers
# ============================================================

target_g_long <- nmrc[
  rpt_rec_num %in% gap_providers$rpt_rec_num &
    stringr::str_detect(wksht_cd, "^G") &
    !is.na(itm_val_num),
  .(
    rpt_rec_num,
    wksht_cd,
    line_num_chr,
    clmn_num_chr,
    itm_val_num
  )
]

target_g_long <- merge(
  target_g_long,
  gap_providers[
    ,
    .(
      rpt_rec_num,
      prvdr_num_chr,
      provider_name,
      city,
      state_abbrev,
      provider_model_class,
      revenue_source_method,
      hospital_beds,
      gross_total_patient_revenue,
      net_patient_revenue
    )
  ],
  by = "rpt_rec_num",
  all.x = TRUE
)

cat("\nGap providers with any G-family numeric data:", uniqueN(target_g_long$rpt_rec_num), "\n")
cat("Gap providers total:", nrow(gap_providers), "\n")

# ============================================================
# 4. Profile all G-family fields among target gap providers
# ============================================================

target_g_profile <- target_g_long[
  ,
  .(
    n_rows = .N,
    n_reports = uniqueN(rpt_rec_num),
    nonzero_reports = uniqueN(rpt_rec_num[itm_val_num != 0]),
    min_value = suppressWarnings(min(itm_val_num, na.rm = TRUE)),
    p25_value = suppressWarnings(as.numeric(quantile(itm_val_num, 0.25, na.rm = TRUE))),
    median_value = suppressWarnings(median(itm_val_num, na.rm = TRUE)),
    mean_value = suppressWarnings(mean(itm_val_num, na.rm = TRUE)),
    p75_value = suppressWarnings(as.numeric(quantile(itm_val_num, 0.75, na.rm = TRUE))),
    max_value = suppressWarnings(max(itm_val_num, na.rm = TRUE)),
    total_value = sum(itm_val_num, na.rm = TRUE)
  ),
  by = .(provider_model_class, revenue_source_method, wksht_cd, line_num_chr, clmn_num_chr)
][order(provider_model_class, revenue_source_method, wksht_cd, line_num_chr, clmn_num_chr)]

for (cc in c("min_value", "p25_value", "median_value", "mean_value", "p75_value", "max_value")) {
  target_g_profile[
    is.infinite(get(cc)),
    (cc) := NA_real_
  ]
}

profile_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_childrens_cah_g_family_profile.csv")
)

data.table::fwrite(target_g_profile, profile_csv)

cat("\nG-family profile for Children's gap providers:\n")
print(target_g_profile[
  provider_model_class == "Children's hospital"
][1:250])

cat("\nG-family profile for CAH-labeled gap providers:\n")
print(target_g_profile[
  provider_model_class == "Critical access hospital"
][1:250])

# ============================================================
# 5. Alternative revenue-like candidate fields
# ============================================================

alt_candidates <- target_g_profile[
  n_reports >= 3 &
    median_value > 100000,
  .(
    provider_model_class,
    revenue_source_method,
    wksht_cd,
    line_num_chr,
    clmn_num_chr,
    n_reports,
    median_value,
    mean_value,
    total_value,
    min_value,
    max_value
  )
][order(provider_model_class, revenue_source_method, -n_reports, -median_value)]

cat("\nAlternative revenue-like candidate fields:\n")
print(alt_candidates[1:300])

alt_candidate_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_childrens_cah_alt_revenue_candidates.csv")
)

data.table::fwrite(alt_candidates, alt_candidate_csv)

# ============================================================
# 6. Sample long rows for manual inspection
# ============================================================

if (nrow(gap_providers) > 0) {
  sample_gap_reports <- gap_providers[
    ,
    head(.SD, 10),
    by = .(provider_model_class, revenue_source_method)
  ]$rpt_rec_num
  
  sample_g_long <- target_g_long[
    rpt_rec_num %in% sample_gap_reports
  ][order(provider_model_class, revenue_source_method, rpt_rec_num, wksht_cd, line_num_chr, clmn_num_chr)]
} else {
  sample_g_long <- data.table::data.table()
}

cat("\nSample G-family rows for target gap providers:\n")
print(sample_g_long[1:700])

sample_g_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_childrens_cah_sample_g_long.csv")
)

data.table::fwrite(sample_g_long, sample_g_csv)

# ============================================================
# 7. CAH classification screen
# ============================================================

# This does NOT determine true CAH status. It screens the current CAH-labeled
# bucket for records that should not be treated as safe CAH/rural stabilization
# candidates without external CMS validation.

cah_screen <- provider_fin[
  provider_backbone_include_v1 == TRUE &
    provider_model_class == "Critical access hospital",
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    city,
    state_abbrev,
    provider_model_class,
    facility_type,
    hospital_beds,
    hospital_bed_days_available,
    revenue_source_method,
    revenue_use_for_model_flag,
    gross_total_patient_revenue,
    net_patient_revenue,
    net_outpatient_exposure_base,
    s10_any_data_flag,
    uncompensated_care_cost
  )
]

cah_screen[
  ,
  name_academic_flag :=
    stringr::str_detect(
      stringr::str_to_upper(provider_name),
      paste(
        c(
          "UNIVERSITY",
          "UCSF",
          "UCLA",
          "UCSD",
          "UC DAVIS",
          "UCI",
          "MD ANDERSON",
          "MEDICAL UNIVERSITY",
          "UT SOUTHWESTERN",
          "OHIO STATE",
          "STONY BROOK",
          "DENVER HEALTH",
          "WASHINGTON MED",
          "IOWA HEALTH",
          "ALABAMA HOSPITAL",
          "MAYO",
          "CANCER CENTER",
          "MEDICAL CENTER AT THE UNI"
        ),
        collapse = "|"
      )
    )
]

cah_screen[
  ,
  name_psych_behavioral_flag :=
    stringr::str_detect(
      stringr::str_to_upper(provider_name),
      paste(
        c(
          "PSYCH",
          "BEHAVIOR",
          "MENTAL",
          "STATE HOSPITAL",
          "RECOVERY",
          "FORENSIC",
          "HOSPITAL CENTER",
          "REGIONAL HOSPITAL"
        ),
        collapse = "|"
      )
    )
]

cah_screen[
  ,
  name_childrens_flag :=
    stringr::str_detect(
      stringr::str_to_upper(provider_name),
      "CHILD|CHILDREN|PEDIATRIC"
    )
]

cah_screen[
  ,
  cah_bed_red_flag :=
    !is.na(hospital_beds) &
    hospital_beds > 25
]

cah_screen[
  ,
  cah_revenue_red_flag :=
    !is.na(gross_total_patient_revenue) &
    gross_total_patient_revenue > 250000000
]

cah_screen[
  ,
  cah_size_red_flag :=
    cah_bed_red_flag | cah_revenue_red_flag
]

cah_screen[
  ,
  cah_safe_for_stabilization_without_external_validation :=
    provider_model_class == "Critical access hospital" &
    !name_academic_flag &
    !name_psych_behavioral_flag &
    !name_childrens_flag &
    !cah_size_red_flag
]

cat("\nCAH classification screen summary:\n")
print(cah_screen[
  ,
  .(
    providers = .N,
    academic_name_flags = sum(name_academic_flag, na.rm = TRUE),
    psych_behavioral_name_flags = sum(name_psych_behavioral_flag, na.rm = TRUE),
    childrens_name_flags = sum(name_childrens_flag, na.rm = TRUE),
    bed_red_flags = sum(cah_bed_red_flag, na.rm = TRUE),
    revenue_red_flags = sum(cah_revenue_red_flag, na.rm = TRUE),
    size_red_flags = sum(cah_size_red_flag, na.rm = TRUE),
    safe_without_external_validation =
      sum(cah_safe_for_stabilization_without_external_validation, na.rm = TRUE)
  )
])

cat("\nCAH classification screen by revenue source method:\n")
print(cah_screen[
  ,
  .(
    providers = .N,
    academic_name_flags = sum(name_academic_flag, na.rm = TRUE),
    psych_behavioral_name_flags = sum(name_psych_behavioral_flag, na.rm = TRUE),
    childrens_name_flags = sum(name_childrens_flag, na.rm = TRUE),
    bed_red_flags = sum(cah_bed_red_flag, na.rm = TRUE),
    revenue_red_flags = sum(cah_revenue_red_flag, na.rm = TRUE),
    safe_without_external_validation =
      sum(cah_safe_for_stabilization_without_external_validation, na.rm = TRUE)
  ),
  by = revenue_source_method
][order(-providers)])

cat("\nLargest CAH-labeled records by gross total revenue:\n")
print(cah_screen[
  order(-gross_total_patient_revenue)
][1:75])

cat("\nCAH-labeled records that look safer as CAH candidates by internal screen:\n")
print(cah_screen[
  cah_safe_for_stabilization_without_external_validation == TRUE
][order(state_abbrev, provider_name)][1:100])

cah_screen_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_cah_classification_screen.csv")
)

data.table::fwrite(cah_screen, cah_screen_csv)

# ============================================================
# 8. Save and finish
# ============================================================

cat("\nSaved:\n")
cat(gap_provider_csv, "\n")
cat(profile_csv, "\n")
cat(alt_candidate_csv, "\n")
cat(sample_g_csv, "\n")
cat(cah_screen_csv, "\n")

cat("\n============================================================\n")
cat("Children's / CAH revenue diagnosis complete.\n")
cat("============================================================\n")
```

---

# 09_validate_provider_classification.R

```r
# Scripts/09_validate_provider_classification.R
# Validate and clean provider classification for the UCC/HSE provider-impact model.
#
# Purpose:
#   The raw FY2024 provider_model_class is useful but not safe for policy scoring
#   because the "Critical access hospital" bucket is contaminated with large
#   academic medical centers, psych/behavioral hospitals, specialty hospitals,
#   and other non-CAH entities.
#
# Inputs:
#   Processed/hcris_YYYY_provider_master_with_financials.rds
#
# Outputs:
#   Processed/hcris_YYYY_provider_master_classified.rds
#   Output/hcris_YYYY_provider_master_classified.csv
#   Output/hcris_YYYY_provider_classification_summary.csv
#   Output/hcris_YYYY_provider_classification_review_list.csv
#   Output/hcris_YYYY_cah_internal_validation_list.csv
#
# Notes:
#   This script does NOT claim to prove true CMS CAH status.
#   It creates an internal classification layer for model safety.
#
#   External CMS CAH/rural identifiers can be merged later.
#
# Key fields created:
#   raw_provider_model_class
#   clean_provider_model_class
#   clean_provider_group
#   academic_major_medical_center_flag
#   psych_behavioral_flag
#   rehab_ltach_specialty_flag
#   children_name_flag
#   rural_primary_or_ihs_flag
#   cah_safe_without_external_validation_flag
#   stabilization_eligible_internal_flag
#   classification_needs_external_validation_flag

source("Scripts/00_setup.R")

cat("\n============================================================\n")
cat("VALIDATE PROVIDER CLASSIFICATION\n")
cat("============================================================\n")
cat("Build year:", hcris_year_label, "\n\n")

# ============================================================
# 1. Load input
# ============================================================

provider_fin_file <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_provider_master_with_financials.rds")
)

if (!file.exists(provider_fin_file)) {
  stop("Missing provider financial file: ", provider_fin_file)
}

provider_fin <- readRDS(provider_fin_file)

cat("Loaded:\n")
cat(provider_fin_file, "\n")

cat("\nProvider rows:", nrow(provider_fin), "\n")

# ============================================================
# 2. Safety checks
# ============================================================

required_cols <- c(
  "rpt_rec_num",
  "prvdr_num_chr",
  "provider_name",
  "city",
  "state_abbrev",
  "facility_type",
  "provider_model_class",
  "provider_backbone_include_v1",
  "hospital_beds",
  "gross_total_patient_revenue",
  "net_patient_revenue",
  "net_outpatient_exposure_base",
  "revenue_source_method",
  "revenue_use_for_model_flag",
  "s10_any_data_flag",
  "uncompensated_care_cost"
)

missing_cols <- setdiff(required_cols, names(provider_fin))

if (length(missing_cols) > 0) {
  stop(
    "Provider financial file missing required columns:\n",
    paste(missing_cols, collapse = "\n")
  )
}

# ============================================================
# 3. Preserve raw class
# ============================================================

classified <- copy(provider_fin)

classified[
  ,
  raw_provider_model_class := provider_model_class
]

classified[
  ,
  provider_name_upper := stringr::str_to_upper(provider_name)
]

classified[
  ,
  facility_type_upper := stringr::str_to_upper(facility_type)
]

# ============================================================
# 4. Name / facility-type classification flags
# ============================================================

classified[
  ,
  academic_major_medical_center_flag :=
    stringr::str_detect(
      provider_name_upper,
      paste(
        c(
          "UNIVERSITY",
          "UCSF",
          "UCLA",
          "UCSD",
          "UC DAVIS",
          "UCI",
          "MD ANDERSON",
          "UT SOUTHWESTERN",
          "OHIO STATE",
          "STONY BROOK",
          "DENVER HEALTH",
          "WASHINGTON MED",
          "UNIVERSITY OF WASHINGTON",
          "IOWA HEALTH",
          "UNIVERSITY OF IOWA",
          "ALABAMA HOSPITAL",
          "UNIVERSITY OF ALABAMA",
          "MEDICAL UNIVERSITY",
          "U OF U",
          "UAMS",
          "UT HEALTH",
          "UTMB",
          "MAYO",
          "CANCER CENTER",
          "CANCER INSTITUTE",
          "BOARD OF TRUSTEES OF THE UNIVERSITY"
        ),
        collapse = "|"
      )
    )
]

classified[
  ,
  psych_behavioral_flag :=
    stringr::str_detect(
      provider_name_upper,
      paste(
        c(
          "PSYCH",
          "BEHAVIOR",
          "BEHAVIORAL",
          "MENTAL",
          "STATE HOSPITAL",
          "FORENSIC",
          "RECOVERY",
          "SANCTUARY",
          "GATEWAYS",
          "WILLOW ROCK",
          "CBHH",
          "P\\.I\\.",
          "P I",
          "CENTER FOR COGNITIVE",
          "HARMON HOSPITAL"
        ),
        collapse = "|"
      )
    ) |
    stringr::str_detect(
      facility_type_upper,
      "PSYCHIATRIC"
    )
]

classified[
  ,
  rehab_ltach_specialty_flag :=
    stringr::str_detect(
      provider_name_upper,
      paste(
        c(
          "REHAB",
          "REHABILITATION",
          "VIBRA",
          "RESTORATIVE",
          "SPECIALTY",
          "LTCH",
          "LONG TERM",
          "LONG-TERM",
          "SURGICAL",
          "ORTHOPAEDIC",
          "ORTHOPEDIC",
          "ADVANCED CARE",
          "REUNION",
          "ENCOMPASS",
          "WARM SPRINGS",
          "HELEN HAYES"
        ),
        collapse = "|"
      )
    ) |
    stringr::str_detect(
      facility_type_upper,
      "REHABILITATION|LONG-TERM|LONG TERM"
    )
]

classified[
  ,
  children_name_flag :=
    stringr::str_detect(
      provider_name_upper,
      "CHILD|CHILDREN|PEDIATRIC|SHRINERS"
    ) |
    stringr::str_detect(
      facility_type_upper,
      "CHILDREN"
    )
]

classified[
  ,
  rural_primary_or_ihs_flag :=
    raw_provider_model_class == "Rural primary care hospital" |
    stringr::str_detect(
      provider_name_upper,
      paste(
        c(
          "INDIAN",
          "IHS",
          "USPHS",
          "PHS HOSPITAL",
          "NATIVE",
          "NAVAJO",
          "APACHE",
          "CHOCTAW",
          "CHEROKEE",
          "CHICKASAW",
          "BLACKFEET",
          "CROW",
          "NORTHERN CHEYENNE",
          "PINE RIDGE",
          "ROSEBUD",
          "EAGLE BUTTE",
          "TUBA CITY",
          "GALLUP INDIAN",
          "FORT DEFIANCE",
          "WHITERIVER",
          "ZUNI",
          "HOPI",
          "SELLS HOSPITAL",
          "RED LAKE",
          "CASS LAKE",
          "BELKNAP",
          "BROWNING",
          "WINNEBAGO"
        ),
        collapse = "|"
      )
    )
]

classified[
  ,
  apparent_general_acute_name_flag :=
    stringr::str_detect(
      provider_name_upper,
      paste(
        c(
          "MEDICAL CENTER",
          "HOSPITAL",
          "HEALTH CENTER",
          "REGIONAL",
          "MEMORIAL",
          "COMMUNITY",
          "SAINT",
          "ST\\.",
          "BAPTIST",
          "MERCY",
          "ADVENT",
          "PROVIDENCE",
          "METHODIST"
        ),
        collapse = "|"
      )
    ) &
    !psych_behavioral_flag &
    !rehab_ltach_specialty_flag &
    !children_name_flag
]

# ============================================================
# 5. Size / revenue red flags
# ============================================================

classified[
  ,
  small_cah_bed_flag :=
    !is.na(hospital_beds) &
    hospital_beds <= 25
]

classified[
  ,
  large_bed_red_flag :=
    !is.na(hospital_beds) &
    hospital_beds > 25
]

classified[
  ,
  very_large_bed_red_flag :=
    !is.na(hospital_beds) &
    hospital_beds >= 100
]

classified[
  ,
  large_revenue_red_flag :=
    !is.na(gross_total_patient_revenue) &
    gross_total_patient_revenue > 250000000
]

classified[
  ,
  very_large_revenue_red_flag :=
    !is.na(gross_total_patient_revenue) &
    gross_total_patient_revenue > 1000000000
]

classified[
  ,
  cah_internal_red_flag :=
    raw_provider_model_class == "Critical access hospital" &
    (
      large_bed_red_flag |
        large_revenue_red_flag |
        academic_major_medical_center_flag |
        psych_behavioral_flag |
        rehab_ltach_specialty_flag |
        children_name_flag
    )
]

# ============================================================
# 6. CAH-safe internal flag
# ============================================================

classified[
  ,
  cah_safe_without_external_validation_flag :=
    raw_provider_model_class == "Critical access hospital" &
    small_cah_bed_flag == TRUE &
    large_revenue_red_flag == FALSE &
    academic_major_medical_center_flag == FALSE &
    psych_behavioral_flag == FALSE &
    rehab_ltach_specialty_flag == FALSE &
    children_name_flag == FALSE
]

# ============================================================
# 7. Clean provider model class
# ============================================================

classified[
  ,
  clean_provider_model_class := data.table::fcase(
    # Keep rural/IHS-like providers distinct.
    rural_primary_or_ihs_flag == TRUE,
    "Rural primary care / IHS-like hospital",
    
    # Identify true/safe CAH candidates only when internally safe.
    cah_safe_without_external_validation_flag == TRUE,
    "CAH candidate - internally safe",
    
    # Children first if raw/facility/name indicates pediatric.
    raw_provider_model_class == "Children's hospital" | children_name_flag == TRUE,
    "Children's / pediatric hospital",
    
    # Psych/behavioral and rehab/specialty are not general acute.
    psych_behavioral_flag == TRUE,
    "Psychiatric / behavioral hospital",
    
    rehab_ltach_specialty_flag == TRUE,
    "Rehab / LTCH / specialty hospital",
    
    # Large academic or large CAH-labeled records are general/academic hospitals.
    academic_major_medical_center_flag == TRUE,
    "Academic / major medical center",
    
    raw_provider_model_class == "Critical access hospital" &
      cah_internal_red_flag == TRUE &
      very_large_revenue_red_flag == TRUE,
    "Large hospital misclassified as CAH",
    
    raw_provider_model_class == "Critical access hospital" &
      cah_internal_red_flag == TRUE &
      very_large_bed_red_flag == TRUE,
    "Large hospital misclassified as CAH",
    
    raw_provider_model_class == "Critical access hospital" &
      cah_internal_red_flag == TRUE,
    "Non-CAH specialty/other in CAH bucket",
    
    raw_provider_model_class == "Short-term acute/general hospital",
    "Short-term acute/general hospital",
    
    default = "Unknown / needs review"
  )
]

# ============================================================
# 8. Clean provider group for scoring
# ============================================================

classified[
  ,
  clean_provider_group := data.table::fcase(
    clean_provider_model_class %in% c(
      "Short-term acute/general hospital",
      "Academic / major medical center",
      "Large hospital misclassified as CAH"
    ),
    "General acute / academic",
    
    clean_provider_model_class == "Children's / pediatric hospital",
    "Children's / pediatric",
    
    clean_provider_model_class %in% c(
      "Rural primary care / IHS-like hospital",
      "CAH candidate - internally safe"
    ),
    "Rural / CAH / IHS",
    
    clean_provider_model_class %in% c(
      "Psychiatric / behavioral hospital",
      "Rehab / LTCH / specialty hospital",
      "Non-CAH specialty/other in CAH bucket"
    ),
    "Specialty / behavioral / rehab",
    
    default = "Unknown / needs review"
  )
]

# ============================================================
# 9. Stabilization eligibility flags
# ============================================================

classified[
  ,
  safety_net_financial_stress_flag :=
    (
      !is.na(uncompensated_care_cost) &
        uncompensated_care_cost > 0
    ) |
    s10_any_data_flag == TRUE
]

classified[
  ,
  stabilization_eligible_internal_flag :=
    clean_provider_group %in% c(
      "Rural / CAH / IHS",
      "Children's / pediatric"
    ) |
    (
      clean_provider_group == "General acute / academic" &
        safety_net_financial_stress_flag == TRUE
    )
]

classified[
  ,
  rural_cah_ihs_stabilization_candidate_flag :=
    clean_provider_group == "Rural / CAH / IHS"
]

classified[
  ,
  children_stabilization_candidate_flag :=
    clean_provider_group == "Children's / pediatric"
]

classified[
  ,
  safety_net_stabilization_candidate_flag :=
    clean_provider_group == "General acute / academic" &
    safety_net_financial_stress_flag == TRUE
]

classified[
  ,
  classification_needs_external_validation_flag :=
    provider_backbone_include_v1 == TRUE &
    (
      clean_provider_model_class == "Unknown / needs review" |
        raw_provider_model_class == "Critical access hospital"
    )
]

# ============================================================
# 10. Review severity field
# ============================================================

classified[
  ,
  classification_review_priority := data.table::fcase(
    provider_backbone_include_v1 == TRUE &
      raw_provider_model_class == "Critical access hospital" &
      very_large_revenue_red_flag == TRUE,
    "High - CAH label with >$1B gross revenue",
    
    provider_backbone_include_v1 == TRUE &
      raw_provider_model_class == "Critical access hospital" &
      very_large_bed_red_flag == TRUE,
    "High - CAH label with >=100 beds",
    
    provider_backbone_include_v1 == TRUE &
      raw_provider_model_class == "Critical access hospital" &
      cah_internal_red_flag == TRUE,
    "Medium - CAH label with internal red flag",
    
    provider_backbone_include_v1 == TRUE &
      clean_provider_model_class == "Unknown / needs review",
    "Medium - unknown class",
    
    provider_backbone_include_v1 == TRUE &
      cah_safe_without_external_validation_flag == TRUE,
    "Low - internally safe CAH candidate",
    
    default = "No immediate review flag"
  )
]

# ============================================================
# 11. Save outputs
# ============================================================

classified_rds <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_provider_master_classified.rds")
)

classified_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_provider_master_classified.csv")
)

classification_summary_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_provider_classification_summary.csv")
)

classification_review_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_provider_classification_review_list.csv")
)

cah_internal_validation_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_cah_internal_validation_list.csv")
)

saveRDS(classified, classified_rds)
data.table::fwrite(classified, classified_csv)

classification_summary <- classified[
  provider_backbone_include_v1 == TRUE,
  .(
    providers = .N,
    revenue_use_for_model = sum(revenue_use_for_model_flag, na.rm = TRUE),
    total_beds = sum(hospital_beds, na.rm = TRUE),
    gross_total_patient_revenue = sum(gross_total_patient_revenue_model, na.rm = TRUE),
    net_patient_revenue = sum(net_patient_revenue_model, na.rm = TRUE),
    net_outpatient_exposure_base = sum(net_outpatient_exposure_base_model, na.rm = TRUE),
    uncompensated_care_cost = sum(uncompensated_care_cost_model, na.rm = TRUE),
    stabilization_eligible_internal =
      sum(stabilization_eligible_internal_flag, na.rm = TRUE)
  ),
  by = .(
    raw_provider_model_class,
    clean_provider_model_class,
    clean_provider_group
  )
][order(clean_provider_group, clean_provider_model_class, raw_provider_model_class)]

data.table::fwrite(classification_summary, classification_summary_csv)

classification_review <- classified[
  provider_backbone_include_v1 == TRUE &
    classification_review_priority != "No immediate review flag",
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    city,
    state_abbrev,
    raw_provider_model_class,
    facility_type,
    clean_provider_model_class,
    clean_provider_group,
    classification_review_priority,
    hospital_beds,
    gross_total_patient_revenue,
    net_patient_revenue,
    net_outpatient_exposure_base,
    revenue_source_method,
    revenue_use_for_model_flag,
    s10_any_data_flag,
    uncompensated_care_cost,
    academic_major_medical_center_flag,
    psych_behavioral_flag,
    rehab_ltach_specialty_flag,
    children_name_flag,
    rural_primary_or_ihs_flag,
    cah_safe_without_external_validation_flag,
    stabilization_eligible_internal_flag
  )
][order(classification_review_priority, -gross_total_patient_revenue)]

data.table::fwrite(classification_review, classification_review_csv)

cah_internal_validation <- classified[
  provider_backbone_include_v1 == TRUE &
    raw_provider_model_class == "Critical access hospital",
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    city,
    state_abbrev,
    facility_type,
    clean_provider_model_class,
    clean_provider_group,
    classification_review_priority,
    hospital_beds,
    gross_total_patient_revenue,
    net_patient_revenue,
    net_outpatient_exposure_base,
    revenue_source_method,
    revenue_use_for_model_flag,
    s10_any_data_flag,
    uncompensated_care_cost,
    academic_major_medical_center_flag,
    psych_behavioral_flag,
    rehab_ltach_specialty_flag,
    children_name_flag,
    rural_primary_or_ihs_flag,
    large_bed_red_flag,
    very_large_bed_red_flag,
    large_revenue_red_flag,
    very_large_revenue_red_flag,
    cah_internal_red_flag,
    cah_safe_without_external_validation_flag,
    stabilization_eligible_internal_flag
  )
][order(clean_provider_group, clean_provider_model_class, -gross_total_patient_revenue)]

data.table::fwrite(cah_internal_validation, cah_internal_validation_csv)

# ============================================================
# 12. Print summaries
# ============================================================

cat("\n============================================================\n")
cat("PROVIDER CLASSIFICATION VALIDATION COMPLETE\n")
cat("============================================================\n")

cat("\nBackbone raw provider classes:\n")
print(classified[
  provider_backbone_include_v1 == TRUE,
  .N,
  by = raw_provider_model_class
][order(-N)])

cat("\nBackbone clean provider model classes:\n")
print(classified[
  provider_backbone_include_v1 == TRUE,
  .N,
  by = clean_provider_model_class
][order(-N)])

cat("\nBackbone clean provider groups:\n")
print(classified[
  provider_backbone_include_v1 == TRUE,
  .N,
  by = clean_provider_group
][order(-N)])

cat("\nClassification summary by raw class / clean class / clean group:\n")
print(classification_summary)

cat("\nCAH internal validation summary:\n")
print(classified[
  provider_backbone_include_v1 == TRUE &
    raw_provider_model_class == "Critical access hospital",
  .(
    providers = .N,
    academic_major_medical_center = sum(academic_major_medical_center_flag, na.rm = TRUE),
    psych_behavioral = sum(psych_behavioral_flag, na.rm = TRUE),
    rehab_ltach_specialty = sum(rehab_ltach_specialty_flag, na.rm = TRUE),
    children_name = sum(children_name_flag, na.rm = TRUE),
    large_bed_red = sum(large_bed_red_flag, na.rm = TRUE),
    very_large_bed_red = sum(very_large_bed_red_flag, na.rm = TRUE),
    large_revenue_red = sum(large_revenue_red_flag, na.rm = TRUE),
    very_large_revenue_red = sum(very_large_revenue_red_flag, na.rm = TRUE),
    cah_internal_red = sum(cah_internal_red_flag, na.rm = TRUE),
    cah_safe_without_external_validation =
      sum(cah_safe_without_external_validation_flag, na.rm = TRUE)
  )
])

cat("\nCAH clean classes:\n")
print(classified[
  provider_backbone_include_v1 == TRUE &
    raw_provider_model_class == "Critical access hospital",
  .N,
  by = clean_provider_model_class
][order(-N)])

cat("\nCAH clean groups:\n")
print(classified[
  provider_backbone_include_v1 == TRUE &
    raw_provider_model_class == "Critical access hospital",
  .N,
  by = clean_provider_group
][order(-N)])

cat("\nStabilization eligibility internal flags:\n")
print(classified[
  provider_backbone_include_v1 == TRUE,
  .(
    providers = .N,
    stabilization_eligible_internal =
      sum(stabilization_eligible_internal_flag, na.rm = TRUE),
    rural_cah_ihs =
      sum(rural_cah_ihs_stabilization_candidate_flag, na.rm = TRUE),
    children =
      sum(children_stabilization_candidate_flag, na.rm = TRUE),
    safety_net =
      sum(safety_net_stabilization_candidate_flag, na.rm = TRUE),
    needs_external_validation =
      sum(classification_needs_external_validation_flag, na.rm = TRUE)
  )
])

cat("\nTop CAH-labeled records needing review:\n")
print(cah_internal_validation[
  classification_review_priority != "Low - internally safe CAH candidate"
][1:75])

cat("\nInternally safe CAH candidates:\n")
print(cah_internal_validation[
  cah_safe_without_external_validation_flag == TRUE
][order(state_abbrev, provider_name)])

cat("\nSaved:\n")
cat(classified_rds, "\n")
cat(classified_csv, "\n")
cat(classification_summary_csv, "\n")
cat(classification_review_csv, "\n")
cat(cah_internal_validation_csv, "\n")

cat("\n============================================================\n")
```

---

# 10_create_stabilization_eligibility.R

```r
# Scripts/10_create_stabilization_eligibility.R
# Create bounded, formula-based stabilization eligibility metrics for UCC/HSE
# provider-impact scoring.
#
# Purpose:
#   Script 09 created a defensible clean provider classification layer.
#   This script turns that classification into a bounded stabilization layer.
#
# Important correction:
#   This version DOES NOT use provisional operating-margin fields to assign
#   final stabilization tiers.
#
#   Operating margin fields are retained as diagnostic variables only because
#   G-3 line 4 / line 5 interpretation has not yet been fully validated.
#
# Inputs:
#   Processed/hcris_YYYY_provider_master_classified.rds
#
# Outputs:
#   Processed/hcris_YYYY_provider_master_with_stabilization.rds
#   Output/hcris_YYYY_provider_master_with_stabilization.csv
#   Output/hcris_YYYY_stabilization_summary.csv
#   Output/hcris_YYYY_stabilization_tier_review_list.csv
#
# Core principle:
#   Stabilization is NOT an open-ended provider bailout.
#   It is a temporary, bounded transition protection layer for:
#     1. Rural / CAH / IHS providers
#     2. Children's / pediatric hospitals
#     3. High uncompensated-care safety-net hospitals
#
# Stabilization is driven by:
#   - clean provider class
#   - uncompensated-care burden
#   - within-group UC burden rank
#
# Stabilization is NOT currently driven by:
#   - provisional operating-margin candidate
#
# Stabilization tiers:
#   Tier 0: Not eligible
#   Tier 1: Monitoring / low support
#   Tier 2: Moderate transition support
#   Tier 3: High transition support
#   Tier 4: Critical transition support
#
# Default annual support cap rates:
#   Tier 1: 0.5% of net patient revenue
#   Tier 2: 1.0% of net patient revenue
#   Tier 3: 2.0% of net patient revenue
#   Tier 4: 3.0% of net patient revenue
#
# These are modeling caps, not final policy recommendations.

source("Scripts/00_setup.R")

cat("\n============================================================\n")
cat("CREATE STABILIZATION ELIGIBILITY METRICS\n")
cat("============================================================\n")
cat("Build year:", hcris_year_label, "\n\n")

# ============================================================
# 0. Stabilization assumptions
# ============================================================

# UC burden thresholds.
# Ratio is generally uncompensated_care_cost / net_patient_revenue.
uc_burden_tier1_threshold <- 0.02
uc_burden_tier2_threshold <- 0.05
uc_burden_tier3_threshold <- 0.10
uc_burden_tier4_threshold <- 0.15

# Tier support cap rates.
tier1_support_cap_rate <- 0.005
tier2_support_cap_rate <- 0.010
tier3_support_cap_rate <- 0.020
tier4_support_cap_rate <- 0.030

# Baseline protected-class tiers.
# These are transition-protection floors, not automatic high-tier support.
rural_cah_ihs_min_tier <- 2L
children_min_tier <- 2L

# General acute / academic hospitals only qualify through UC burden,
# not simply because they have any S-10 data.
general_acute_min_tier <- 0L

# Specialty / behavioral / rehab providers are not automatically eligible
# in the base stabilization program unless UC burden triggers support.
specialty_min_tier <- 0L

# For top-rank burden triggers:
# Top quartile gets Tier 1 only if UC burden is positive.
# Top decile gets Tier 2 only if UC burden is positive.
use_within_group_percentile_triggers <- TRUE

# ============================================================
# 1. Load input
# ============================================================

classified_file <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_provider_master_classified.rds")
)

if (!file.exists(classified_file)) {
  stop("Missing classified provider file: ", classified_file)
}

dt <- readRDS(classified_file)

cat("Loaded:\n")
cat(classified_file, "\n")
cat("\nRows:", nrow(dt), "\n")

# ============================================================
# 2. Safety checks
# ============================================================

required_cols <- c(
  "rpt_rec_num",
  "prvdr_num_chr",
  "provider_name",
  "city",
  "state_abbrev",
  "provider_backbone_include_v1",
  "raw_provider_model_class",
  "clean_provider_model_class",
  "clean_provider_group",
  "hospital_beds",
  "gross_total_patient_revenue_model",
  "net_patient_revenue_model",
  "net_outpatient_exposure_base_model",
  "uncompensated_care_cost_model",
  "revenue_use_for_model_flag",
  "s10_use_for_model_flag",
  "classification_needs_external_validation_flag",
  "g3_line_00400_c001",
  "g3_line_00500_c001"
)

missing_cols <- setdiff(required_cols, names(dt))

if (length(missing_cols) > 0) {
  stop(
    "Classified provider file missing required columns:\n",
    paste(missing_cols, collapse = "\n")
  )
}

stab <- copy(dt)

# ============================================================
# 3. Core denominator fields
# ============================================================

stab[
  ,
  stabilization_revenue_base :=
    data.table::fcase(
      !is.na(net_patient_revenue_model) & net_patient_revenue_model > 0,
      net_patient_revenue_model,
      
      !is.na(gross_total_patient_revenue_model) & gross_total_patient_revenue_model > 0,
      gross_total_patient_revenue_model,
      
      default = NA_real_
    )
]

stab[
  ,
  stabilization_revenue_base_source := data.table::fcase(
    !is.na(net_patient_revenue_model) & net_patient_revenue_model > 0,
    "net_patient_revenue_model",
    
    !is.na(gross_total_patient_revenue_model) & gross_total_patient_revenue_model > 0,
    "gross_total_patient_revenue_model",
    
    default = "missing"
  )
]

stab[
  ,
  stabilization_revenue_base_available_flag :=
    !is.na(stabilization_revenue_base) &
    stabilization_revenue_base > 0
]

# ============================================================
# 4. UC burden metrics
# ============================================================

stab[
  ,
  uc_to_net_patient_revenue_ratio :=
    data.table::fifelse(
      !is.na(uncompensated_care_cost_model) &
        uncompensated_care_cost_model >= 0 &
        !is.na(net_patient_revenue_model) &
        net_patient_revenue_model > 0,
      uncompensated_care_cost_model / net_patient_revenue_model,
      NA_real_
    )
]

stab[
  ,
  uc_to_gross_revenue_ratio :=
    data.table::fifelse(
      !is.na(uncompensated_care_cost_model) &
        uncompensated_care_cost_model >= 0 &
        !is.na(gross_total_patient_revenue_model) &
        gross_total_patient_revenue_model > 0,
      uncompensated_care_cost_model / gross_total_patient_revenue_model,
      NA_real_
    )
]

stab[
  ,
  uc_burden_ratio_for_tiering :=
    data.table::fcase(
      !is.na(uc_to_net_patient_revenue_ratio),
      uc_to_net_patient_revenue_ratio,
      
      !is.na(uc_to_gross_revenue_ratio),
      uc_to_gross_revenue_ratio,
      
      default = NA_real_
    )
]

stab[
  ,
  uc_burden_available_flag :=
    !is.na(uc_burden_ratio_for_tiering)
]

stab[
  ,
  uc_burden_tier := data.table::fcase(
    uc_burden_available_flag == FALSE,
    0L,
    
    uc_burden_ratio_for_tiering >= uc_burden_tier4_threshold,
    4L,
    
    uc_burden_ratio_for_tiering >= uc_burden_tier3_threshold,
    3L,
    
    uc_burden_ratio_for_tiering >= uc_burden_tier2_threshold,
    2L,
    
    uc_burden_ratio_for_tiering >= uc_burden_tier1_threshold,
    1L,
    
    default = 0L
  )
]

stab[
  ,
  high_uc_burden_flag :=
    uc_burden_tier >= 2L
]

stab[
  ,
  severe_uc_burden_flag :=
    uc_burden_tier >= 3L
]

stab[
  ,
  critical_uc_burden_flag :=
    uc_burden_tier >= 4L
]

# ============================================================
# 5. Within-group UC burden percentiles
# ============================================================

stab[
  ,
  uc_burden_percentile_within_clean_group := NA_real_
]

stab[
  provider_backbone_include_v1 == TRUE &
    uc_burden_available_flag == TRUE,
  uc_burden_percentile_within_clean_group :=
    data.table::frank(
      uc_burden_ratio_for_tiering,
      ties.method = "average",
      na.last = "keep"
    ) / .N,
  by = clean_provider_group
]

stab[
  ,
  uc_burden_top_quartile_within_group_flag :=
    !is.na(uc_burden_percentile_within_clean_group) &
    uc_burden_percentile_within_clean_group >= 0.75 &
    !is.na(uc_burden_ratio_for_tiering) &
    uc_burden_ratio_for_tiering > 0
]

stab[
  ,
  uc_burden_top_decile_within_group_flag :=
    !is.na(uc_burden_percentile_within_clean_group) &
    uc_burden_percentile_within_clean_group >= 0.90 &
    !is.na(uc_burden_ratio_for_tiering) &
    uc_burden_ratio_for_tiering > 0
]

# ============================================================
# 6. Diagnostic-only operating position metrics
# ============================================================

# Prior run showed margin-based tiering was too aggressive because provisional
# G-3 line interpretation generated suspicious values, especially median -1.000
# for Rural / CAH / IHS and many specialty providers.
#
# Therefore these fields are retained only for diagnostics and publication caveats.
# They DO NOT drive final stabilization_tier_numeric.

stab[
  ,
  operating_revenue_candidate :=
    data.table::fifelse(
      !is.na(g3_line_00400_c001) & g3_line_00400_c001 > 0,
      g3_line_00400_c001,
      NA_real_
    )
]

stab[
  ,
  operating_income_candidate :=
    g3_line_00500_c001
]

stab[
  ,
  operating_margin_candidate :=
    data.table::fifelse(
      !is.na(operating_income_candidate) &
        !is.na(operating_revenue_candidate) &
        operating_revenue_candidate > 0,
      operating_income_candidate / operating_revenue_candidate,
      NA_real_
    )
]

stab[
  ,
  operating_margin_available_flag :=
    !is.na(operating_margin_candidate)
]

stab[
  ,
  negative_margin_candidate_flag :=
    operating_margin_available_flag == TRUE &
    operating_margin_candidate < 0
]

stab[
  ,
  diagnostic_margin_stress_tier := data.table::fcase(
    operating_margin_available_flag == FALSE,
    0L,
    
    operating_margin_candidate <= -0.10,
    4L,
    
    operating_margin_candidate <= -0.05,
    3L,
    
    operating_margin_candidate <= -0.02,
    2L,
    
    operating_margin_candidate < 0,
    1L,
    
    default = 0L
  )
]

stab[
  ,
  diagnostic_severe_negative_margin_flag :=
    diagnostic_margin_stress_tier >= 3L
]

# Backward-compatible diagnostic alias.
stab[
  ,
  margin_stress_tier := diagnostic_margin_stress_tier
]

stab[
  ,
  severe_negative_margin_candidate_flag :=
    diagnostic_severe_negative_margin_flag
]

# ============================================================
# 7. Baseline protected-class tier
# ============================================================

stab[
  ,
  baseline_class_stabilization_tier := data.table::fcase(
    clean_provider_group == "Rural / CAH / IHS",
    rural_cah_ihs_min_tier,
    
    clean_provider_group == "Children's / pediatric",
    children_min_tier,
    
    clean_provider_group == "General acute / academic",
    general_acute_min_tier,
    
    clean_provider_group == "Specialty / behavioral / rehab",
    specialty_min_tier,
    
    default = 0L
  )
]

# ============================================================
# 8. Safety-net UC-burden tier
# ============================================================

stab[
  ,
  safety_net_burden_tier := data.table::fcase(
    critical_uc_burden_flag == TRUE,
    4L,
    
    severe_uc_burden_flag == TRUE,
    3L,
    
    high_uc_burden_flag == TRUE,
    2L,
    
    use_within_group_percentile_triggers == TRUE &
      uc_burden_top_decile_within_group_flag == TRUE,
    2L,
    
    use_within_group_percentile_triggers == TRUE &
      uc_burden_top_quartile_within_group_flag == TRUE,
    1L,
    
    default = 0L
  )
]

# ============================================================
# 9. Final stabilization tier
# ============================================================

# Critical correction:
#   final tier is class + UC burden only.
#   diagnostic_margin_stress_tier is NOT included.
stab[
  ,
  stabilization_tier_numeric :=
    pmax(
      baseline_class_stabilization_tier,
      safety_net_burden_tier,
      na.rm = TRUE
    )
]

stab[
  ,
  stabilization_tier := data.table::fcase(
    stabilization_tier_numeric == 4L,
    "Tier 4 - critical transition support",
    
    stabilization_tier_numeric == 3L,
    "Tier 3 - high transition support",
    
    stabilization_tier_numeric == 2L,
    "Tier 2 - moderate transition support",
    
    stabilization_tier_numeric == 1L,
    "Tier 1 - monitoring / low support",
    
    default = "Tier 0 - not eligible"
  )
]

stab[
  ,
  stabilization_eligible_bounded_flag :=
    provider_backbone_include_v1 == TRUE &
    stabilization_tier_numeric > 0L
]

stab[
  ,
  stabilization_basis := data.table::fcase(
    baseline_class_stabilization_tier > 0L &
      safety_net_burden_tier > 0L,
    "class + UC burden",
    
    baseline_class_stabilization_tier > 0L,
    "class-based transition protection",
    
    safety_net_burden_tier > 0L,
    "UC burden safety-net trigger",
    
    default = "none"
  )
]

# Explicitly preserve whether a provider would have been flagged by the
# diagnostic margin screen, without using that to assign support.
stab[
  ,
  diagnostic_margin_stress_flag :=
    diagnostic_margin_stress_tier > 0L
]

stab[
  ,
  diagnostic_margin_note := data.table::fcase(
    diagnostic_margin_stress_tier >= 3L,
    "diagnostic severe margin stress; not used for final tier",
    
    diagnostic_margin_stress_tier > 0L,
    "diagnostic margin stress; not used for final tier",
    
    operating_margin_available_flag == TRUE,
    "no diagnostic margin stress",
    
    default = "margin unavailable"
  )
]

# ============================================================
# 10. Support cap rates and capped support amounts
# ============================================================

stab[
  ,
  transition_support_cap_rate := data.table::fcase(
    stabilization_tier_numeric == 4L,
    tier4_support_cap_rate,
    
    stabilization_tier_numeric == 3L,
    tier3_support_cap_rate,
    
    stabilization_tier_numeric == 2L,
    tier2_support_cap_rate,
    
    stabilization_tier_numeric == 1L,
    tier1_support_cap_rate,
    
    default = 0
  )
]

stab[
  ,
  annual_transition_support_cap :=
    data.table::fifelse(
      stabilization_eligible_bounded_flag == TRUE &
        stabilization_revenue_base_available_flag == TRUE,
      stabilization_revenue_base * transition_support_cap_rate,
      0
    )
]

# Alternative cap using modeled outpatient exposure base.
stab[
  ,
  annual_transition_support_cap_op_exposure :=
    data.table::fifelse(
      stabilization_eligible_bounded_flag == TRUE &
        !is.na(net_outpatient_exposure_base_model) &
        net_outpatient_exposure_base_model > 0,
      net_outpatient_exposure_base_model * transition_support_cap_rate,
      0
    )
]

# Conservative model cap:
#   If both revenue-base and outpatient-exposure cap are available, use smaller.
stab[
  ,
  annual_transition_support_cap_model :=
    data.table::fcase(
      annual_transition_support_cap > 0 &
        annual_transition_support_cap_op_exposure > 0,
      pmin(annual_transition_support_cap, annual_transition_support_cap_op_exposure),
      
      annual_transition_support_cap > 0,
      annual_transition_support_cap,
      
      annual_transition_support_cap_op_exposure > 0,
      annual_transition_support_cap_op_exposure,
      
      default = 0
    )
]

# ============================================================
# 11. Review flags
# ============================================================

stab[
  ,
  stabilization_review_flag :=
    provider_backbone_include_v1 == TRUE &
    (
      stabilization_eligible_bounded_flag == TRUE |
        classification_needs_external_validation_flag == TRUE |
        raw_provider_model_class == "Critical access hospital" |
        stabilization_tier_numeric >= 3L |
        diagnostic_margin_stress_tier >= 3L
    )
]

stab[
  ,
  stabilization_review_priority := data.table::fcase(
    stabilization_tier_numeric == 4L,
    "High - Tier 4 UC/class",
    
    stabilization_tier_numeric == 3L,
    "High - Tier 3 UC/class",
    
    classification_needs_external_validation_flag == TRUE &
      raw_provider_model_class == "Critical access hospital",
    "Medium - raw CAH needs external validation",
    
    stabilization_tier_numeric == 2L,
    "Medium - Tier 2 class/UC",
    
    stabilization_tier_numeric == 1L,
    "Low - Tier 1 UC monitoring",
    
    diagnostic_margin_stress_tier >= 3L,
    "Low - diagnostic margin stress only",
    
    default = "No immediate review flag"
  )
]

# ============================================================
# 12. Save outputs
# ============================================================

stab_rds <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_provider_master_with_stabilization.rds")
)

stab_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_provider_master_with_stabilization.csv")
)

summary_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_stabilization_summary.csv")
)

review_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_stabilization_tier_review_list.csv")
)

diagnostic_margin_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_diagnostic_margin_stress_list.csv")
)

saveRDS(stab, stab_rds)
data.table::fwrite(stab, stab_csv)

# ============================================================
# 13. Summary tables
# ============================================================

stabilization_summary <- stab[
  provider_backbone_include_v1 == TRUE,
  .(
    providers = .N,
    revenue_use_for_model = sum(revenue_use_for_model_flag, na.rm = TRUE),
    
    total_net_patient_revenue =
      sum(net_patient_revenue_model, na.rm = TRUE),
    
    total_gross_patient_revenue =
      sum(gross_total_patient_revenue_model, na.rm = TRUE),
    
    total_net_outpatient_exposure =
      sum(net_outpatient_exposure_base_model, na.rm = TRUE),
    
    total_uncompensated_care =
      sum(uncompensated_care_cost_model, na.rm = TRUE),
    
    uc_burden_available =
      sum(uc_burden_available_flag, na.rm = TRUE),
    
    median_uc_to_npr =
      median(uc_to_net_patient_revenue_ratio, na.rm = TRUE),
    
    mean_uc_to_npr =
      mean(uc_to_net_patient_revenue_ratio, na.rm = TRUE),
    
    diagnostic_margin_available =
      sum(operating_margin_available_flag, na.rm = TRUE),
    
    diagnostic_median_operating_margin_candidate =
      median(operating_margin_candidate, na.rm = TRUE),
    
    diagnostic_severe_margin_stress =
      sum(diagnostic_severe_negative_margin_flag, na.rm = TRUE),
    
    stabilization_eligible_bounded =
      sum(stabilization_eligible_bounded_flag, na.rm = TRUE),
    
    annual_transition_support_cap_model =
      sum(annual_transition_support_cap_model, na.rm = TRUE)
  ),
  by = .(
    clean_provider_group,
    clean_provider_model_class,
    stabilization_tier
  )
][order(clean_provider_group, clean_provider_model_class, stabilization_tier)]

data.table::fwrite(stabilization_summary, summary_csv)

stabilization_review <- stab[
  provider_backbone_include_v1 == TRUE &
    stabilization_review_flag == TRUE,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    city,
    state_abbrev,
    raw_provider_model_class,
    clean_provider_model_class,
    clean_provider_group,
    revenue_source_method,
    revenue_use_for_model_flag,
    hospital_beds,
    gross_total_patient_revenue,
    net_patient_revenue,
    net_outpatient_exposure_base,
    uncompensated_care_cost,
    uc_to_net_patient_revenue_ratio,
    uc_burden_percentile_within_clean_group,
    operating_margin_candidate,
    diagnostic_margin_stress_tier,
    diagnostic_margin_note,
    baseline_class_stabilization_tier,
    safety_net_burden_tier,
    stabilization_tier,
    stabilization_basis,
    transition_support_cap_rate,
    annual_transition_support_cap_model,
    classification_needs_external_validation_flag,
    stabilization_review_priority
  )
][order(
  stabilization_review_priority,
  clean_provider_group,
  clean_provider_model_class,
  -annual_transition_support_cap_model
)]

data.table::fwrite(stabilization_review, review_csv)

diagnostic_margin_stress <- stab[
  provider_backbone_include_v1 == TRUE &
    diagnostic_margin_stress_tier >= 3L,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    city,
    state_abbrev,
    raw_provider_model_class,
    clean_provider_model_class,
    clean_provider_group,
    revenue_source_method,
    revenue_use_for_model_flag,
    operating_revenue_candidate,
    operating_income_candidate,
    operating_margin_candidate,
    diagnostic_margin_stress_tier,
    diagnostic_margin_note,
    stabilization_tier,
    stabilization_basis,
    annual_transition_support_cap_model
  )
][order(clean_provider_group, clean_provider_model_class, operating_margin_candidate)]

data.table::fwrite(diagnostic_margin_stress, diagnostic_margin_csv)

# ============================================================
# 14. Print summaries
# ============================================================

cat("\n============================================================\n")
cat("STABILIZATION ELIGIBILITY COMPLETE\n")
cat("============================================================\n")

cat("\nBounded stabilization tiers, backbone providers:\n")
print(stab[
  provider_backbone_include_v1 == TRUE,
  .N,
  by = stabilization_tier
][order(stabilization_tier)])

cat("\nBounded stabilization tiers by clean provider group:\n")
print(stab[
  provider_backbone_include_v1 == TRUE,
  .N,
  by = .(clean_provider_group, stabilization_tier)
][order(clean_provider_group, stabilization_tier)])

cat("\nStabilization summary by clean group / class / tier:\n")
print(stabilization_summary)

cat("\nUC burden summary by clean provider group:\n")
print(stab[
  provider_backbone_include_v1 == TRUE,
  .(
    providers = .N,
    uc_burden_available = sum(uc_burden_available_flag, na.rm = TRUE),
    median_uc_to_npr = median(uc_to_net_patient_revenue_ratio, na.rm = TRUE),
    p75_uc_to_npr = as.numeric(quantile(uc_to_net_patient_revenue_ratio, 0.75, na.rm = TRUE)),
    p90_uc_to_npr = as.numeric(quantile(uc_to_net_patient_revenue_ratio, 0.90, na.rm = TRUE)),
    max_uc_to_npr = max(uc_to_net_patient_revenue_ratio, na.rm = TRUE),
    high_uc_burden = sum(high_uc_burden_flag, na.rm = TRUE),
    severe_uc_burden = sum(severe_uc_burden_flag, na.rm = TRUE),
    critical_uc_burden = sum(critical_uc_burden_flag, na.rm = TRUE)
  ),
  by = clean_provider_group
][order(clean_provider_group)])

cat("\nDiagnostic operating margin candidate summary by clean provider group:\n")
print(stab[
  provider_backbone_include_v1 == TRUE,
  .(
    providers = .N,
    margin_available = sum(operating_margin_available_flag, na.rm = TRUE),
    median_margin = median(operating_margin_candidate, na.rm = TRUE),
    p25_margin = as.numeric(quantile(operating_margin_candidate, 0.25, na.rm = TRUE)),
    p10_margin = as.numeric(quantile(operating_margin_candidate, 0.10, na.rm = TRUE)),
    min_margin = min(operating_margin_candidate, na.rm = TRUE),
    negative_margin = sum(negative_margin_candidate_flag, na.rm = TRUE),
    diagnostic_severe_margin_stress =
      sum(diagnostic_severe_negative_margin_flag, na.rm = TRUE)
  ),
  by = clean_provider_group
][order(clean_provider_group)])

cat("\nSupport cap totals by clean provider group:\n")
print(stab[
  provider_backbone_include_v1 == TRUE,
  .(
    providers = .N,
    stabilization_eligible_bounded =
      sum(stabilization_eligible_bounded_flag, na.rm = TRUE),
    total_revenue_base =
      sum(stabilization_revenue_base, na.rm = TRUE),
    total_net_outpatient_exposure =
      sum(net_outpatient_exposure_base_model, na.rm = TRUE),
    annual_transition_support_cap =
      sum(annual_transition_support_cap, na.rm = TRUE),
    annual_transition_support_cap_op_exposure =
      sum(annual_transition_support_cap_op_exposure, na.rm = TRUE),
    annual_transition_support_cap_model =
      sum(annual_transition_support_cap_model, na.rm = TRUE)
  ),
  by = clean_provider_group
][order(clean_provider_group)])

cat("\nTop providers by bounded annual transition support cap:\n")
print(stab[
  provider_backbone_include_v1 == TRUE &
    annual_transition_support_cap_model > 0,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    state_abbrev,
    raw_provider_model_class,
    clean_provider_model_class,
    clean_provider_group,
    stabilization_tier,
    stabilization_basis,
    stabilization_revenue_base,
    net_outpatient_exposure_base_model,
    uncompensated_care_cost_model,
    uc_to_net_patient_revenue_ratio,
    operating_margin_candidate,
    diagnostic_margin_stress_tier,
    transition_support_cap_rate,
    annual_transition_support_cap_model
  )
][order(-annual_transition_support_cap_model)][1:75])

cat("\nProviders not eligible after bounded stabilization filter:\n")
print(stab[
  provider_backbone_include_v1 == TRUE &
    stabilization_eligible_bounded_flag == FALSE,
  .N,
  by = clean_provider_group
][order(-N)])

cat("\nDiagnostic severe margin stress records not used for tiering:\n")
print(stab[
  provider_backbone_include_v1 == TRUE &
    diagnostic_margin_stress_tier >= 3L,
  .N,
  by = clean_provider_group
][order(-N)])

cat("\nSaved:\n")
cat(stab_rds, "\n")
cat(stab_csv, "\n")
cat(summary_csv, "\n")
cat(review_csv, "\n")
cat(diagnostic_margin_csv, "\n")

cat("\n============================================================\n")
```

---

# 11_create_provider_impact_scenarios.R

```r
# Scripts/11_create_provider_impact_scenarios.R
# Create UCC/HSE provider-impact scenario tables from the FY2024 HCRIS backbone.
#
# Inputs:
#   Processed/hcris_YYYY_provider_master_with_stabilization.rds
#
# Outputs:
#   Processed/hcris_YYYY_provider_impact_scenarios.rds
#   Processed/hcris_YYYY_provider_impact_basebase_provider_level.rds
#
#   Output/hcris_YYYY_table_7A_provider_impact_3x3_matrix.csv
#   Output/hcris_YYYY_table_7B_provider_impact_by_clean_group_basebase.csv
#   Output/hcris_YYYY_table_7C_provider_impact_by_clean_class_basebase.csv
#   Output/hcris_YYYY_table_7D_provider_level_effect_distribution_basebase.csv
#   Output/hcris_YYYY_provider_impact_basebase_provider_level.csv
#
# Purpose:
#   Estimate provider-level and aggregate provider impact under UCC/HSE using:
#     1. outpatient/routine repricing exposure
#     2. uncompensated-care / liquidity offset
#     3. bounded stabilization support
#
# Conceptual model:
#   Gross provider impact =
#     - outpatient repricing pressure
#     + uncompensated-care offset
#     + transition stabilization support
#
# Notes:
#   - This is a provider-impact model, not final federal budget scoring.
#   - Stabilization is bounded by Script 10.
#   - Operating margin diagnostics are not used for tiering or support.
#   - Standard hospitals use HCRIS-derived net outpatient exposure.
#   - Rural and children's total-only fallback records use explicit scenario assumptions
#     created earlier in Script 08.
#
# Required prior scripts:
#   08_extract_g2_g3_revenue_expense.R
#   09_validate_provider_classification.R
#   10_create_stabilization_eligibility.R

source("Scripts/00_setup.R")

cat("\n============================================================\n")
cat("CREATE PROVIDER IMPACT SCENARIOS\n")
cat("============================================================\n")
cat("Build year:", hcris_year_label, "\n\n")

# ============================================================
# 0. Scenario assumptions
# ============================================================

# Repricing intensity:
#   This is the assumed reduction pressure on the modeled net outpatient exposure base.
#   It is not a hard policy haircut on every provider.
#   It represents the provider-side revenue pressure from routine-care price discipline,
#   HSA-funded purchasing, transparent pricing, site-neutral substitution, and plan competition.

repricing_scenarios <- data.table::data.table(
  repricing_scenario = c("Low repricing", "Base repricing", "High repricing"),
  repricing_rate = c(0.05, 0.10, 0.15)
)

# Stabilization generosity:
#   Multiplier applied to the bounded stabilization cap from Script 10.
#   Base = 100% of bounded cap.
#   Low = 50% of bounded cap.
#   High = 150% of bounded cap.
#
# This keeps transition protection bounded and formula-based.

stabilization_scenarios <- data.table::data.table(
  stabilization_scenario = c("Low stabilization", "Base stabilization", "High stabilization"),
  stabilization_multiplier = c(0.50, 1.00, 1.50)
)

# Uncompensated-care offset assumptions:
#   UCC/HSE coverage and routine liquidity should reduce some uncompensated care and bad debt.
#   This model applies an offset to S-10 uncompensated care.
#
# The offset is intentionally partial. It should not assume all uncompensated care disappears.
# Base case uses 25% of reported uncompensated care as a provider-side offset.

uc_offset_rate_low  <- 0.15
uc_offset_rate_base <- 0.25
uc_offset_rate_high <- 0.35

# Tie UC offset to repricing scenario conservatively:
#   Low repricing scenario uses low UC offset.
#   Base repricing scenario uses base UC offset.
#   High repricing scenario uses high UC offset.
#
# This is not because repricing directly causes offset, but because the scenarios are
# intended to represent low/base/high total policy effectiveness.

repricing_scenarios[
  ,
  uc_offset_rate := data.table::fcase(
    repricing_scenario == "Low repricing",
    uc_offset_rate_low,
    
    repricing_scenario == "Base repricing",
    uc_offset_rate_base,
    
    repricing_scenario == "High repricing",
    uc_offset_rate_high
  )
]

# Provider-level floor/cap diagnostics.
# We do NOT censor provider impact by default, but we flag very large impacts.
large_negative_impact_threshold_npr <- -0.05
large_positive_impact_threshold_npr <-  0.05

# Base/base labels.
base_repricing_label <- "Base repricing"
base_stabilization_label <- "Base stabilization"

# ============================================================
# 1. Load input
# ============================================================

stab_file <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_provider_master_with_stabilization.rds")
)

if (!file.exists(stab_file)) {
  stop("Missing stabilization file: ", stab_file)
}

dt <- readRDS(stab_file)

cat("Loaded:\n")
cat(stab_file, "\n")
cat("\nRows:", nrow(dt), "\n")

# ============================================================
# 2. Safety checks
# ============================================================

required_cols <- c(
  "rpt_rec_num",
  "prvdr_num_chr",
  "provider_name",
  "city",
  "state_abbrev",
  "provider_backbone_include_v1",
  "raw_provider_model_class",
  "clean_provider_model_class",
  "clean_provider_group",
  "revenue_source_method",
  "revenue_use_for_model_flag",
  "gross_total_patient_revenue_model",
  "net_patient_revenue_model",
  "net_outpatient_exposure_base_model",
  "net_outpatient_exposure_low_model",
  "net_outpatient_exposure_high_model",
  "uncompensated_care_cost_model",
  "stabilization_tier",
  "stabilization_tier_numeric",
  "stabilization_basis",
  "transition_support_cap_rate",
  "annual_transition_support_cap_model",
  "stabilization_eligible_bounded_flag",
  "classification_needs_external_validation_flag",
  "diagnostic_margin_stress_tier"
)

missing_cols <- setdiff(required_cols, names(dt))

if (length(missing_cols) > 0) {
  stop(
    "Stabilization file missing required columns:\n",
    paste(missing_cols, collapse = "\n")
  )
}

# Restrict to backbone providers.
backbone <- copy(dt[provider_backbone_include_v1 == TRUE])

cat("\nBackbone providers:", nrow(backbone), "\n")

# ============================================================
# 3. Provider-level base fields
# ============================================================

backbone[
  ,
  provider_impact_model_include_flag :=
    revenue_use_for_model_flag == TRUE &
    !is.na(net_patient_revenue_model) &
    net_patient_revenue_model > 0
]

# Conservative outpatient exposure base:
#   Use base exposure for base scenario.
#   Use low/high exposure fields only for low/high repricing scenarios if they exist.
#   For standard records low/base/high are equal.
#   For rural/children fallback records low/base/high vary according to fallback assumption.

backbone[
  ,
  exposure_base_base :=
    data.table::fifelse(
      provider_impact_model_include_flag == TRUE,
      net_outpatient_exposure_base_model,
      0
    )
]

backbone[
  ,
  exposure_base_low :=
    data.table::fifelse(
      provider_impact_model_include_flag == TRUE,
      net_outpatient_exposure_low_model,
      0
    )
]

backbone[
  ,
  exposure_base_high :=
    data.table::fifelse(
      provider_impact_model_include_flag == TRUE,
      net_outpatient_exposure_high_model,
      0
    )
]

# Fallback if low/high are missing.
backbone[
  is.na(exposure_base_low),
  exposure_base_low := exposure_base_base
]

backbone[
  is.na(exposure_base_high),
  exposure_base_high := exposure_base_base
]

# Core denominators.
backbone[
  ,
  provider_revenue_denominator :=
    data.table::fcase(
      !is.na(net_patient_revenue_model) & net_patient_revenue_model > 0,
      net_patient_revenue_model,
      
      !is.na(gross_total_patient_revenue_model) & gross_total_patient_revenue_model > 0,
      gross_total_patient_revenue_model,
      
      default = NA_real_
    )
]

backbone[
  ,
  uncompensated_care_for_offset :=
    data.table::fifelse(
      !is.na(uncompensated_care_cost_model) &
        uncompensated_care_cost_model > 0,
      uncompensated_care_cost_model,
      0
    )
]

backbone[
  ,
  stabilization_cap_for_model :=
    data.table::fifelse(
      !is.na(annual_transition_support_cap_model) &
        annual_transition_support_cap_model > 0,
      annual_transition_support_cap_model,
      0
    )
]

# ============================================================
# 4. Build full 3x3 provider-level scenario table
# ============================================================

repricing_scenarios[
  ,
  scenario_join_key := 1L
]

stabilization_scenarios[
  ,
  scenario_join_key := 1L
]

scenario_grid <- merge(
  repricing_scenarios,
  stabilization_scenarios,
  by = "scenario_join_key",
  allow.cartesian = TRUE
)

scenario_grid[
  ,
  scenario_join_key := NULL
]

backbone[
  ,
  scenario_join_key := 1L
]

scenario_grid[
  ,
  scenario_join_key := 1L
]

provider_scenarios <- merge(
  backbone,
  scenario_grid,
  by = "scenario_join_key",
  allow.cartesian = TRUE
)

provider_scenarios[
  ,
  scenario_join_key := NULL
]

# Clean up helper key from source tables.
repricing_scenarios[
  ,
  scenario_join_key := NULL
]

stabilization_scenarios[
  ,
  scenario_join_key := NULL
]

# Select exposure base by repricing scenario.
provider_scenarios[
  ,
  outpatient_exposure_used := data.table::fcase(
    repricing_scenario == "Low repricing",
    exposure_base_low,
    
    repricing_scenario == "Base repricing",
    exposure_base_base,
    
    repricing_scenario == "High repricing",
    exposure_base_high,
    
    default = exposure_base_base
  )
]

# Repricing pressure: negative provider-side effect.
provider_scenarios[
  ,
  outpatient_repricing_pressure :=
    -1 * outpatient_exposure_used * repricing_rate
]

# UC / liquidity offset: positive provider-side effect.
provider_scenarios[
  ,
  uncompensated_care_offset :=
    uncompensated_care_for_offset * uc_offset_rate
]

# Stabilization support: positive provider-side effect, bounded.
provider_scenarios[
  ,
  stabilization_support :=
    stabilization_cap_for_model * stabilization_multiplier
]

# Net provider impact.
provider_scenarios[
  ,
  net_provider_impact :=
    outpatient_repricing_pressure +
    uncompensated_care_offset +
    stabilization_support
]

# Impact ratios.
provider_scenarios[
  ,
  net_provider_impact_pct_of_npr :=
    data.table::fifelse(
      !is.na(net_patient_revenue_model) &
        net_patient_revenue_model > 0,
      net_provider_impact / net_patient_revenue_model,
      NA_real_
    )
]

provider_scenarios[
  ,
  repricing_pressure_pct_of_npr :=
    data.table::fifelse(
      !is.na(net_patient_revenue_model) &
        net_patient_revenue_model > 0,
      outpatient_repricing_pressure / net_patient_revenue_model,
      NA_real_
    )
]

provider_scenarios[
  ,
  uc_offset_pct_of_npr :=
    data.table::fifelse(
      !is.na(net_patient_revenue_model) &
        net_patient_revenue_model > 0,
      uncompensated_care_offset / net_patient_revenue_model,
      NA_real_
    )
]

provider_scenarios[
  ,
  stabilization_support_pct_of_npr :=
    data.table::fifelse(
      !is.na(net_patient_revenue_model) &
        net_patient_revenue_model > 0,
      stabilization_support / net_patient_revenue_model,
      NA_real_
    )
]

# Flags.
provider_scenarios[
  ,
  negative_net_impact_flag :=
    !is.na(net_provider_impact) &
    net_provider_impact < 0
]

provider_scenarios[
  ,
  positive_net_impact_flag :=
    !is.na(net_provider_impact) &
    net_provider_impact > 0
]

provider_scenarios[
  ,
  large_negative_net_impact_flag :=
    !is.na(net_provider_impact_pct_of_npr) &
    net_provider_impact_pct_of_npr <= large_negative_impact_threshold_npr
]

provider_scenarios[
  ,
  large_positive_net_impact_flag :=
    !is.na(net_provider_impact_pct_of_npr) &
    net_provider_impact_pct_of_npr >= large_positive_impact_threshold_npr
]

# Scenario ordering.
provider_scenarios[
  ,
  repricing_scenario_order := data.table::fcase(
    repricing_scenario == "Low repricing", 1L,
    repricing_scenario == "Base repricing", 2L,
    repricing_scenario == "High repricing", 3L,
    default = 99L
  )
]

provider_scenarios[
  ,
  stabilization_scenario_order := data.table::fcase(
    stabilization_scenario == "Low stabilization", 1L,
    stabilization_scenario == "Base stabilization", 2L,
    stabilization_scenario == "High stabilization", 3L,
    default = 99L
  )
]

# ============================================================
# 5. Table 7A — 3x3 Scenario Matrix
# ============================================================

table_7A <- provider_scenarios[
  provider_impact_model_include_flag == TRUE,
  .(
    providers_in_model = .N,
    
    total_net_patient_revenue =
      sum(net_patient_revenue_model, na.rm = TRUE),
    
    total_gross_patient_revenue =
      sum(gross_total_patient_revenue_model, na.rm = TRUE),
    
    total_outpatient_exposure_used =
      sum(outpatient_exposure_used, na.rm = TRUE),
    
    total_outpatient_repricing_pressure =
      sum(outpatient_repricing_pressure, na.rm = TRUE),
    
    total_uncompensated_care_offset =
      sum(uncompensated_care_offset, na.rm = TRUE),
    
    total_stabilization_support =
      sum(stabilization_support, na.rm = TRUE),
    
    total_net_provider_impact =
      sum(net_provider_impact, na.rm = TRUE),
    
    net_impact_pct_of_total_npr =
      sum(net_provider_impact, na.rm = TRUE) /
      sum(net_patient_revenue_model, na.rm = TRUE),
    
    repricing_pressure_pct_of_total_npr =
      sum(outpatient_repricing_pressure, na.rm = TRUE) /
      sum(net_patient_revenue_model, na.rm = TRUE),
    
    uc_offset_pct_of_total_npr =
      sum(uncompensated_care_offset, na.rm = TRUE) /
      sum(net_patient_revenue_model, na.rm = TRUE),
    
    stabilization_support_pct_of_total_npr =
      sum(stabilization_support, na.rm = TRUE) /
      sum(net_patient_revenue_model, na.rm = TRUE),
    
    providers_negative_net_impact =
      sum(negative_net_impact_flag, na.rm = TRUE),
    
    providers_positive_net_impact =
      sum(positive_net_impact_flag, na.rm = TRUE),
    
    providers_large_negative_net_impact =
      sum(large_negative_net_impact_flag, na.rm = TRUE),
    
    median_provider_impact_pct_of_npr =
      median(net_provider_impact_pct_of_npr, na.rm = TRUE),
    
    p25_provider_impact_pct_of_npr =
      as.numeric(quantile(net_provider_impact_pct_of_npr, 0.25, na.rm = TRUE)),
    
    p75_provider_impact_pct_of_npr =
      as.numeric(quantile(net_provider_impact_pct_of_npr, 0.75, na.rm = TRUE))
  ),
  by = .(
    repricing_scenario_order,
    repricing_scenario,
    repricing_rate,
    uc_offset_rate,
    stabilization_scenario_order,
    stabilization_scenario,
    stabilization_multiplier
  )
][order(repricing_scenario_order, stabilization_scenario_order)]

# ============================================================
# 6. Base/Base provider-level table
# ============================================================

basebase_provider_level <- provider_scenarios[
  repricing_scenario == base_repricing_label &
    stabilization_scenario == base_stabilization_label
]

# ============================================================
# 7. Table 7B — by clean provider group under Base/Base
# ============================================================

table_7B <- basebase_provider_level[
  ,
  .(
    providers = .N,
    providers_in_model = sum(provider_impact_model_include_flag, na.rm = TRUE),
    
    total_net_patient_revenue =
      sum(net_patient_revenue_model, na.rm = TRUE),
    
    total_gross_patient_revenue =
      sum(gross_total_patient_revenue_model, na.rm = TRUE),
    
    total_outpatient_exposure_used =
      sum(outpatient_exposure_used, na.rm = TRUE),
    
    total_outpatient_repricing_pressure =
      sum(outpatient_repricing_pressure, na.rm = TRUE),
    
    total_uncompensated_care_offset =
      sum(uncompensated_care_offset, na.rm = TRUE),
    
    total_stabilization_support =
      sum(stabilization_support, na.rm = TRUE),
    
    total_net_provider_impact =
      sum(net_provider_impact, na.rm = TRUE),
    
    net_impact_pct_of_total_npr =
      sum(net_provider_impact, na.rm = TRUE) /
      sum(net_patient_revenue_model, na.rm = TRUE),
    
    median_provider_impact_pct_of_npr =
      median(net_provider_impact_pct_of_npr, na.rm = TRUE),
    
    providers_negative_net_impact =
      sum(negative_net_impact_flag, na.rm = TRUE),
    
    providers_positive_net_impact =
      sum(positive_net_impact_flag, na.rm = TRUE),
    
    providers_large_negative_net_impact =
      sum(large_negative_net_impact_flag, na.rm = TRUE),
    
    stabilization_eligible =
      sum(stabilization_eligible_bounded_flag, na.rm = TRUE),
    
    diagnostic_margin_stress_tier_3_or_4 =
      sum(diagnostic_margin_stress_tier >= 3L, na.rm = TRUE)
  ),
  by = clean_provider_group
][order(clean_provider_group)]

# ============================================================
# 8. Table 7C — by clean provider class under Base/Base
# ============================================================

table_7C <- basebase_provider_level[
  ,
  .(
    providers = .N,
    providers_in_model = sum(provider_impact_model_include_flag, na.rm = TRUE),
    
    total_net_patient_revenue =
      sum(net_patient_revenue_model, na.rm = TRUE),
    
    total_gross_patient_revenue =
      sum(gross_total_patient_revenue_model, na.rm = TRUE),
    
    total_outpatient_exposure_used =
      sum(outpatient_exposure_used, na.rm = TRUE),
    
    total_outpatient_repricing_pressure =
      sum(outpatient_repricing_pressure, na.rm = TRUE),
    
    total_uncompensated_care_offset =
      sum(uncompensated_care_offset, na.rm = TRUE),
    
    total_stabilization_support =
      sum(stabilization_support, na.rm = TRUE),
    
    total_net_provider_impact =
      sum(net_provider_impact, na.rm = TRUE),
    
    net_impact_pct_of_total_npr =
      sum(net_provider_impact, na.rm = TRUE) /
      sum(net_patient_revenue_model, na.rm = TRUE),
    
    median_provider_impact_pct_of_npr =
      median(net_provider_impact_pct_of_npr, na.rm = TRUE),
    
    providers_negative_net_impact =
      sum(negative_net_impact_flag, na.rm = TRUE),
    
    providers_positive_net_impact =
      sum(positive_net_impact_flag, na.rm = TRUE),
    
    providers_large_negative_net_impact =
      sum(large_negative_net_impact_flag, na.rm = TRUE),
    
    stabilization_eligible =
      sum(stabilization_eligible_bounded_flag, na.rm = TRUE),
    
    diagnostic_margin_stress_tier_3_or_4 =
      sum(diagnostic_margin_stress_tier >= 3L, na.rm = TRUE)
  ),
  by = .(
    clean_provider_group,
    clean_provider_model_class
  )
][order(clean_provider_group, clean_provider_model_class)]

# ============================================================
# 9. Table 7D — distribution of provider-level effects under Base/Base
# ============================================================

distribution_breaks <- c(
  -Inf,
  -0.10,
  -0.05,
  -0.025,
  -0.01,
  0,
  0.01,
  0.025,
  0.05,
  0.10,
  Inf
)

distribution_labels <- c(
  "<= -10%",
  "-10% to -5%",
  "-5% to -2.5%",
  "-2.5% to -1%",
  "-1% to 0%",
  "0% to 1%",
  "1% to 2.5%",
  "2.5% to 5%",
  "5% to 10%",
  "> 10%"
)

basebase_provider_level[
  ,
  provider_impact_pct_bucket :=
    cut(
      net_provider_impact_pct_of_npr,
      breaks = distribution_breaks,
      labels = distribution_labels,
      right = TRUE
    )
]

table_7D <- basebase_provider_level[
  provider_impact_model_include_flag == TRUE,
  .(
    providers = .N,
    total_net_patient_revenue =
      sum(net_patient_revenue_model, na.rm = TRUE),
    
    total_net_provider_impact =
      sum(net_provider_impact, na.rm = TRUE),
    
    median_provider_impact_pct_of_npr =
      median(net_provider_impact_pct_of_npr, na.rm = TRUE)
  ),
  by = .(
    clean_provider_group,
    provider_impact_pct_bucket
  )
][order(clean_provider_group, provider_impact_pct_bucket)]

# Overall distribution as separate rows.
table_7D_overall <- basebase_provider_level[
  provider_impact_model_include_flag == TRUE,
  .(
    providers = .N,
    total_net_patient_revenue =
      sum(net_patient_revenue_model, na.rm = TRUE),
    
    total_net_provider_impact =
      sum(net_provider_impact, na.rm = TRUE),
    
    median_provider_impact_pct_of_npr =
      median(net_provider_impact_pct_of_npr, na.rm = TRUE)
  ),
  by = provider_impact_pct_bucket
][
  ,
  clean_provider_group := "All modeled providers"
][
  ,
  .(
    clean_provider_group,
    provider_impact_pct_bucket,
    providers,
    total_net_patient_revenue,
    total_net_provider_impact,
    median_provider_impact_pct_of_npr
  )
][order(provider_impact_pct_bucket)]

table_7D <- data.table::rbindlist(
  list(table_7D_overall, table_7D),
  fill = TRUE
)

# ============================================================
# 10. Save outputs
# ============================================================

scenario_rds <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_provider_impact_scenarios.rds")
)

basebase_rds <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_provider_impact_basebase_provider_level.rds")
)

table_7A_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_table_7A_provider_impact_3x3_matrix.csv")
)

table_7B_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_table_7B_provider_impact_by_clean_group_basebase.csv")
)

table_7C_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_table_7C_provider_impact_by_clean_class_basebase.csv")
)

table_7D_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_table_7D_provider_level_effect_distribution_basebase.csv")
)

basebase_provider_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_provider_impact_basebase_provider_level.csv")
)

saveRDS(provider_scenarios, scenario_rds)
saveRDS(basebase_provider_level, basebase_rds)

data.table::fwrite(table_7A, table_7A_csv)
data.table::fwrite(table_7B, table_7B_csv)
data.table::fwrite(table_7C, table_7C_csv)
data.table::fwrite(table_7D, table_7D_csv)
data.table::fwrite(basebase_provider_level, basebase_provider_csv)

# ============================================================
# 11. Print summaries
# ============================================================

cat("\n============================================================\n")
cat("PROVIDER IMPACT SCENARIOS COMPLETE\n")
cat("============================================================\n")

cat("\nProvider-impact model inclusion:\n")
print(backbone[
  ,
  .N,
  by = provider_impact_model_include_flag
][order(provider_impact_model_include_flag)])

cat("\nProvider-impact model inclusion by clean provider group:\n")
print(backbone[
  ,
  .N,
  by = .(clean_provider_group, provider_impact_model_include_flag)
][order(clean_provider_group, provider_impact_model_include_flag)])

cat("\nTable 7A. Provider Impact 3x3 Scenario Matrix:\n")
print(table_7A)

cat("\nTable 7B. Provider Impact by Provider Group under Base/Base Scenario:\n")
print(table_7B)

cat("\nTable 7C. Provider Impact by Provider Class under Base/Base Scenario:\n")
print(table_7C)

cat("\nTable 7D. Distribution of Provider-Level Effects under Base/Base Scenario:\n")
print(table_7D)

cat("\nLargest negative provider impacts under Base/Base:\n")
print(basebase_provider_level[
  provider_impact_model_include_flag == TRUE,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    state_abbrev,
    raw_provider_model_class,
    clean_provider_model_class,
    clean_provider_group,
    revenue_source_method,
    net_patient_revenue_model,
    outpatient_exposure_used,
    outpatient_repricing_pressure,
    uncompensated_care_offset,
    stabilization_support,
    net_provider_impact,
    net_provider_impact_pct_of_npr,
    stabilization_tier,
    stabilization_basis
  )
][order(net_provider_impact)][1:50])

cat("\nLargest positive provider impacts under Base/Base:\n")
print(basebase_provider_level[
  provider_impact_model_include_flag == TRUE,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    state_abbrev,
    raw_provider_model_class,
    clean_provider_model_class,
    clean_provider_group,
    revenue_source_method,
    net_patient_revenue_model,
    outpatient_exposure_used,
    outpatient_repricing_pressure,
    uncompensated_care_offset,
    stabilization_support,
    net_provider_impact,
    net_provider_impact_pct_of_npr,
    stabilization_tier,
    stabilization_basis
  )
][order(-net_provider_impact)][1:50])

cat("\nSaved:\n")
cat(scenario_rds, "\n")
cat(basebase_rds, "\n")
cat(table_7A_csv, "\n")
cat(table_7B_csv, "\n")
cat(table_7C_csv, "\n")
cat(table_7D_csv, "\n")
cat(basebase_provider_csv, "\n")

cat("\n============================================================\n")
```

---

# 11A_audit_provider_impact_coverage_and_exposure.R

```r
# Scripts/11A_audit_provider_impact_coverage_and_exposure.R
# Audit provider-impact model coverage and outpatient exposure anomalies.
#
# Purpose:
#   1. Diagnose why Specialty / behavioral / rehab has low model inclusion.
#   2. Audit General acute / academic records for suspicious outpatient exposure.
#   3. Identify revenue records with total/net revenue but missing or implausible OP exposure.
#   4. Find candidate fallback fields from G-family worksheets for excluded or anomalous providers.
#
# Inputs:
#   Processed/hcris_YYYY_provider_master_with_stabilization.rds
#   Processed/hcris_YYYY_provider_impact_basebase_provider_level.rds
#   Processed/hcris_YYYY_nmrc.rds
#
# Outputs:
#   Output/hcris_YYYY_11A_model_inclusion_by_group_class.csv
#   Output/hcris_YYYY_11A_excluded_provider_audit.csv
#   Output/hcris_YYYY_11A_exposure_anomaly_audit.csv
#   Output/hcris_YYYY_11A_gap_provider_g_family_profile.csv
#   Output/hcris_YYYY_11A_alt_revenue_exposure_candidates.csv
#   Output/hcris_YYYY_11A_general_acute_exposure_anomalies.csv
#   Output/hcris_YYYY_11A_specialty_behavioral_rehab_gap_list.csv

source("Scripts/00_setup.R")

cat("\n============================================================\n")
cat("AUDIT PROVIDER IMPACT COVERAGE AND EXPOSURE\n")
cat("============================================================\n")
cat("Build year:", hcris_year_label, "\n\n")

# ============================================================
# 1. Load inputs
# ============================================================

stab_file <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_provider_master_with_stabilization.rds")
)

basebase_file <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_provider_impact_basebase_provider_level.rds")
)

nmrc_file <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_nmrc.rds")
)

if (!file.exists(stab_file)) {
  stop("Missing stabilization file: ", stab_file)
}

if (!file.exists(basebase_file)) {
  stop("Missing base/base provider impact file: ", basebase_file)
}

if (!file.exists(nmrc_file)) {
  stop("Missing NMRC file: ", nmrc_file)
}

stab <- readRDS(stab_file)
basebase <- readRDS(basebase_file)
nmrc <- readRDS(nmrc_file)

cat("Loaded:\n")
cat(stab_file, "\n")
cat(basebase_file, "\n")
cat(nmrc_file, "\n")

# ============================================================
# 2. Safety checks
# ============================================================

required_stab_cols <- c(
  "rpt_rec_num",
  "prvdr_num_chr",
  "provider_name",
  "city",
  "state_abbrev",
  "provider_backbone_include_v1",
  "raw_provider_model_class",
  "clean_provider_model_class",
  "clean_provider_group",
  "revenue_source_method",
  "revenue_use_for_model_flag",
  "gross_total_patient_revenue_model",
  "net_patient_revenue_model",
  "net_outpatient_exposure_base_model",
  "net_outpatient_exposure_low_model",
  "net_outpatient_exposure_high_model",
  "uncompensated_care_cost_model",
  "stabilization_tier",
  "stabilization_eligible_bounded_flag"
)

required_base_cols <- c(
  "rpt_rec_num",
  "provider_impact_model_include_flag",
  "outpatient_exposure_used",
  "net_patient_revenue_model",
  "gross_total_patient_revenue_model",
  "net_provider_impact",
  "net_provider_impact_pct_of_npr"
)

required_nmrc_cols <- c(
  "rpt_rec_num",
  "wksht_cd",
  "line_num_chr",
  "clmn_num_chr",
  "itm_val_num"
)

missing_stab <- setdiff(required_stab_cols, names(stab))
missing_base <- setdiff(required_base_cols, names(basebase))
missing_nmrc <- setdiff(required_nmrc_cols, names(nmrc))

if (length(missing_stab) > 0) {
  stop("Stabilization file missing required columns:\n", paste(missing_stab, collapse = "\n"))
}

if (length(missing_base) > 0) {
  stop("Base/base file missing required columns:\n", paste(missing_base, collapse = "\n"))
}

if (length(missing_nmrc) > 0) {
  stop("NMRC file missing required columns:\n", paste(missing_nmrc, collapse = "\n"))
}

# ============================================================
# 3. Model inclusion audit
# ============================================================

audit <- copy(stab[provider_backbone_include_v1 == TRUE])

audit[
  ,
  provider_impact_model_include_flag :=
    revenue_use_for_model_flag == TRUE &
    !is.na(net_patient_revenue_model) &
    net_patient_revenue_model > 0
]

audit[
  ,
  net_outpatient_exposure_to_npr_ratio :=
    data.table::fifelse(
      !is.na(net_patient_revenue_model) &
        net_patient_revenue_model > 0 &
        !is.na(net_outpatient_exposure_base_model),
      net_outpatient_exposure_base_model / net_patient_revenue_model,
      NA_real_
    )
]

audit[
  ,
  net_outpatient_exposure_to_gross_ratio :=
    data.table::fifelse(
      !is.na(gross_total_patient_revenue_model) &
        gross_total_patient_revenue_model > 0 &
        !is.na(net_outpatient_exposure_base_model),
      net_outpatient_exposure_base_model / gross_total_patient_revenue_model,
      NA_real_
    )
]

audit[
  ,
  revenue_present_but_not_model_flag :=
    revenue_use_for_model_flag == FALSE &
    (
      (!is.na(net_patient_revenue_model) & net_patient_revenue_model > 0) |
        (!is.na(gross_total_patient_revenue_model) & gross_total_patient_revenue_model > 0)
    )
]

audit[
  ,
  exposure_missing_or_zero_flag :=
    revenue_use_for_model_flag == TRUE &
    (
      is.na(net_outpatient_exposure_base_model) |
        net_outpatient_exposure_base_model <= 0
    )
]

audit[
  ,
  low_exposure_ratio_flag :=
    revenue_use_for_model_flag == TRUE &
    !is.na(net_outpatient_exposure_to_npr_ratio) &
    net_outpatient_exposure_to_npr_ratio < 0.005
]

audit[
  ,
  very_low_exposure_ratio_flag :=
    revenue_use_for_model_flag == TRUE &
    !is.na(net_outpatient_exposure_to_npr_ratio) &
    net_outpatient_exposure_to_npr_ratio < 0.001
]

audit[
  ,
  high_exposure_ratio_flag :=
    revenue_use_for_model_flag == TRUE &
    !is.na(net_outpatient_exposure_to_npr_ratio) &
    net_outpatient_exposure_to_npr_ratio > 0.90
]

audit[
  ,
  exposure_anomaly_flag :=
    exposure_missing_or_zero_flag |
    low_exposure_ratio_flag |
    high_exposure_ratio_flag
]

inclusion_summary <- audit[
  ,
  .(
    providers = .N,
    model_included = sum(provider_impact_model_include_flag, na.rm = TRUE),
    model_excluded = sum(!provider_impact_model_include_flag, na.rm = TRUE),
    revenue_use_for_model = sum(revenue_use_for_model_flag, na.rm = TRUE),
    revenue_present_but_not_model = sum(revenue_present_but_not_model_flag, na.rm = TRUE),
    exposure_missing_or_zero = sum(exposure_missing_or_zero_flag, na.rm = TRUE),
    low_exposure_ratio = sum(low_exposure_ratio_flag, na.rm = TRUE),
    very_low_exposure_ratio = sum(very_low_exposure_ratio_flag, na.rm = TRUE),
    high_exposure_ratio = sum(high_exposure_ratio_flag, na.rm = TRUE),
    exposure_anomaly = sum(exposure_anomaly_flag, na.rm = TRUE),
    total_net_patient_revenue = sum(net_patient_revenue_model, na.rm = TRUE),
    total_gross_patient_revenue = sum(gross_total_patient_revenue_model, na.rm = TRUE),
    total_net_outpatient_exposure = sum(net_outpatient_exposure_base_model, na.rm = TRUE)
  ),
  by = .(
    clean_provider_group,
    clean_provider_model_class,
    revenue_source_method
  )
][order(clean_provider_group, clean_provider_model_class, revenue_source_method)]

cat("\nModel inclusion by clean group / class / revenue source:\n")
print(inclusion_summary)

inclusion_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_11A_model_inclusion_by_group_class.csv")
)

data.table::fwrite(inclusion_summary, inclusion_csv)

# ============================================================
# 4. Excluded provider audit
# ============================================================

excluded_provider_audit <- audit[
  provider_impact_model_include_flag == FALSE,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    city,
    state_abbrev,
    raw_provider_model_class,
    clean_provider_model_class,
    clean_provider_group,
    revenue_source_method,
    revenue_use_for_model_flag,
    gross_total_patient_revenue_model,
    net_patient_revenue_model,
    net_outpatient_exposure_base_model,
    net_outpatient_exposure_to_npr_ratio,
    net_outpatient_exposure_to_gross_ratio,
    revenue_present_but_not_model_flag,
    exposure_missing_or_zero_flag,
    low_exposure_ratio_flag,
    high_exposure_ratio_flag,
    uncompensated_care_cost_model,
    stabilization_tier,
    stabilization_eligible_bounded_flag
  )
][order(clean_provider_group, clean_provider_model_class, revenue_source_method, -gross_total_patient_revenue_model)]

cat("\nExcluded providers by clean group / class / revenue source:\n")
print(excluded_provider_audit[
  ,
  .N,
  by = .(clean_provider_group, clean_provider_model_class, revenue_source_method)
][order(clean_provider_group, clean_provider_model_class, -N)])

excluded_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_11A_excluded_provider_audit.csv")
)

data.table::fwrite(excluded_provider_audit, excluded_csv)

# ============================================================
# 5. Exposure anomaly audit
# ============================================================

exposure_anomaly_audit <- audit[
  revenue_use_for_model_flag == TRUE &
    exposure_anomaly_flag == TRUE,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    city,
    state_abbrev,
    raw_provider_model_class,
    clean_provider_model_class,
    clean_provider_group,
    revenue_source_method,
    gross_total_patient_revenue_model,
    net_patient_revenue_model,
    net_outpatient_exposure_base_model,
    net_outpatient_exposure_to_npr_ratio,
    net_outpatient_exposure_to_gross_ratio,
    exposure_missing_or_zero_flag,
    low_exposure_ratio_flag,
    very_low_exposure_ratio_flag,
    high_exposure_ratio_flag,
    uncompensated_care_cost_model,
    stabilization_tier
  )
][order(clean_provider_group, clean_provider_model_class, net_outpatient_exposure_to_npr_ratio)]

cat("\nExposure anomalies by clean group / class / revenue source:\n")
print(exposure_anomaly_audit[
  ,
  .N,
  by = .(clean_provider_group, clean_provider_model_class, revenue_source_method)
][order(clean_provider_group, clean_provider_model_class, -N)])

cat("\nGeneral acute / academic exposure anomalies:\n")
print(exposure_anomaly_audit[
  clean_provider_group == "General acute / academic"
][1:100])

exposure_anomaly_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_11A_exposure_anomaly_audit.csv")
)

general_acute_anomaly_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_11A_general_acute_exposure_anomalies.csv")
)

data.table::fwrite(exposure_anomaly_audit, exposure_anomaly_csv)
data.table::fwrite(
  exposure_anomaly_audit[clean_provider_group == "General acute / academic"],
  general_acute_anomaly_csv
)

# ============================================================
# 6. Specialty / behavioral / rehab gap list
# ============================================================

specialty_gap <- audit[
  clean_provider_group == "Specialty / behavioral / rehab" &
    provider_impact_model_include_flag == FALSE,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    city,
    state_abbrev,
    raw_provider_model_class,
    clean_provider_model_class,
    revenue_source_method,
    revenue_use_for_model_flag,
    gross_total_patient_revenue_model,
    net_patient_revenue_model,
    net_outpatient_exposure_base_model,
    revenue_present_but_not_model_flag,
    exposure_missing_or_zero_flag,
    net_outpatient_exposure_to_npr_ratio,
    uncompensated_care_cost_model,
    stabilization_tier
  )
][order(clean_provider_model_class, revenue_source_method, -gross_total_patient_revenue_model)]

cat("\nSpecialty / behavioral / rehab gap list summary:\n")
print(specialty_gap[
  ,
  .N,
  by = .(clean_provider_model_class, revenue_source_method)
][order(clean_provider_model_class, -N)])

specialty_gap_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_11A_specialty_behavioral_rehab_gap_list.csv")
)

data.table::fwrite(specialty_gap, specialty_gap_csv)

# ============================================================
# 7. Pull G-family rows for gap/anomaly providers
# ============================================================

gap_report_ids <- unique(c(
  excluded_provider_audit$rpt_rec_num,
  exposure_anomaly_audit$rpt_rec_num
))

gap_g_long <- nmrc[
  rpt_rec_num %in% gap_report_ids &
    stringr::str_detect(wksht_cd, "^G") &
    !is.na(itm_val_num),
  .(
    rpt_rec_num,
    wksht_cd,
    line_num_chr,
    clmn_num_chr,
    itm_val_num
  )
]

gap_g_long <- merge(
  gap_g_long,
  audit[
    ,
    .(
      rpt_rec_num,
      prvdr_num_chr,
      provider_name,
      city,
      state_abbrev,
      raw_provider_model_class,
      clean_provider_model_class,
      clean_provider_group,
      revenue_source_method,
      revenue_use_for_model_flag,
      provider_impact_model_include_flag,
      net_patient_revenue_model,
      gross_total_patient_revenue_model,
      net_outpatient_exposure_base_model,
      net_outpatient_exposure_to_npr_ratio,
      exposure_anomaly_flag
    )
  ],
  by = "rpt_rec_num",
  all.x = TRUE
)

cat("\nGap/anomaly providers with any G-family numeric data:", uniqueN(gap_g_long$rpt_rec_num), "\n")
cat("Gap/anomaly providers total:", length(gap_report_ids), "\n")

# ============================================================
# 8. G-family profile for gap/anomaly providers
# ============================================================

gap_g_profile <- gap_g_long[
  ,
  .(
    n_rows = .N,
    n_reports = uniqueN(rpt_rec_num),
    nonzero_reports = uniqueN(rpt_rec_num[itm_val_num != 0]),
    min_value = suppressWarnings(min(itm_val_num, na.rm = TRUE)),
    p25_value = suppressWarnings(as.numeric(quantile(itm_val_num, 0.25, na.rm = TRUE))),
    median_value = suppressWarnings(median(itm_val_num, na.rm = TRUE)),
    mean_value = suppressWarnings(mean(itm_val_num, na.rm = TRUE)),
    p75_value = suppressWarnings(as.numeric(quantile(itm_val_num, 0.75, na.rm = TRUE))),
    max_value = suppressWarnings(max(itm_val_num, na.rm = TRUE)),
    total_value = sum(itm_val_num, na.rm = TRUE)
  ),
  by = .(
    clean_provider_group,
    clean_provider_model_class,
    revenue_source_method,
    wksht_cd,
    line_num_chr,
    clmn_num_chr
  )
][order(clean_provider_group, clean_provider_model_class, revenue_source_method, wksht_cd, line_num_chr, clmn_num_chr)]

for (cc in c("min_value", "p25_value", "median_value", "mean_value", "p75_value", "max_value")) {
  gap_g_profile[
    is.infinite(get(cc)),
    (cc) := NA_real_
  ]
}

gap_profile_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_11A_gap_provider_g_family_profile.csv")
)

data.table::fwrite(gap_g_profile, gap_profile_csv)

cat("\nG-family profile for Specialty / behavioral / rehab gap/anomaly providers:\n")
print(gap_g_profile[
  clean_provider_group == "Specialty / behavioral / rehab"
][1:300])

cat("\nG-family profile for General acute / academic exposure anomalies:\n")
print(gap_g_profile[
  clean_provider_group == "General acute / academic"
][1:300])

# ============================================================
# 9. Alternative revenue/exposure candidate fields
# ============================================================

alt_candidates <- gap_g_profile[
  n_reports >= 3 &
    median_value > 100000,
  .(
    clean_provider_group,
    clean_provider_model_class,
    revenue_source_method,
    wksht_cd,
    line_num_chr,
    clmn_num_chr,
    n_reports,
    median_value,
    mean_value,
    total_value,
    min_value,
    max_value
  )
][order(clean_provider_group, clean_provider_model_class, revenue_source_method, -n_reports, -median_value)]

cat("\nAlternative revenue/exposure candidate fields for gaps/anomalies:\n")
print(alt_candidates[1:400])

alt_candidates_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_11A_alt_revenue_exposure_candidates.csv")
)

data.table::fwrite(alt_candidates, alt_candidates_csv)

# ============================================================
# 10. Suggested provider-level audit category
# ============================================================

audit[
  ,
  audit_recommendation := data.table::fcase(
    clean_provider_group == "Specialty / behavioral / rehab" &
      provider_impact_model_include_flag == FALSE &
      revenue_present_but_not_model_flag == TRUE,
    "Specialty fallback candidate - revenue present but no model exposure",
    
    clean_provider_group == "Specialty / behavioral / rehab" &
      provider_impact_model_include_flag == FALSE,
    "Specialty missing revenue/exposure - inspect G-family profile",
    
    clean_provider_group == "General acute / academic" &
      exposure_anomaly_flag == TRUE,
    "General acute exposure anomaly - inspect G2 OP split",
    
    exposure_anomaly_flag == TRUE,
    "Non-general exposure anomaly - inspect G2 OP split",
    
    provider_impact_model_include_flag == FALSE,
    "Excluded from model - inspect revenue availability",
    
    default = "No immediate audit issue"
  )
]

audit_recommendation_summary <- audit[
  ,
  .N,
  by = .(clean_provider_group, audit_recommendation)
][order(clean_provider_group, -N)]

cat("\nAudit recommendation summary:\n")
print(audit_recommendation_summary)

# ============================================================
# 11. Save and finish
# ============================================================

cat("\nSaved:\n")
cat(inclusion_csv, "\n")
cat(excluded_csv, "\n")
cat(exposure_anomaly_csv, "\n")
cat(general_acute_anomaly_csv, "\n")
cat(specialty_gap_csv, "\n")
cat(gap_profile_csv, "\n")
cat(alt_candidates_csv, "\n")

cat("\n============================================================\n")
cat("Coverage/exposure audit complete.\n")
cat("============================================================\n")
```

---

# 12_format_table7_publication_outputs.R

```r
# Scripts/12_format_table7_publication_outputs.R
# Format corrected UCC/HSE provider-impact model outputs into publication-ready Table 7 files.
#
# Purpose:
#   This script does NOT rebuild the model.
#   It reads the already-corrected Script 11 / 11A outputs and exports clean,
#   publication-oriented Table 7 files.
#
# Required current model state:
#   - HCRIS FY2024 backbone providers: 912
#   - Modeled providers: corrected model should be approximately 886 / 912
#   - No model-used net-to-gross outliers > 1.50
#   - Corrected fallback method names should include:
#       nonstandard_g200000_l04300_fallback
#       nonstandard_fallback_failed_plausibility
#
# Inputs:
#   Output/hcris_YYYY_table_7A_provider_impact_3x3_matrix.csv
#   Output/hcris_YYYY_table_7B_provider_impact_by_clean_group_basebase.csv
#   Output/hcris_YYYY_table_7C_provider_impact_by_clean_class_basebase.csv
#   Output/hcris_YYYY_table_7D_provider_level_effect_distribution_basebase.csv
#   Output/hcris_YYYY_11A_model_inclusion_by_group_class.csv
#   Output/hcris_YYYY_11A_exposure_anomaly_audit.csv
#   Output/hcris_YYYY_provider_impact_basebase_provider_level.csv
#   Output/hcris_YYYY_provider_master_with_financials.csv
#
# Outputs:
#   Output/Table7_Publication/table_7A_publication.csv
#   Output/Table7_Publication/table_7B_publication.csv
#   Output/Table7_Publication/table_7C_publication.csv
#   Output/Table7_Publication/table_7D_publication.csv
#   Output/Table7_Publication/table_7E_model_coverage_audit.csv
#   Output/Table7_Publication/table_7F_exposure_anomaly_sensitivity.csv
#   Output/Table7_Publication/table_7_methodology_notes.txt
#   Output/Table7_Publication/table_7_data_state_freeze_summary.txt
#   Output/Table7_Publication/table_7_all_publication_tables.xlsx
#
# Optional Excel export:
#   Requires openxlsx. If missing, CSV/TXT outputs are still written.

source("Scripts/00_setup.R")

cat("\n============================================================\n")
cat("FORMAT TABLE 7 PUBLICATION OUTPUTS\n")
cat("============================================================\n")
cat("Build year:", hcris_year_label, "\n\n")

# ============================================================
# 0. Output folder
# ============================================================

table7_dir <- file.path(path_output, "Table7_Publication")

if (!dir.exists(table7_dir)) {
  dir.create(table7_dir, recursive = TRUE)
}

cat("Publication output folder:\n")
cat(table7_dir, "\n\n")

# ============================================================
# 1. Input file paths
# ============================================================

table_7A_file <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_table_7A_provider_impact_3x3_matrix.csv")
)

table_7B_file <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_table_7B_provider_impact_by_clean_group_basebase.csv")
)

table_7C_file <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_table_7C_provider_impact_by_clean_class_basebase.csv")
)

table_7D_file <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_table_7D_provider_level_effect_distribution_basebase.csv")
)

inclusion_file <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_11A_model_inclusion_by_group_class.csv")
)

exposure_anomaly_file <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_11A_exposure_anomaly_audit.csv")
)

basebase_provider_file <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_provider_impact_basebase_provider_level.csv")
)

provider_financials_file <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_provider_master_with_financials.csv")
)

required_files <- c(
  table_7A_file,
  table_7B_file,
  table_7C_file,
  table_7D_file,
  inclusion_file,
  exposure_anomaly_file,
  basebase_provider_file,
  provider_financials_file
)

missing_files <- required_files[!file.exists(required_files)]

if (length(missing_files) > 0) {
  stop(
    "Missing required input files. Rerun Scripts 08, 09, 10, 11, and 11A first:\n",
    paste(missing_files, collapse = "\n")
  )
}

# ============================================================
# 2. Read inputs
# ============================================================

table_7A_raw <- data.table::fread(table_7A_file)
table_7B_raw <- data.table::fread(table_7B_file)
table_7C_raw <- data.table::fread(table_7C_file)
table_7D_raw <- data.table::fread(table_7D_file)
inclusion_raw <- data.table::fread(inclusion_file)
exposure_anomaly_raw <- data.table::fread(exposure_anomaly_file)
basebase_provider_raw <- data.table::fread(basebase_provider_file)
provider_financials_raw <- data.table::fread(provider_financials_file)

cat("Loaded input rows:\n")
cat("Table 7A:", nrow(table_7A_raw), "\n")
cat("Table 7B:", nrow(table_7B_raw), "\n")
cat("Table 7C:", nrow(table_7C_raw), "\n")
cat("Table 7D:", nrow(table_7D_raw), "\n")
cat("Inclusion audit:", nrow(inclusion_raw), "\n")
cat("Exposure anomaly audit:", nrow(exposure_anomaly_raw), "\n")
cat("Base/base provider-level:", nrow(basebase_provider_raw), "\n")
cat("Provider financials:", nrow(provider_financials_raw), "\n\n")

# ============================================================
# 3. Helper functions
# ============================================================

billion <- function(x) {
  round(as.numeric(x) / 1e9, 2)
}

million <- function(x) {
  round(as.numeric(x) / 1e6, 1)
}

pct1 <- function(x) {
  round(as.numeric(x) * 100, 1)
}

pct2 <- function(x) {
  round(as.numeric(x) * 100, 2)
}

num0 <- function(x) {
  as.integer(round(as.numeric(x), 0))
}

num1 <- function(x) {
  round(as.numeric(x), 1)
}

num2 <- function(x) {
  round(as.numeric(x), 2)
}

safe_sum <- function(x) {
  sum(as.numeric(x), na.rm = TRUE)
}

safe_div <- function(num, den) {
  ifelse(!is.na(den) & den != 0, num / den, NA_real_)
}

# ============================================================
# 4. Safety checks on corrected model state
# ============================================================

if (!"revenue_source_method" %in% names(provider_financials_raw)) {
  stop("provider_financials_raw missing revenue_source_method")
}

if (!"revenue_use_for_model_flag" %in% names(provider_financials_raw)) {
  stop("provider_financials_raw missing revenue_use_for_model_flag")
}

if (!"provider_backbone_include_v1" %in% names(provider_financials_raw)) {
  stop("provider_financials_raw missing provider_backbone_include_v1")
}

provider_financials_raw[
  ,
  revenue_use_for_model_flag := as.logical(revenue_use_for_model_flag)
]

provider_financials_raw[
  ,
  provider_backbone_include_v1 := as.logical(provider_backbone_include_v1)
]

# Confirm corrected fallback naming exists.
source_methods <- sort(unique(provider_financials_raw$revenue_source_method))

old_specialty_method_present <- "specialty_g200000_l04300_fallback" %in% source_methods
corrected_nonstandard_method_present <- "nonstandard_g200000_l04300_fallback" %in% source_methods
failed_plausibility_method_present <- "nonstandard_fallback_failed_plausibility" %in% source_methods

if (old_specialty_method_present) {
  warning(
    "Old fallback name 'specialty_g200000_l04300_fallback' is present. ",
    "This suggests the old Script 8 may have been used. Confirm before publication."
  )
}

if (!corrected_nonstandard_method_present) {
  warning(
    "Corrected fallback name 'nonstandard_g200000_l04300_fallback' was not found. ",
    "Confirm that corrected Script 8 was run."
  )
}

# Model-used net-to-gross outlier check.
model_used_net_to_gross_outliers <- provider_financials_raw[
  provider_backbone_include_v1 == TRUE &
    revenue_use_for_model_flag == TRUE &
    !is.na(net_to_gross_ratio) &
    (net_to_gross_ratio <= 0 | net_to_gross_ratio > 1.50)
]

if (nrow(model_used_net_to_gross_outliers) > 0) {
  warning(
    "There are model-used net-to-gross outliers <=0 or >1.50. ",
    "Do not treat Table 7 as final until these are resolved."
  )
}

# ============================================================
# 5. Table 7A publication formatting
# ============================================================

required_7A_cols <- c(
  "repricing_scenario",
  "stabilization_scenario",
  "providers_in_model",
  "total_outpatient_exposure_used",
  "total_outpatient_repricing_pressure",
  "total_uncompensated_care_offset",
  "total_stabilization_support",
  "total_net_provider_impact",
  "net_impact_pct_of_total_npr",
  "providers_negative_net_impact",
  "providers_large_negative_net_impact",
  "median_provider_impact_pct_of_npr"
)

missing_7A <- setdiff(required_7A_cols, names(table_7A_raw))
if (length(missing_7A) > 0) {
  stop("Table 7A raw file missing columns:\n", paste(missing_7A, collapse = "\n"))
}

table_7A_pub <- table_7A_raw[
  ,
  .(
    `Repricing Scenario` = repricing_scenario,
    `Stabilization Scenario` = stabilization_scenario,
    `Modeled Providers` = num0(providers_in_model),
    `Outpatient/Routine Exposure ($B)` = billion(total_outpatient_exposure_used),
    `Repricing Pressure ($B)` = billion(total_outpatient_repricing_pressure),
    `UC / Liquidity Offset ($B)` = billion(total_uncompensated_care_offset),
    `Stabilization Support ($B)` = billion(total_stabilization_support),
    `Net Provider Impact ($B)` = billion(total_net_provider_impact),
    `Net Impact (% of NPR)` = pct1(net_impact_pct_of_total_npr),
    `Negative-Impact Providers` = num0(providers_negative_net_impact),
    `Large Negative-Impact Providers` = num0(providers_large_negative_net_impact),
    `Median Provider Impact (% of NPR)` = pct1(median_provider_impact_pct_of_npr)
  )
]

# ============================================================
# 6. Table 7B publication formatting
# ============================================================

required_7B_cols <- c(
  "clean_provider_group",
  "providers",
  "providers_in_model",
  "total_net_patient_revenue",
  "total_outpatient_exposure_used",
  "total_outpatient_repricing_pressure",
  "total_uncompensated_care_offset",
  "total_stabilization_support",
  "total_net_provider_impact",
  "net_impact_pct_of_total_npr",
  "providers_negative_net_impact",
  "providers_large_negative_net_impact",
  "stabilization_eligible"
)

missing_7B <- setdiff(required_7B_cols, names(table_7B_raw))
if (length(missing_7B) > 0) {
  stop("Table 7B raw file missing columns:\n", paste(missing_7B, collapse = "\n"))
}

table_7B_pub <- table_7B_raw[
  ,
  .(
    `Provider Group` = clean_provider_group,
    `Providers` = num0(providers),
    `Modeled Providers` = num0(providers_in_model),
    `Net Patient Revenue ($B)` = billion(total_net_patient_revenue),
    `Outpatient/Routine Exposure ($B)` = billion(total_outpatient_exposure_used),
    `Repricing Pressure ($B)` = billion(total_outpatient_repricing_pressure),
    `UC / Liquidity Offset ($B)` = billion(total_uncompensated_care_offset),
    `Stabilization Support ($B)` = billion(total_stabilization_support),
    `Net Provider Impact ($B)` = billion(total_net_provider_impact),
    `Net Impact (% of NPR)` = pct1(net_impact_pct_of_total_npr),
    `Negative-Impact Providers` = num0(providers_negative_net_impact),
    `Large Negative-Impact Providers` = num0(providers_large_negative_net_impact),
    `Stabilization-Eligible Providers` = num0(stabilization_eligible)
  )
][order(`Provider Group`)]

# ============================================================
# 7. Table 7C publication formatting
# ============================================================

required_7C_cols <- c(
  "clean_provider_group",
  "clean_provider_model_class",
  "providers",
  "providers_in_model",
  "total_net_patient_revenue",
  "total_outpatient_exposure_used",
  "total_outpatient_repricing_pressure",
  "total_uncompensated_care_offset",
  "total_stabilization_support",
  "total_net_provider_impact",
  "net_impact_pct_of_total_npr",
  "providers_negative_net_impact",
  "providers_large_negative_net_impact",
  "stabilization_eligible"
)

missing_7C <- setdiff(required_7C_cols, names(table_7C_raw))
if (length(missing_7C) > 0) {
  stop("Table 7C raw file missing columns:\n", paste(missing_7C, collapse = "\n"))
}

table_7C_pub <- table_7C_raw[
  ,
  .(
    `Provider Group` = clean_provider_group,
    `Provider Class` = clean_provider_model_class,
    `Providers` = num0(providers),
    `Modeled Providers` = num0(providers_in_model),
    `Net Patient Revenue ($B)` = billion(total_net_patient_revenue),
    `Outpatient/Routine Exposure ($B)` = billion(total_outpatient_exposure_used),
    `Repricing Pressure ($B)` = billion(total_outpatient_repricing_pressure),
    `UC / Liquidity Offset ($B)` = billion(total_uncompensated_care_offset),
    `Stabilization Support ($B)` = billion(total_stabilization_support),
    `Net Provider Impact ($B)` = billion(total_net_provider_impact),
    `Net Impact (% of NPR)` = pct1(net_impact_pct_of_total_npr),
    `Negative-Impact Providers` = num0(providers_negative_net_impact),
    `Large Negative-Impact Providers` = num0(providers_large_negative_net_impact),
    `Stabilization-Eligible Providers` = num0(stabilization_eligible)
  )
][order(`Provider Group`, `Provider Class`)]

# ============================================================
# 8. Table 7D publication formatting
# ============================================================

required_7D_cols <- c(
  "clean_provider_group",
  "provider_impact_pct_bucket",
  "providers",
  "total_net_patient_revenue",
  "total_net_provider_impact",
  "median_provider_impact_pct_of_npr"
)

missing_7D <- setdiff(required_7D_cols, names(table_7D_raw))
if (length(missing_7D) > 0) {
  stop("Table 7D raw file missing columns:\n", paste(missing_7D, collapse = "\n"))
}

table_7D_pub <- table_7D_raw[
  ,
  .(
    `Provider Group` = clean_provider_group,
    `Provider Impact Bucket (% of NPR)` = as.character(provider_impact_pct_bucket),
    `Providers` = num0(providers),
    `Net Patient Revenue ($B)` = billion(total_net_patient_revenue),
    `Net Provider Impact ($B)` = billion(total_net_provider_impact),
    `Median Provider Impact (% of NPR)` = pct1(median_provider_impact_pct_of_npr)
  )
][order(`Provider Group`, `Provider Impact Bucket (% of NPR)`)]

# ============================================================
# 9. Table 7E — Model coverage and data quality audit
# ============================================================

provider_fin_backbone <- provider_financials_raw[provider_backbone_include_v1 == TRUE]

backbone_providers <- nrow(provider_fin_backbone)
modeled_providers <- provider_fin_backbone[revenue_use_for_model_flag == TRUE, .N]
excluded_providers <- provider_fin_backbone[revenue_use_for_model_flag == FALSE, .N]
modeled_share <- safe_div(modeled_providers, backbone_providers)

source_method_counts <- provider_fin_backbone[
  ,
  .(providers = .N),
  by = revenue_source_method
]

get_method_count <- function(method_name) {
  val <- source_method_counts[revenue_source_method == method_name, providers]
  if (length(val) == 0) return(0L)
  as.integer(val[1])
}

standard_g2_split_records <- get_method_count("standard_g2_l028_split")
rural_fallback_records <- get_method_count("rural_g200000_l04300_fallback")
children_fallback_records <- get_method_count("children_total_only_fallback")
nonstandard_fallback_records <- get_method_count("nonstandard_g200000_l04300_fallback")
failed_plausibility_records <- get_method_count("nonstandard_fallback_failed_plausibility")
g2_total_only_records <- get_method_count("g2_total_only_no_outpatient_split")
missing_unusable_records <- get_method_count("missing_or_unusable")
old_specialty_fallback_records <- get_method_count("specialty_g200000_l04300_fallback")

model_used_net_to_gross_outlier_count <- nrow(model_used_net_to_gross_outliers)

exposure_anomaly_count <- nrow(exposure_anomaly_raw)

# If the anomaly file includes revenue/model flags, create a more specific count.
if (all(c("revenue_use_for_model_flag", "exposure_anomaly_flag") %in% names(exposure_anomaly_raw))) {
  exposure_anomaly_modeled_count <- exposure_anomaly_raw[
    as.logical(revenue_use_for_model_flag) == TRUE,
    .N
  ]
} else {
  exposure_anomaly_modeled_count <- exposure_anomaly_count
}

# Inclusion by clean group directly from base/base provider file.
if (!all(c("clean_provider_group", "provider_impact_model_include_flag") %in% names(basebase_provider_raw))) {
  stop("Base/base provider-level file missing clean_provider_group or provider_impact_model_include_flag")
}

basebase_provider_raw[
  ,
  provider_impact_model_include_flag := as.logical(provider_impact_model_include_flag)
]

coverage_by_group <- basebase_provider_raw[
  ,
  .(
    backbone_providers = .N,
    modeled_providers = sum(provider_impact_model_include_flag, na.rm = TRUE),
    excluded_providers = sum(!provider_impact_model_include_flag, na.rm = TRUE)
  ),
  by = clean_provider_group
][
  ,
  modeled_share := safe_div(modeled_providers, backbone_providers)
][order(clean_provider_group)]

table_7E_overall <- data.table::data.table(
  `Audit Item` = c(
    "Backbone providers",
    "Modeled providers",
    "Excluded providers",
    "Modeled share",
    "Standard G-2 split records",
    "Rural fallback records",
    "Children's fallback records",
    "Nonstandard fallback records",
    "Nonstandard fallback failed plausibility records",
    "G-2 total-only / no outpatient split records",
    "Missing or unusable records",
    "Old specialty fallback records present",
    "Model-used net-to-gross outliers <=0 or >1.50",
    "Exposure anomaly records",
    "Modeled exposure anomaly records"
  ),
  `Value` = c(
    as.character(backbone_providers),
    as.character(modeled_providers),
    as.character(excluded_providers),
    paste0(pct1(modeled_share), "%"),
    as.character(standard_g2_split_records),
    as.character(rural_fallback_records),
    as.character(children_fallback_records),
    as.character(nonstandard_fallback_records),
    as.character(failed_plausibility_records),
    as.character(g2_total_only_records),
    as.character(missing_unusable_records),
    as.character(old_specialty_fallback_records),
    as.character(model_used_net_to_gross_outlier_count),
    as.character(exposure_anomaly_count),
    as.character(exposure_anomaly_modeled_count)
  )
)

table_7E_group <- coverage_by_group[
  ,
  .(
    `Provider Group` = clean_provider_group,
    `Backbone Providers` = num0(backbone_providers),
    `Modeled Providers` = num0(modeled_providers),
    `Excluded Providers` = num0(excluded_providers),
    `Modeled Share (%)` = pct1(modeled_share)
  )
]

# A long combined audit table for CSV readability.
table_7E_pub <- data.table::rbindlist(
  list(
    data.table::data.table(
      `Section` = "Overall data-state audit",
      `Metric` = table_7E_overall$`Audit Item`,
      `Value` = table_7E_overall$Value
    ),
    data.table::data.table(
      `Section` = "Coverage by clean provider group",
      `Metric` = table_7E_group$`Provider Group`,
      `Value` = paste0(
        table_7E_group$`Modeled Providers`,
        " / ",
        table_7E_group$`Backbone Providers`,
        " modeled (",
        table_7E_group$`Modeled Share (%)`,
        "%)"
      )
    )
  ),
  fill = TRUE
)

# ============================================================
# 10. Table 7F — exposure anomaly sensitivity
# ============================================================

# This is not the main table. It is a sensitivity / appendix export showing
# whether flagged OP exposure anomalies materially change the Base/Base totals.

basebase <- copy(basebase_provider_raw)

needed_sensitivity_cols <- c(
  "provider_impact_model_include_flag",
  "rpt_rec_num",
  "net_patient_revenue_model",
  "outpatient_exposure_used",
  "outpatient_repricing_pressure",
  "uncompensated_care_offset",
  "stabilization_support",
  "net_provider_impact",
  "net_provider_impact_pct_of_npr"
)

missing_sens <- setdiff(needed_sensitivity_cols, names(basebase))
if (length(missing_sens) > 0) {
  stop("Base/base file missing sensitivity columns:\n", paste(missing_sens, collapse = "\n"))
}

# Identify anomaly report IDs from 11A.
if ("rpt_rec_num" %in% names(exposure_anomaly_raw)) {
  anomaly_ids <- unique(exposure_anomaly_raw$rpt_rec_num)
} else {
  anomaly_ids <- integer(0)
}

basebase[
  ,
  exposure_anomaly_from_11A_flag := rpt_rec_num %in% anomaly_ids
]

make_sensitivity_row <- function(dt, label) {
  dt_model <- dt[provider_impact_model_include_flag == TRUE]
  data.table::data.table(
    `Sensitivity Case` = label,
    `Modeled Providers` = nrow(dt_model),
    `Net Patient Revenue ($B)` = billion(safe_sum(dt_model$net_patient_revenue_model)),
    `Outpatient/Routine Exposure ($B)` = billion(safe_sum(dt_model$outpatient_exposure_used)),
    `Repricing Pressure ($B)` = billion(safe_sum(dt_model$outpatient_repricing_pressure)),
    `UC / Liquidity Offset ($B)` = billion(safe_sum(dt_model$uncompensated_care_offset)),
    `Stabilization Support ($B)` = billion(safe_sum(dt_model$stabilization_support)),
    `Net Provider Impact ($B)` = billion(safe_sum(dt_model$net_provider_impact)),
    `Net Impact (% of NPR)` = pct1(
      safe_div(
        safe_sum(dt_model$net_provider_impact),
        safe_sum(dt_model$net_patient_revenue_model)
      )
    ),
    `Median Provider Impact (% of NPR)` = pct1(median(dt_model$net_provider_impact_pct_of_npr, na.rm = TRUE))
  )
}

table_7F_pub <- data.table::rbindlist(
  list(
    make_sensitivity_row(basebase, "Base/Base - all modeled providers"),
    make_sensitivity_row(basebase[exposure_anomaly_from_11A_flag == FALSE], "Base/Base - excluding 11A exposure anomalies")
  ),
  fill = TRUE
)

# ============================================================
# 11. Methodology notes
# ============================================================

methodology_notes <- c(
  "Table 7 methodology notes",
  "========================",
  "",
  paste0("Build year: ", hcris_year_label),
  paste0("Generated: ", Sys.time()),
  "",
  "Provider impact was estimated using FY2024 HCRIS hospital cost-report data.",
  "The model uses Worksheet G-2 and G-3 revenue fields to identify net patient revenue and outpatient/routine-care exposure.",
  "Standard acute hospitals were modeled using direct inpatient/outpatient revenue splits where available.",
  "For rural primary care, pediatric, and nonstandard specialty/behavioral/rehab-like records without validated outpatient splits, the model applies bounded fallback exposure assumptions.",
  "Providers were reclassified into cleaned analytical groups before scoring to avoid treating raw CAH-labeled records as true critical access hospitals when internal size, revenue, or name-based screens indicated academic, psychiatric, specialty, or other non-CAH status.",
  "Stabilization support is modeled as temporary, bounded transition protection based on cleaned provider class and uncompensated-care burden.",
  "Provisional operating-margin fields are retained for diagnostics but are not used to assign stabilization tiers.",
  "",
  "Core formula:",
  "Net Provider Impact = - Outpatient Repricing Pressure + UC/Liquidity Offset + Bounded Stabilization Support",
  "",
  "Definitions:",
  "Outpatient Repricing Pressure = outpatient/routine exposure x repricing scenario rate.",
  "UC/Liquidity Offset = S-10 uncompensated-care cost x scenario offset rate.",
  "Bounded Stabilization Support = bounded stabilization cap x stabilization scenario multiplier.",
  "",
  "Fallback exposure assumptions used by upstream Script 08:",
  "Rural fallback outpatient exposure share: low 20%, base 30%, high 40%.",
  "Children's fallback outpatient exposure share: low 30%, base 45%, high 60%.",
  "Nonstandard fallback outpatient exposure share: low 5%, base 10%, high 15%.",
  "",
  "Data-state checks from this export:",
  paste0("Backbone providers: ", backbone_providers),
  paste0("Modeled providers: ", modeled_providers),
  paste0("Excluded providers: ", excluded_providers),
  paste0("Modeled share: ", pct1(modeled_share), "%"),
  paste0("Standard G-2 split records: ", standard_g2_split_records),
  paste0("Rural fallback records: ", rural_fallback_records),
  paste0("Children's fallback records: ", children_fallback_records),
  paste0("Nonstandard fallback records: ", nonstandard_fallback_records),
  paste0("Nonstandard fallback failed plausibility records: ", failed_plausibility_records),
  paste0("Model-used net-to-gross outliers <=0 or >1.50: ", model_used_net_to_gross_outlier_count),
  paste0("Exposure anomaly records from 11A: ", exposure_anomaly_count),
  "",
  "Publication note:",
  "Table 7A-7C should use all modeled providers. Table 7F provides a sensitivity excluding exposure-anomaly records identified in the 11A audit."
)

freeze_summary <- c(
  "Table 7 data-state freeze summary",
  "=================================",
  "",
  paste0("Build year: ", hcris_year_label),
  paste0("Generated: ", Sys.time()),
  "",
  paste0("Backbone providers: ", backbone_providers),
  paste0("Modeled providers: ", modeled_providers),
  paste0("Excluded providers: ", excluded_providers),
  paste0("Modeled share: ", pct1(modeled_share), "%"),
  "",
  "Coverage by clean provider group:",
  paste0(
    table_7E_group$`Provider Group`,
    ": ",
    table_7E_group$`Modeled Providers`,
    " / ",
    table_7E_group$`Backbone Providers`,
    " modeled (",
    table_7E_group$`Modeled Share (%)`,
    "%)"
  ),
  "",
  "Revenue source method counts:",
  paste0(source_method_counts$revenue_source_method, ": ", source_method_counts$providers),
  "",
  paste0("Old specialty fallback method present: ", old_specialty_method_present),
  paste0("Corrected nonstandard fallback method present: ", corrected_nonstandard_method_present),
  paste0("Failed-plausibility method present: ", failed_plausibility_method_present),
  paste0("Model-used net-to-gross outliers <=0 or >1.50: ", model_used_net_to_gross_outlier_count),
  paste0("Exposure anomaly records from 11A: ", exposure_anomaly_count)
)

# ============================================================
# 12. Save publication outputs
# ============================================================

table_7A_pub_file <- file.path(table7_dir, "table_7A_publication.csv")
table_7B_pub_file <- file.path(table7_dir, "table_7B_publication.csv")
table_7C_pub_file <- file.path(table7_dir, "table_7C_publication.csv")
table_7D_pub_file <- file.path(table7_dir, "table_7D_publication.csv")
table_7E_pub_file <- file.path(table7_dir, "table_7E_model_coverage_audit.csv")
table_7E_group_file <- file.path(table7_dir, "table_7E_coverage_by_provider_group.csv")
table_7F_pub_file <- file.path(table7_dir, "table_7F_exposure_anomaly_sensitivity.csv")
methodology_file <- file.path(table7_dir, "table_7_methodology_notes.txt")
freeze_file <- file.path(table7_dir, "table_7_data_state_freeze_summary.txt")

# Add table-title rows in separate title metadata file for clarity.
table_titles <- data.table::data.table(
  table_id = c("Table 7A", "Table 7B", "Table 7C", "Table 7D", "Table 7E", "Table 7F"),
  title = c(
    "Provider Impact 3x3 Scenario Matrix",
    "Provider Impact by Provider Group under Base/Base Scenario",
    "Provider Impact by Provider Class under Base/Base Scenario",
    "Distribution of Provider-Level Effects under Base/Base Scenario",
    "Provider-Impact Model Coverage and Data Quality Audit",
    "Exposure-Anomaly Sensitivity under Base/Base Scenario"
  )
)

table_titles_file <- file.path(table7_dir, "table_7_titles.csv")

data.table::fwrite(table_7A_pub, table_7A_pub_file)
data.table::fwrite(table_7B_pub, table_7B_pub_file)
data.table::fwrite(table_7C_pub, table_7C_pub_file)
data.table::fwrite(table_7D_pub, table_7D_pub_file)
data.table::fwrite(table_7E_pub, table_7E_pub_file)
data.table::fwrite(table_7E_group, table_7E_group_file)
data.table::fwrite(table_7F_pub, table_7F_pub_file)
data.table::fwrite(table_titles, table_titles_file)
writeLines(methodology_notes, methodology_file)
writeLines(freeze_summary, freeze_file)

# ============================================================
# 13. Optional combined Excel workbook
# ============================================================

excel_file <- file.path(table7_dir, "table_7_all_publication_tables.xlsx")

if (requireNamespace("openxlsx", quietly = TRUE)) {
  wb <- openxlsx::createWorkbook()
  
  add_sheet <- function(wb, sheet_name, dt) {
    openxlsx::addWorksheet(wb, sheet_name)
    openxlsx::writeData(wb, sheet_name, dt)
    openxlsx::freezePane(wb, sheet_name, firstRow = TRUE)
    openxlsx::setColWidths(wb, sheet_name, cols = 1:ncol(dt), widths = "auto")
  }
  
  add_sheet(wb, "Table 7A", table_7A_pub)
  add_sheet(wb, "Table 7B", table_7B_pub)
  add_sheet(wb, "Table 7C", table_7C_pub)
  add_sheet(wb, "Table 7D", table_7D_pub)
  add_sheet(wb, "Table 7E Audit", table_7E_pub)
  add_sheet(wb, "Table 7E Coverage", table_7E_group)
  add_sheet(wb, "Table 7F Sensitivity", table_7F_pub)
  add_sheet(wb, "Titles", table_titles)
  
  openxlsx::addWorksheet(wb, "Methodology Notes")
  openxlsx::writeData(wb, "Methodology Notes", data.table::data.table(notes = methodology_notes))
  openxlsx::setColWidths(wb, "Methodology Notes", cols = 1, widths = 120)
  
  openxlsx::addWorksheet(wb, "Freeze Summary")
  openxlsx::writeData(wb, "Freeze Summary", data.table::data.table(summary = freeze_summary))
  openxlsx::setColWidths(wb, "Freeze Summary", cols = 1, widths = 120)
  
  openxlsx::saveWorkbook(wb, excel_file, overwrite = TRUE)
  excel_written <- TRUE
} else {
  warning("Package openxlsx not installed. Excel workbook was not written. CSV/TXT outputs were written.")
  excel_written <- FALSE
}

# ============================================================
# 14. Print summaries
# ============================================================

cat("\n============================================================\n")
cat("TABLE 7 PUBLICATION OUTPUTS COMPLETE\n")
cat("============================================================\n")

cat("\nCorrected model-state checks:\n")
cat("Backbone providers:", backbone_providers, "\n")
cat("Modeled providers:", modeled_providers, "\n")
cat("Excluded providers:", excluded_providers, "\n")
cat("Modeled share:", pct1(modeled_share), "%\n")
cat("Old specialty fallback records:", old_specialty_fallback_records, "\n")
cat("Corrected nonstandard fallback records:", nonstandard_fallback_records, "\n")
cat("Nonstandard fallback failed plausibility records:", failed_plausibility_records, "\n")
cat("Model-used net-to-gross outliers <=0 or >1.50:", model_used_net_to_gross_outlier_count, "\n")
cat("Exposure anomaly records from 11A:", exposure_anomaly_count, "\n")

cat("\nCoverage by clean provider group:\n")
print(table_7E_group)

cat("\nTable 7A publication preview:\n")
print(table_7A_pub)

cat("\nTable 7B publication preview:\n")
print(table_7B_pub)

cat("\nTable 7E audit preview:\n")
print(table_7E_pub)

cat("\nTable 7F exposure-anomaly sensitivity preview:\n")
print(table_7F_pub)

cat("\nSaved:\n")
cat(table_7A_pub_file, "\n")
cat(table_7B_pub_file, "\n")
cat(table_7C_pub_file, "\n")
cat(table_7D_pub_file, "\n")
cat(table_7E_pub_file, "\n")
cat(table_7E_group_file, "\n")
cat(table_7F_pub_file, "\n")
cat(table_titles_file, "\n")
cat(methodology_file, "\n")
cat(freeze_file, "\n")

if (excel_written == TRUE) {
  cat(excel_file, "\n")
}

cat("\n============================================================\n")
```

---

# 13_provider_transition_protection_sensitivity.R

```r
# Scripts/13_provider_transition_protection_sensitivity.R
# Provider transition-protection and permanent rural-access sensitivity analysis for Table 7.
#
# Purpose:
#   This script does NOT rebuild the baseline provider-impact model.
#   It reads the corrected Base/Base provider-level output from Script 11
#   and estimates:
#
#     1. temporary transition protections for providers facing large modeled losses; and
#     2. a permanent rural access guarantee that does not sunset.
#
# Inputs:
#   Output/hcris_YYYY_provider_impact_basebase_provider_level.csv
#
# Outputs:
#   Output/Table7_Publication/table_7G_transition_and_rural_access_sensitivity.csv
#   Output/Table7_Publication/table_7H_remaining_large_negative_impacts.csv
#   Output/Table7_Publication/table_7I_support_cost_by_group_class.csv
#   Output/Table7_Publication/table_7J_provider_level_transition_and_rural_access.csv
#   Output/Table7_Publication/table_7_transition_and_rural_access_methodology_notes.txt
#
# Concept:
#   Current Base/Base Table 7 formula:
#
#     Net Provider Impact =
#       - Market Repricing Pressure
#       + UC / Liquidity Offset
#       + Bounded Stabilization Support
#
#   This script tests optional protections:
#
#     Case A: Current Base/Base
#     Case B: Large-negative-impact transition add-on
#     Case C: Pediatric transition hold-harmless
#     Case D: Permanent rural access guarantee
#     Case E: Enhanced Tier 3 / Tier 4 transition stabilization
#     Case F: Combined transition protection + permanent rural access guarantee
#
# Policy principle:
#   The goal is not to hold every provider harmless.
#   The goal is to prevent essential-provider collapse during transition while preserving
#   price discipline. Rural access support is treated differently because rural access is
#   a structural access-capacity problem, not merely a transition problem.
#
# Sunset logic:
#   Temporary transition protections:
#     - large-negative-impact add-on
#     - pediatric hold-harmless
#     - Tier 3 / Tier 4 enhanced stabilization
#   These should sunset after the transition period.
#
#   Permanent support:
#     - rural access guarantee
#   This does not automatically sunset, but remains formula-based, capped, and reviewable.
#
# Important technical note:
#   data.table::fifelse() is strict about class matching. This script uses 0.0
#   and explicit as.numeric() to avoid integer/double class errors.

source("Scripts/00_setup.R")

cat("\n============================================================\n")
cat("CREATE TRANSITION-PROTECTION AND RURAL-ACCESS SENSITIVITY TABLES\n")
cat("============================================================\n")
cat("Build year:", hcris_year_label, "\n\n")

# ============================================================
# 0. Output folder
# ============================================================

table7_dir <- file.path(path_output, "Table7_Publication")

if (!dir.exists(table7_dir)) {
  dir.create(table7_dir, recursive = TRUE)
}

# ============================================================
# 1. Load corrected Base/Base provider-level output
# ============================================================

basebase_provider_file <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_provider_impact_basebase_provider_level.csv")
)

if (!file.exists(basebase_provider_file)) {
  stop(
    "Missing Base/Base provider-level file. Run Script 11 first:\n",
    basebase_provider_file
  )
}

dt <- data.table::fread(basebase_provider_file)

cat("Loaded:\n")
cat(basebase_provider_file, "\n")
cat("\nRows:", nrow(dt), "\n")

# ============================================================
# 2. Safety checks
# ============================================================

required_cols <- c(
  "rpt_rec_num",
  "prvdr_num_chr",
  "provider_name",
  "city",
  "state_abbrev",
  "provider_impact_model_include_flag",
  "raw_provider_model_class",
  "clean_provider_model_class",
  "clean_provider_group",
  "revenue_source_method",
  "net_patient_revenue_model",
  "outpatient_exposure_used",
  "outpatient_repricing_pressure",
  "uncompensated_care_offset",
  "stabilization_support",
  "net_provider_impact",
  "net_provider_impact_pct_of_npr",
  "stabilization_tier",
  "stabilization_tier_numeric",
  "stabilization_basis",
  "transition_support_cap_rate",
  "annual_transition_support_cap_model",
  "stabilization_eligible_bounded_flag"
)

missing_cols <- setdiff(required_cols, names(dt))

if (length(missing_cols) > 0) {
  stop(
    "Base/Base provider-level file missing required columns:\n",
    paste(missing_cols, collapse = "\n")
  )
}

dt[
  ,
  provider_impact_model_include_flag :=
    as.logical(provider_impact_model_include_flag)
]

dt[
  ,
  stabilization_eligible_bounded_flag :=
    as.logical(stabilization_eligible_bounded_flag)
]

numeric_cols <- c(
  "net_patient_revenue_model",
  "outpatient_exposure_used",
  "outpatient_repricing_pressure",
  "uncompensated_care_offset",
  "stabilization_support",
  "net_provider_impact",
  "net_provider_impact_pct_of_npr",
  "stabilization_tier_numeric",
  "transition_support_cap_rate",
  "annual_transition_support_cap_model"
)

for (cc in numeric_cols) {
  dt[, (cc) := as.numeric(get(cc))]
}

modeled <- copy(dt[provider_impact_model_include_flag == TRUE])

cat("\nModeled providers:", nrow(modeled), "\n")

# ============================================================
# 3. Policy assumptions
# ============================================================

# Large negative impact threshold.
# Providers worse than -5% of NPR are considered large-negative-impact providers.
large_negative_threshold <- -0.05

# Severe negative impact threshold.
# Providers worse than -10% of NPR are considered severe-transition-risk providers.
severe_negative_threshold <- -0.10

# Case B: temporary large-negative-impact add-on.
# Offsets a portion of the provider's modeled loss beyond the -5% threshold,
# subject to a cap as a percent of NPR.
large_negative_loss_share_offset <- 0.25
large_negative_addon_cap_npr <- 0.01

# Case C: temporary pediatric hold-harmless floor.
# Pediatric providers should be protected during transition, but this support sunsets.
pediatric_floor_pct_npr <- -0.03

# Case D: permanent rural access guarantee.
# Rural help does not sunset because rural access vulnerability is structural.
permanent_rural_access_rate_npr <- 0.01

# Optional fixed-dollar cap for the permanent rural access guarantee.
# This prevents very large rural-labeled providers from receiving uncapped support.
# Set to Inf if you do not want a fixed-dollar cap.
permanent_rural_access_fixed_cap <- 3000000.0

# Case E: temporary enhanced Tier 3 / Tier 4 stabilization.
# This sunsets after transition.
tier3_incremental_cap_npr <- 0.005
tier4_incremental_cap_npr <- 0.010

# Case F: combined protection guardrail.
# Total temporary added transition support per provider is capped.
# Permanent rural access support is tracked separately because it does not sunset.
combined_temporary_support_cap_npr <- 0.025

# Optional repricing phase-in illustration.
# This is not applied to the steady-state Table 7G cases unless explicitly stated.
repricing_phase_in_year1 <- 0.40
repricing_phase_in_year2 <- 0.60
repricing_phase_in_year3 <- 0.80
repricing_phase_in_year4_plus <- 1.00

# ============================================================
# 4. Provider-level flags
# ============================================================

modeled[
  ,
  large_negative_impact_flag :=
    !is.na(net_provider_impact_pct_of_npr) &
    net_provider_impact_pct_of_npr <= large_negative_threshold
]

modeled[
  ,
  severe_negative_impact_flag :=
    !is.na(net_provider_impact_pct_of_npr) &
    net_provider_impact_pct_of_npr <= severe_negative_threshold
]

modeled[
  ,
  permanent_rural_access_eligible_flag :=
    clean_provider_group == "Rural / CAH / IHS"
]

modeled[
  ,
  pediatric_transition_eligible_flag :=
    clean_provider_group == "Children's / pediatric"
]

modeled[
  ,
  high_stabilization_tier_flag :=
    stabilization_tier_numeric >= 3L
]

modeled[
  ,
  tier3_flag :=
    stabilization_tier_numeric == 3L
]

modeled[
  ,
  tier4_flag :=
    stabilization_tier_numeric == 4L
]

# Amount of loss beyond the -5% NPR threshold.
modeled[
  ,
  loss_beyond_large_negative_threshold :=
    data.table::fifelse(
      large_negative_impact_flag == TRUE,
      as.numeric(
        abs(net_provider_impact) -
          abs(net_patient_revenue_model * large_negative_threshold)
      ),
      0.0
    )
]

modeled[
  loss_beyond_large_negative_threshold < 0 |
    is.na(loss_beyond_large_negative_threshold),
  loss_beyond_large_negative_threshold := 0.0
]

# ============================================================
# 5. Case A: Current Base/Base
# ============================================================

modeled[
  ,
  case_A_temporary_support := 0.0
]

modeled[
  ,
  case_A_permanent_rural_access_support := 0.0
]

modeled[
  ,
  case_A_total_added_support := 0.0
]

modeled[
  ,
  case_A_net_impact := as.numeric(net_provider_impact)
]

modeled[
  ,
  case_A_net_impact_pct_npr :=
    as.numeric(net_provider_impact_pct_of_npr)
]

# ============================================================
# 6. Case B: Temporary large-negative-impact add-on
# ============================================================

modeled[
  ,
  case_B_large_negative_addon :=
    pmin(
      as.numeric(loss_beyond_large_negative_threshold * large_negative_loss_share_offset),
      as.numeric(net_patient_revenue_model * large_negative_addon_cap_npr),
      na.rm = TRUE
    )
]

modeled[
  is.na(case_B_large_negative_addon),
  case_B_large_negative_addon := 0.0
]

modeled[
  ,
  case_B_temporary_support :=
    as.numeric(case_B_large_negative_addon)
]

modeled[
  ,
  case_B_permanent_rural_access_support := 0.0
]

modeled[
  ,
  case_B_total_added_support :=
    as.numeric(case_B_temporary_support + case_B_permanent_rural_access_support)
]

modeled[
  ,
  case_B_net_impact :=
    as.numeric(net_provider_impact + case_B_total_added_support)
]

modeled[
  ,
  case_B_net_impact_pct_npr :=
    data.table::fifelse(
      net_patient_revenue_model > 0,
      as.numeric(case_B_net_impact / net_patient_revenue_model),
      NA_real_
    )
]

# ============================================================
# 7. Case C: Temporary pediatric hold-harmless floor
# ============================================================

modeled[
  ,
  case_C_pediatric_hold_harmless_needed :=
    data.table::fifelse(
      pediatric_transition_eligible_flag == TRUE &
        net_provider_impact_pct_of_npr < pediatric_floor_pct_npr,
      as.numeric(
        (net_patient_revenue_model * pediatric_floor_pct_npr) -
          net_provider_impact
      ),
      0.0
    )
]

modeled[
  case_C_pediatric_hold_harmless_needed < 0 |
    is.na(case_C_pediatric_hold_harmless_needed),
  case_C_pediatric_hold_harmless_needed := 0.0
]

modeled[
  ,
  case_C_temporary_support :=
    as.numeric(case_C_pediatric_hold_harmless_needed)
]

modeled[
  ,
  case_C_permanent_rural_access_support := 0.0
]

modeled[
  ,
  case_C_total_added_support :=
    as.numeric(case_C_temporary_support + case_C_permanent_rural_access_support)
]

modeled[
  ,
  case_C_net_impact :=
    as.numeric(net_provider_impact + case_C_total_added_support)
]

modeled[
  ,
  case_C_net_impact_pct_npr :=
    data.table::fifelse(
      net_patient_revenue_model > 0,
      as.numeric(case_C_net_impact / net_patient_revenue_model),
      NA_real_
    )
]

# ============================================================
# 8. Case D: Permanent rural access guarantee
# ============================================================

modeled[
  ,
  case_D_rural_access_uncapped :=
    data.table::fifelse(
      permanent_rural_access_eligible_flag == TRUE,
      as.numeric(net_patient_revenue_model * permanent_rural_access_rate_npr),
      0.0
    )
]

modeled[
  ,
  case_D_permanent_rural_access_support :=
    pmin(
      as.numeric(case_D_rural_access_uncapped),
      permanent_rural_access_fixed_cap,
      na.rm = TRUE
    )
]

modeled[
  is.na(case_D_permanent_rural_access_support),
  case_D_permanent_rural_access_support := 0.0
]

modeled[
  ,
  case_D_temporary_support := 0.0
]

modeled[
  ,
  case_D_total_added_support :=
    as.numeric(case_D_temporary_support + case_D_permanent_rural_access_support)
]

modeled[
  ,
  case_D_net_impact :=
    as.numeric(net_provider_impact + case_D_total_added_support)
]

modeled[
  ,
  case_D_net_impact_pct_npr :=
    data.table::fifelse(
      net_patient_revenue_model > 0,
      as.numeric(case_D_net_impact / net_patient_revenue_model),
      NA_real_
    )
]

# ============================================================
# 9. Case E: Temporary enhanced Tier 3 / Tier 4 stabilization
# ============================================================

modeled[
  ,
  case_E_tier_enhancement :=
    data.table::fcase(
      tier4_flag == TRUE,
      as.numeric(net_patient_revenue_model * tier4_incremental_cap_npr),
      
      tier3_flag == TRUE,
      as.numeric(net_patient_revenue_model * tier3_incremental_cap_npr),
      
      default = 0.0
    )
]

modeled[
  is.na(case_E_tier_enhancement),
  case_E_tier_enhancement := 0.0
]

modeled[
  ,
  case_E_temporary_support :=
    as.numeric(case_E_tier_enhancement)
]

modeled[
  ,
  case_E_permanent_rural_access_support := 0.0
]

modeled[
  ,
  case_E_total_added_support :=
    as.numeric(case_E_temporary_support + case_E_permanent_rural_access_support)
]

modeled[
  ,
  case_E_net_impact :=
    as.numeric(net_provider_impact + case_E_total_added_support)
]

modeled[
  ,
  case_E_net_impact_pct_npr :=
    data.table::fifelse(
      net_patient_revenue_model > 0,
      as.numeric(case_E_net_impact / net_patient_revenue_model),
      NA_real_
    )
]

# ============================================================
# 10. Case F: Combined transition protection + permanent rural access
# ============================================================

# Temporary support components:
#   - Case B large-negative-impact add-on
#   - Case C pediatric hold-harmless
#   - Case E Tier 3 / Tier 4 enhancement
#
# Permanent rural access component:
#   - Case D rural access guarantee
#
# Temporary support is capped per provider.
# Permanent rural access is not sunset and is tracked separately.

modeled[
  ,
  case_F_uncapped_temporary_support :=
    as.numeric(
      case_B_large_negative_addon +
        case_C_pediatric_hold_harmless_needed +
        case_E_tier_enhancement
    )
]

modeled[
  ,
  case_F_temporary_support_cap :=
    as.numeric(net_patient_revenue_model * combined_temporary_support_cap_npr)
]

modeled[
  ,
  case_F_temporary_support :=
    pmin(
      as.numeric(case_F_uncapped_temporary_support),
      as.numeric(case_F_temporary_support_cap),
      na.rm = TRUE
    )
]

modeled[
  is.na(case_F_temporary_support),
  case_F_temporary_support := 0.0
]

modeled[
  ,
  case_F_permanent_rural_access_support :=
    as.numeric(case_D_permanent_rural_access_support)
]

modeled[
  ,
  case_F_total_added_support :=
    as.numeric(case_F_temporary_support + case_F_permanent_rural_access_support)
]

modeled[
  ,
  case_F_net_impact :=
    as.numeric(net_provider_impact + case_F_total_added_support)
]

modeled[
  ,
  case_F_net_impact_pct_npr :=
    data.table::fifelse(
      net_patient_revenue_model > 0,
      as.numeric(case_F_net_impact / net_patient_revenue_model),
      NA_real_
    )
]

# ============================================================
# 11. Optional repricing phase-in illustration
# ============================================================

modeled[
  ,
  phasein_year1_net_impact :=
    as.numeric(
      (outpatient_repricing_pressure * repricing_phase_in_year1) +
        uncompensated_care_offset +
        stabilization_support
    )
]

modeled[
  ,
  phasein_year2_net_impact :=
    as.numeric(
      (outpatient_repricing_pressure * repricing_phase_in_year2) +
        uncompensated_care_offset +
        stabilization_support
    )
]

modeled[
  ,
  phasein_year3_net_impact :=
    as.numeric(
      (outpatient_repricing_pressure * repricing_phase_in_year3) +
        uncompensated_care_offset +
        stabilization_support
    )
]

modeled[
  ,
  phasein_year4_plus_net_impact :=
    as.numeric(
      (outpatient_repricing_pressure * repricing_phase_in_year4_plus) +
        uncompensated_care_offset +
        stabilization_support
    )
]

for (yy in c("year1", "year2", "year3", "year4_plus")) {
  impact_col <- paste0("phasein_", yy, "_net_impact")
  pct_col <- paste0("phasein_", yy, "_net_impact_pct_npr")
  
  modeled[
    ,
    (pct_col) := data.table::fifelse(
      net_patient_revenue_model > 0,
      as.numeric(get(impact_col) / net_patient_revenue_model),
      NA_real_
    )
  ]
}

# ============================================================
# 12. Helper functions
# ============================================================

billion <- function(x) {
  round(as.numeric(x) / 1e9, 2)
}

pct1 <- function(x) {
  round(as.numeric(x) * 100, 1)
}

num0 <- function(x) {
  as.integer(round(as.numeric(x), 0))
}

safe_sum <- function(x) {
  sum(as.numeric(x), na.rm = TRUE)
}

safe_div <- function(num, den) {
  ifelse(!is.na(den) & den != 0, num / den, NA_real_)
}

make_case_summary <- function(
    dt,
    case_id,
    case_name,
    temporary_support_col,
    permanent_rural_support_col,
    total_support_col,
    impact_col,
    pct_col,
    sunset_status
) {
  data.table::data.table(
    `Case` = case_id,
    `Protection Design` = case_name,
    `Sunset Treatment` = sunset_status,
    `Modeled Providers` = nrow(dt),
    `Total Net Patient Revenue ($B)` =
      billion(safe_sum(dt$net_patient_revenue_model)),
    `Original Repricing Pressure ($B)` =
      billion(safe_sum(dt$outpatient_repricing_pressure)),
    `Original UC / Liquidity Offset ($B)` =
      billion(safe_sum(dt$uncompensated_care_offset)),
    `Original Stabilization Support ($B)` =
      billion(safe_sum(dt$stabilization_support)),
    `Temporary Transition Support ($B)` =
      billion(safe_sum(dt[[temporary_support_col]])),
    `Permanent Rural Access Support ($B)` =
      billion(safe_sum(dt[[permanent_rural_support_col]])),
    `Total Added Support ($B)` =
      billion(safe_sum(dt[[total_support_col]])),
    `Net Provider Impact After Support ($B)` =
      billion(safe_sum(dt[[impact_col]])),
    `Net Impact After Support (% of NPR)` =
      pct1(
        safe_div(
          safe_sum(dt[[impact_col]]),
          safe_sum(dt$net_patient_revenue_model)
        )
      ),
    `Median Provider Impact After Support (% of NPR)` =
      pct1(median(dt[[pct_col]], na.rm = TRUE)),
    `Providers Below -5% NPR` =
      num0(sum(dt[[pct_col]] <= large_negative_threshold, na.rm = TRUE)),
    `Providers Below -10% NPR` =
      num0(sum(dt[[pct_col]] <= severe_negative_threshold, na.rm = TRUE)),
    `Providers Negative` =
      num0(sum(dt[[impact_col]] < 0, na.rm = TRUE)),
    `Providers Positive` =
      num0(sum(dt[[impact_col]] > 0, na.rm = TRUE))
  )
}

# ============================================================
# 13. Table 7G — Transition and rural access sensitivity
# ============================================================

table_7G <- data.table::rbindlist(
  list(
    make_case_summary(
      modeled,
      "A",
      "Current Base/Base; no additional support",
      "case_A_temporary_support",
      "case_A_permanent_rural_access_support",
      "case_A_total_added_support",
      "case_A_net_impact",
      "case_A_net_impact_pct_npr",
      "No additional support"
    ),
    make_case_summary(
      modeled,
      "B",
      "Temporary large-negative-impact add-on for providers below -5% NPR",
      "case_B_temporary_support",
      "case_B_permanent_rural_access_support",
      "case_B_total_added_support",
      "case_B_net_impact",
      "case_B_net_impact_pct_npr",
      "Temporary; sunsets after transition"
    ),
    make_case_summary(
      modeled,
      "C",
      "Temporary pediatric hold-harmless floor at -3% NPR",
      "case_C_temporary_support",
      "case_C_permanent_rural_access_support",
      "case_C_total_added_support",
      "case_C_net_impact",
      "case_C_net_impact_pct_npr",
      "Temporary; sunsets after transition"
    ),
    make_case_summary(
      modeled,
      "D",
      "Permanent rural access guarantee",
      "case_D_temporary_support",
      "case_D_permanent_rural_access_support",
      "case_D_total_added_support",
      "case_D_net_impact",
      "case_D_net_impact_pct_npr",
      "Permanent; formula-based and capped"
    ),
    make_case_summary(
      modeled,
      "E",
      "Temporary enhanced Tier 3 / Tier 4 stabilization",
      "case_E_temporary_support",
      "case_E_permanent_rural_access_support",
      "case_E_total_added_support",
      "case_E_net_impact",
      "case_E_net_impact_pct_npr",
      "Temporary; sunsets after transition"
    ),
    make_case_summary(
      modeled,
      "F",
      "Combined temporary transition protection + permanent rural access guarantee",
      "case_F_temporary_support",
      "case_F_permanent_rural_access_support",
      "case_F_total_added_support",
      "case_F_net_impact",
      "case_F_net_impact_pct_npr",
      "Temporary transition support sunsets; rural access support remains"
    )
  ),
  fill = TRUE
)

# ============================================================
# 14. Table 7H — Remaining large negative impacts by group
# ============================================================

make_remaining_by_group <- function(
    dt,
    case_id,
    case_name,
    pct_col,
    impact_col,
    temporary_support_col,
    permanent_rural_support_col,
    total_support_col,
    sunset_status
) {
  dt[
    ,
    .(
      `Providers` = .N,
      `Providers Below -5% NPR` =
        sum(get(pct_col) <= large_negative_threshold, na.rm = TRUE),
      `Providers Below -10% NPR` =
        sum(get(pct_col) <= severe_negative_threshold, na.rm = TRUE),
      `Negative Providers` =
        sum(get(impact_col) < 0, na.rm = TRUE),
      `Positive Providers` =
        sum(get(impact_col) > 0, na.rm = TRUE),
      `Temporary Support ($B)` =
        billion(safe_sum(get(temporary_support_col))),
      `Permanent Rural Access Support ($B)` =
        billion(safe_sum(get(permanent_rural_support_col))),
      `Total Added Support ($B)` =
        billion(safe_sum(get(total_support_col))),
      `Net Provider Impact ($B)` =
        billion(safe_sum(get(impact_col))),
      `Net Impact (% of NPR)` =
        pct1(
          safe_div(
            safe_sum(get(impact_col)),
            safe_sum(net_patient_revenue_model)
          )
        ),
      `Median Impact (% of NPR)` =
        pct1(median(get(pct_col), na.rm = TRUE))
    ),
    by = clean_provider_group
  ][
    ,
    `Case` := case_id
  ][
    ,
    `Protection Design` := case_name
  ][
    ,
    `Sunset Treatment` := sunset_status
  ][
    ,
    .(
      `Case`,
      `Protection Design`,
      `Sunset Treatment`,
      `Provider Group` = clean_provider_group,
      `Providers`,
      `Providers Below -5% NPR`,
      `Providers Below -10% NPR`,
      `Negative Providers`,
      `Positive Providers`,
      `Temporary Support ($B)`,
      `Permanent Rural Access Support ($B)`,
      `Total Added Support ($B)`,
      `Net Provider Impact ($B)`,
      `Net Impact (% of NPR)`,
      `Median Impact (% of NPR)`
    )
  ]
}

table_7H <- data.table::rbindlist(
  list(
    make_remaining_by_group(
      modeled,
      "A",
      "Current Base/Base",
      "case_A_net_impact_pct_npr",
      "case_A_net_impact",
      "case_A_temporary_support",
      "case_A_permanent_rural_access_support",
      "case_A_total_added_support",
      "No additional support"
    ),
    make_remaining_by_group(
      modeled,
      "B",
      "Temporary large-negative-impact add-on",
      "case_B_net_impact_pct_npr",
      "case_B_net_impact",
      "case_B_temporary_support",
      "case_B_permanent_rural_access_support",
      "case_B_total_added_support",
      "Temporary; sunsets after transition"
    ),
    make_remaining_by_group(
      modeled,
      "C",
      "Temporary pediatric hold-harmless",
      "case_C_net_impact_pct_npr",
      "case_C_net_impact",
      "case_C_temporary_support",
      "case_C_permanent_rural_access_support",
      "case_C_total_added_support",
      "Temporary; sunsets after transition"
    ),
    make_remaining_by_group(
      modeled,
      "D",
      "Permanent rural access guarantee",
      "case_D_net_impact_pct_npr",
      "case_D_net_impact",
      "case_D_temporary_support",
      "case_D_permanent_rural_access_support",
      "case_D_total_added_support",
      "Permanent; formula-based and capped"
    ),
    make_remaining_by_group(
      modeled,
      "E",
      "Temporary enhanced Tier 3 / Tier 4 stabilization",
      "case_E_net_impact_pct_npr",
      "case_E_net_impact",
      "case_E_temporary_support",
      "case_E_permanent_rural_access_support",
      "case_E_total_added_support",
      "Temporary; sunsets after transition"
    ),
    make_remaining_by_group(
      modeled,
      "F",
      "Combined temporary transition protection + permanent rural access guarantee",
      "case_F_net_impact_pct_npr",
      "case_F_net_impact",
      "case_F_temporary_support",
      "case_F_permanent_rural_access_support",
      "case_F_total_added_support",
      "Temporary support sunsets; rural access support remains"
    )
  ),
  fill = TRUE
)[order(`Case`, `Provider Group`)]

# ============================================================
# 15. Table 7I — Support cost by group/class
# ============================================================

table_7I <- modeled[
  ,
  .(
    providers = .N,
    
    current_net_impact =
      safe_sum(case_A_net_impact),
    
    large_negative_addon_cost =
      safe_sum(case_B_temporary_support),
    
    pediatric_hold_harmless_cost =
      safe_sum(case_C_temporary_support),
    
    permanent_rural_access_cost =
      safe_sum(case_D_permanent_rural_access_support),
    
    tier3_tier4_enhancement_cost =
      safe_sum(case_E_temporary_support),
    
    combined_temporary_support =
      safe_sum(case_F_temporary_support),
    
    combined_permanent_rural_access_support =
      safe_sum(case_F_permanent_rural_access_support),
    
    combined_total_added_support =
      safe_sum(case_F_total_added_support),
    
    combined_net_impact =
      safe_sum(case_F_net_impact),
    
    providers_below_minus_5_current =
      sum(case_A_net_impact_pct_npr <= large_negative_threshold, na.rm = TRUE),
    
    providers_below_minus_5_combined =
      sum(case_F_net_impact_pct_npr <= large_negative_threshold, na.rm = TRUE),
    
    providers_below_minus_10_current =
      sum(case_A_net_impact_pct_npr <= severe_negative_threshold, na.rm = TRUE),
    
    providers_below_minus_10_combined =
      sum(case_F_net_impact_pct_npr <= severe_negative_threshold, na.rm = TRUE)
  ),
  by = .(
    clean_provider_group,
    clean_provider_model_class
  )
][
  ,
  .(
    `Provider Group` = clean_provider_group,
    `Provider Class` = clean_provider_model_class,
    `Providers` = providers,
    `Current Net Impact ($B)` = billion(current_net_impact),
    `Large-Negative Add-On Cost ($B)` = billion(large_negative_addon_cost),
    `Pediatric Hold-Harmless Cost ($B)` = billion(pediatric_hold_harmless_cost),
    `Permanent Rural Access Cost ($B)` = billion(permanent_rural_access_cost),
    `Tier 3/4 Enhancement Cost ($B)` = billion(tier3_tier4_enhancement_cost),
    `Combined Temporary Support ($B)` = billion(combined_temporary_support),
    `Combined Permanent Rural Access Support ($B)` = billion(combined_permanent_rural_access_support),
    `Combined Total Added Support ($B)` = billion(combined_total_added_support),
    `Combined Net Impact ($B)` = billion(combined_net_impact),
    `Providers Below -5% Current` = providers_below_minus_5_current,
    `Providers Below -5% Combined` = providers_below_minus_5_combined,
    `Providers Below -10% Current` = providers_below_minus_10_current,
    `Providers Below -10% Combined` = providers_below_minus_10_combined
  )
][order(`Provider Group`, `Provider Class`)]

# ============================================================
# 16. Table 7J — Provider-level output
# ============================================================

table_7J <- modeled[
  ,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    city,
    state_abbrev,
    raw_provider_model_class,
    clean_provider_group,
    clean_provider_model_class,
    revenue_source_method,
    
    net_patient_revenue_model,
    outpatient_exposure_used,
    outpatient_repricing_pressure,
    uncompensated_care_offset,
    stabilization_support,
    net_provider_impact,
    net_provider_impact_pct_of_npr,
    
    stabilization_tier,
    stabilization_basis,
    transition_support_cap_rate,
    annual_transition_support_cap_model,
    
    large_negative_impact_flag,
    severe_negative_impact_flag,
    permanent_rural_access_eligible_flag,
    pediatric_transition_eligible_flag,
    high_stabilization_tier_flag,
    
    case_B_temporary_support,
    case_C_temporary_support,
    case_D_permanent_rural_access_support,
    case_E_temporary_support,
    case_F_temporary_support,
    case_F_permanent_rural_access_support,
    case_F_total_added_support,
    
    case_A_net_impact,
    case_A_net_impact_pct_npr,
    case_B_net_impact,
    case_B_net_impact_pct_npr,
    case_C_net_impact,
    case_C_net_impact_pct_npr,
    case_D_net_impact,
    case_D_net_impact_pct_npr,
    case_E_net_impact,
    case_E_net_impact_pct_npr,
    case_F_net_impact,
    case_F_net_impact_pct_npr,
    
    phasein_year1_net_impact,
    phasein_year1_net_impact_pct_npr,
    phasein_year2_net_impact,
    phasein_year2_net_impact_pct_npr,
    phasein_year3_net_impact,
    phasein_year3_net_impact_pct_npr,
    phasein_year4_plus_net_impact,
    phasein_year4_plus_net_impact_pct_npr
  )
][order(case_F_net_impact_pct_npr)]

# ============================================================
# 17. Methodology notes
# ============================================================

methodology_notes <- c(
  "Table 7G-7J transition-protection and rural-access methodology notes",
  "====================================================================",
  "",
  paste0("Build year: ", hcris_year_label),
  paste0("Generated: ", Sys.time()),
  "",
  "These tables are sensitivity analyses layered on top of the corrected Base/Base provider-impact model.",
  "They do not rebuild the core provider-impact model and do not alter Tables 7A-7F.",
  "",
  "Core Base/Base equation:",
  "Net Provider Impact = - Market Repricing Pressure + UC/Liquidity Offset + Bounded Stabilization Support.",
  "",
  "Policy distinction:",
  "Temporary transition stabilization and permanent rural access support are treated separately.",
  "",
  "Temporary transition stabilization addresses short-run adjustment stress created by the movement from comprehensive insurance to UCC/HSE routine-care price discipline.",
  "Permanent rural access support addresses structural rural access constraints that do not disappear after transition: low volume, fixed standby costs, large service areas, workforce constraints, and lack of substitute providers.",
  "",
  "Case A: Current Base/Base",
  "No additional support beyond the original bounded stabilization layer.",
  "",
  "Case B: Temporary large-negative-impact add-on",
  paste0(
    "Providers with net impact at or below ",
    pct1(large_negative_threshold),
    "% of net patient revenue receive an add-on equal to ",
    pct1(large_negative_loss_share_offset),
    "% of the loss beyond that threshold, capped at ",
    pct1(large_negative_addon_cap_npr),
    "% of NPR. This support sunsets after transition."
  ),
  "",
  "Case C: Temporary pediatric hold-harmless",
  paste0(
    "Children's / pediatric providers receive enough support to prevent modeled net impact from being worse than ",
    pct1(pediatric_floor_pct_npr),
    "% of NPR. This support sunsets after transition."
  ),
  "",
  "Case D: Permanent rural access guarantee",
  paste0(
    "Rural / CAH / IHS providers receive a permanent rural access payment equal to ",
    pct1(permanent_rural_access_rate_npr),
    "% of NPR, capped at $",
    format(permanent_rural_access_fixed_cap, big.mark = ","),
    " per provider annually. This support does not automatically sunset."
  ),
  "",
  "Case E: Temporary enhanced Tier 3 / Tier 4 stabilization",
  paste0(
    "Tier 3 providers receive an incremental ",
    pct1(tier3_incremental_cap_npr),
    "% of NPR; Tier 4 providers receive an incremental ",
    pct1(tier4_incremental_cap_npr),
    "% of NPR. This support sunsets after transition."
  ),
  "",
  "Case F: Combined transition protection + permanent rural access guarantee",
  paste0(
    "Combines temporary large-negative-impact protection, pediatric hold-harmless, Tier 3 / Tier 4 enhancement, and permanent rural access support. Temporary support is capped at ",
    pct1(combined_temporary_support_cap_npr),
    "% of NPR per provider. Rural access support remains as a permanent formula-based access-capacity payment."
  ),
  "",
  "Interpretive rule:",
  "The goal is not to hold every provider harmless. The goal is to prevent essential-provider collapse during transition while preserving price discipline.",
  "",
  "Recommended policy framing:",
  "Temporary support for transition losses; permanent support for essential rural access.",
  "",
  "Optional repricing phase-in fields:",
  paste0("Year 1 repricing phase-in factor: ", pct1(repricing_phase_in_year1), "%"),
  paste0("Year 2 repricing phase-in factor: ", pct1(repricing_phase_in_year2), "%"),
  paste0("Year 3 repricing phase-in factor: ", pct1(repricing_phase_in_year3), "%"),
  paste0("Year 4+ repricing phase-in factor: ", pct1(repricing_phase_in_year4_plus), "%")
)

# ============================================================
# 18. Save outputs
# ============================================================

table_7G_file <- file.path(
  table7_dir,
  "table_7G_transition_and_rural_access_sensitivity.csv"
)

table_7H_file <- file.path(
  table7_dir,
  "table_7H_remaining_large_negative_impacts.csv"
)

table_7I_file <- file.path(
  table7_dir,
  "table_7I_support_cost_by_group_class.csv"
)

table_7J_file <- file.path(
  table7_dir,
  "table_7J_provider_level_transition_and_rural_access.csv"
)

methodology_file <- file.path(
  table7_dir,
  "table_7_transition_and_rural_access_methodology_notes.txt"
)

data.table::fwrite(table_7G, table_7G_file)
data.table::fwrite(table_7H, table_7H_file)
data.table::fwrite(table_7I, table_7I_file)
data.table::fwrite(table_7J, table_7J_file)
writeLines(methodology_notes, methodology_file)

# Optional Excel workbook.
excel_file <- file.path(
  table7_dir,
  "table_7G_to_7J_transition_and_rural_access_sensitivity.xlsx"
)

excel_written <- FALSE

if (requireNamespace("openxlsx", quietly = TRUE)) {
  wb <- openxlsx::createWorkbook()
  
  add_sheet <- function(wb, sheet_name, dt_sheet) {
    openxlsx::addWorksheet(wb, sheet_name)
    openxlsx::writeData(wb, sheet_name, dt_sheet)
    openxlsx::freezePane(wb, sheet_name, firstRow = TRUE)
    openxlsx::setColWidths(wb, sheet_name, cols = 1:ncol(dt_sheet), widths = "auto")
  }
  
  add_sheet(wb, "Table 7G", table_7G)
  add_sheet(wb, "Table 7H", table_7H)
  add_sheet(wb, "Table 7I", table_7I)
  add_sheet(wb, "Table 7J", table_7J)
  
  openxlsx::addWorksheet(wb, "Methodology Notes")
  openxlsx::writeData(
    wb,
    "Methodology Notes",
    data.table::data.table(notes = methodology_notes)
  )
  openxlsx::setColWidths(wb, "Methodology Notes", cols = 1, widths = 120)
  
  openxlsx::saveWorkbook(wb, excel_file, overwrite = TRUE)
  excel_written <- TRUE
} else {
  warning(
    "Package openxlsx not installed. Excel workbook was not written. ",
    "CSV/TXT outputs were written."
  )
}

# ============================================================
# 19. Print summaries
# ============================================================

cat("\n============================================================\n")
cat("TRANSITION-PROTECTION AND RURAL-ACCESS SENSITIVITY COMPLETE\n")
cat("============================================================\n")

cat("\nAssumptions:\n")
cat("Large negative threshold:", pct1(large_negative_threshold), "% NPR\n")
cat("Severe negative threshold:", pct1(severe_negative_threshold), "% NPR\n")
cat("Large-negative add-on offset share:", pct1(large_negative_loss_share_offset), "%\n")
cat("Large-negative add-on cap:", pct1(large_negative_addon_cap_npr), "% NPR\n")
cat("Pediatric temporary floor:", pct1(pediatric_floor_pct_npr), "% NPR\n")
cat("Permanent rural access rate:", pct1(permanent_rural_access_rate_npr), "% NPR\n")
cat("Permanent rural access fixed cap: $", format(permanent_rural_access_fixed_cap, big.mark = ","), "\n", sep = "")
cat("Tier 3 incremental cap:", pct1(tier3_incremental_cap_npr), "% NPR\n")
cat("Tier 4 incremental cap:", pct1(tier4_incremental_cap_npr), "% NPR\n")
cat("Combined temporary support cap:", pct1(combined_temporary_support_cap_npr), "% NPR\n")

cat("\nTable 7G. Transition and Rural Access Sensitivity:\n")
print(table_7G)

cat("\nTable 7H. Remaining Large Negative Impacts by Group:\n")
print(table_7H)

cat("\nTable 7I. Support Cost by Group/Class:\n")
print(table_7I)

cat("\nWorst remaining providers under combined protection:\n")
print(table_7J[
  ,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    state_abbrev,
    clean_provider_group,
    clean_provider_model_class,
    net_patient_revenue_model,
    case_A_net_impact_pct_npr,
    case_F_temporary_support,
    case_F_permanent_rural_access_support,
    case_F_total_added_support,
    case_F_net_impact_pct_npr,
    large_negative_impact_flag,
    severe_negative_impact_flag,
    permanent_rural_access_eligible_flag,
    pediatric_transition_eligible_flag,
    stabilization_tier
  )
][order(case_F_net_impact_pct_npr)][1:50])

cat("\nSaved:\n")
cat(table_7G_file, "\n")
cat(table_7H_file, "\n")
cat(table_7I_file, "\n")
cat(table_7J_file, "\n")
cat(methodology_file, "\n")

if (excel_written == TRUE) {
  cat(excel_file, "\n")
}

cat("\n============================================================\n")
```

---

# 13B_enhanced_rural_access_sensitivity.R

```r
# Scripts/13B_enhanced_rural_access_sensitivity.R
# Enhanced Rural Access Guarantee sensitivity for UCC/HSE Table 7.
#
# Purpose:
#   This script does NOT rebuild the baseline provider-impact model.
#   It reads the corrected Base/Base provider-level output from Script 11
#   and tests stronger rural protection options.
#
# Inputs:
#   Output/hcris_YYYY_provider_impact_basebase_provider_level.csv
#
# Outputs:
#   Output/Table7_Publication/table_7K_enhanced_rural_access_sensitivity.csv
#   Output/Table7_Publication/table_7L_rural_provider_level_enhanced_access.csv
#   Output/Table7_Publication/table_7_enhanced_rural_access_methodology_notes.txt
#
# Policy distinction:
#   General transition stabilization can sunset.
#   Rural access support should not automatically sunset because rural access is
#   a structural access-capacity problem, not only a transition problem.

source("Scripts/00_setup.R")

cat("\n============================================================\n")
cat("CREATE ENHANCED RURAL ACCESS GUARANTEE SENSITIVITY\n")
cat("============================================================\n")
cat("Build year:", hcris_year_label, "\n\n")

# ============================================================
# 0. Output folder
# ============================================================

table7_dir <- file.path(path_output, "Table7_Publication")

if (!dir.exists(table7_dir)) {
  dir.create(table7_dir, recursive = TRUE)
}

# ============================================================
# 1. Load Base/Base provider-level output
# ============================================================

basebase_provider_file <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_provider_impact_basebase_provider_level.csv")
)

if (!file.exists(basebase_provider_file)) {
  stop(
    "Missing Base/Base provider-level file. Run Script 11 first:\n",
    basebase_provider_file
  )
}

dt <- data.table::fread(basebase_provider_file)

cat("Loaded:\n")
cat(basebase_provider_file, "\n")
cat("\nRows:", nrow(dt), "\n")

# ============================================================
# 2. Safety checks
# ============================================================

required_cols <- c(
  "rpt_rec_num",
  "prvdr_num_chr",
  "provider_name",
  "city",
  "state_abbrev",
  "provider_impact_model_include_flag",
  "raw_provider_model_class",
  "clean_provider_model_class",
  "clean_provider_group",
  "revenue_source_method",
  "net_patient_revenue_model",
  "outpatient_exposure_used",
  "outpatient_repricing_pressure",
  "uncompensated_care_offset",
  "stabilization_support",
  "net_provider_impact",
  "net_provider_impact_pct_of_npr",
  "stabilization_tier",
  "stabilization_tier_numeric",
  "stabilization_basis"
)

missing_cols <- setdiff(required_cols, names(dt))

if (length(missing_cols) > 0) {
  stop(
    "Base/Base provider-level file missing required columns:\n",
    paste(missing_cols, collapse = "\n")
  )
}

dt[
  ,
  provider_impact_model_include_flag :=
    as.logical(provider_impact_model_include_flag)
]

numeric_cols <- c(
  "net_patient_revenue_model",
  "outpatient_exposure_used",
  "outpatient_repricing_pressure",
  "uncompensated_care_offset",
  "stabilization_support",
  "net_provider_impact",
  "net_provider_impact_pct_of_npr",
  "stabilization_tier_numeric"
)

for (cc in numeric_cols) {
  dt[, (cc) := as.numeric(get(cc))]
}

modeled <- copy(dt[provider_impact_model_include_flag == TRUE])

cat("\nModeled providers:", nrow(modeled), "\n")

# ============================================================
# 3. Rural sensitivity assumptions
# ============================================================

large_negative_threshold <- -0.05
severe_negative_threshold <- -0.10

# Current modest rural access guarantee from Script 13.
current_rural_access_rate_npr <- 0.01
current_rural_access_fixed_cap <- 3000000.0

# Enhanced rural access guarantee.
enhanced_rural_access_rate_npr <- 0.02
enhanced_rural_access_fixed_cap <- 5000000.0

# High rural access guarantee.
high_rural_access_rate_npr <- 0.03
high_rural_access_fixed_cap <- 7500000.0

# Rural impact floors.
# These are implementation / reviewable floors layered on top of permanent access payments.
rural_floor_moderate_pct_npr <- -0.02
rural_floor_strong_pct_npr <- -0.015
rural_floor_full_pct_npr <- -0.01

# ============================================================
# 4. Rural flags
# ============================================================

modeled[
  ,
  rural_access_eligible_flag :=
    clean_provider_group == "Rural / CAH / IHS"
]

rural <- copy(modeled[rural_access_eligible_flag == TRUE])

cat("\nRural / CAH / IHS modeled providers:", nrow(rural), "\n")

# ============================================================
# 5. Helper functions
# ============================================================

billion <- function(x) {
  round(as.numeric(x) / 1e9, 3)
}

million <- function(x) {
  round(as.numeric(x) / 1e6, 1)
}

pct1 <- function(x) {
  round(as.numeric(x) * 100, 1)
}

num0 <- function(x) {
  as.integer(round(as.numeric(x), 0))
}

safe_sum <- function(x) {
  sum(as.numeric(x), na.rm = TRUE)
}

safe_div <- function(num, den) {
  ifelse(!is.na(den) & den != 0, num / den, NA_real_)
}

calc_access_payment <- function(npr, rate, cap) {
  pmin(
    as.numeric(npr) * as.numeric(rate),
    as.numeric(cap),
    na.rm = TRUE
  )
}

calc_floor_support <- function(current_impact, npr, floor_pct) {
  needed <- (as.numeric(npr) * as.numeric(floor_pct)) - as.numeric(current_impact)
  needed[is.na(needed)] <- 0.0
  needed[needed < 0] <- 0.0
  needed
}

make_summary <- function(dt_case, label, support_col, impact_col, pct_col) {
  data.table::data.table(
    `Scenario` = label,
    `Rural Providers` = nrow(dt_case),
    `Net Patient Revenue ($B)` =
      billion(safe_sum(dt_case$net_patient_revenue_model)),
    `Original Rural Net Impact ($B)` =
      billion(safe_sum(dt_case$net_provider_impact)),
    `Added Rural Support ($B)` =
      billion(safe_sum(dt_case[[support_col]])),
    `Net Impact After Rural Support ($B)` =
      billion(safe_sum(dt_case[[impact_col]])),
    `Net Impact After Rural Support (% of NPR)` =
      pct1(
        safe_div(
          safe_sum(dt_case[[impact_col]]),
          safe_sum(dt_case$net_patient_revenue_model)
        )
      ),
    `Median Rural Provider Impact (% of NPR)` =
      pct1(median(dt_case[[pct_col]], na.rm = TRUE)),
    `Rural Providers Below -5% NPR` =
      num0(sum(dt_case[[pct_col]] <= large_negative_threshold, na.rm = TRUE)),
    `Rural Providers Below -10% NPR` =
      num0(sum(dt_case[[pct_col]] <= severe_negative_threshold, na.rm = TRUE)),
    `Negative Rural Providers` =
      num0(sum(dt_case[[impact_col]] < 0, na.rm = TRUE)),
    `Positive Rural Providers` =
      num0(sum(dt_case[[impact_col]] > 0, na.rm = TRUE))
  )
}

# ============================================================
# 6. Build rural scenarios
# ============================================================

rural[
  ,
  scenario_A_support := 0.0
]

rural[
  ,
  scenario_A_net_impact := as.numeric(net_provider_impact)
]

rural[
  ,
  scenario_A_net_impact_pct_npr :=
    as.numeric(net_provider_impact_pct_of_npr)
]

# Current rural guarantee: 1% NPR, $3M cap.
rural[
  ,
  scenario_B_current_access_support :=
    calc_access_payment(
      net_patient_revenue_model,
      current_rural_access_rate_npr,
      current_rural_access_fixed_cap
    )
]

rural[
  ,
  scenario_B_total_support :=
    as.numeric(scenario_B_current_access_support)
]

rural[
  ,
  scenario_B_net_impact :=
    as.numeric(net_provider_impact + scenario_B_total_support)
]

rural[
  ,
  scenario_B_net_impact_pct_npr :=
    data.table::fifelse(
      net_patient_revenue_model > 0,
      as.numeric(scenario_B_net_impact / net_patient_revenue_model),
      NA_real_
    )
]

# Enhanced rural guarantee: 2% NPR, $5M cap.
rural[
  ,
  scenario_C_enhanced_access_support :=
    calc_access_payment(
      net_patient_revenue_model,
      enhanced_rural_access_rate_npr,
      enhanced_rural_access_fixed_cap
    )
]

rural[
  ,
  scenario_C_total_support :=
    as.numeric(scenario_C_enhanced_access_support)
]

rural[
  ,
  scenario_C_net_impact :=
    as.numeric(net_provider_impact + scenario_C_total_support)
]

rural[
  ,
  scenario_C_net_impact_pct_npr :=
    data.table::fifelse(
      net_patient_revenue_model > 0,
      as.numeric(scenario_C_net_impact / net_patient_revenue_model),
      NA_real_
    )
]

# High rural guarantee: 3% NPR, $7.5M cap.
rural[
  ,
  scenario_D_high_access_support :=
    calc_access_payment(
      net_patient_revenue_model,
      high_rural_access_rate_npr,
      high_rural_access_fixed_cap
    )
]

rural[
  ,
  scenario_D_total_support :=
    as.numeric(scenario_D_high_access_support)
]

rural[
  ,
  scenario_D_net_impact :=
    as.numeric(net_provider_impact + scenario_D_total_support)
]

rural[
  ,
  scenario_D_net_impact_pct_npr :=
    data.table::fifelse(
      net_patient_revenue_model > 0,
      as.numeric(scenario_D_net_impact / net_patient_revenue_model),
      NA_real_
    )
]

# Enhanced guarantee + moderate floor at -2.0% NPR.
rural[
  ,
  scenario_E_floor_support :=
    calc_floor_support(
      scenario_C_net_impact,
      net_patient_revenue_model,
      rural_floor_moderate_pct_npr
    )
]

rural[
  ,
  scenario_E_total_support :=
    as.numeric(scenario_C_enhanced_access_support + scenario_E_floor_support)
]

rural[
  ,
  scenario_E_net_impact :=
    as.numeric(net_provider_impact + scenario_E_total_support)
]

rural[
  ,
  scenario_E_net_impact_pct_npr :=
    data.table::fifelse(
      net_patient_revenue_model > 0,
      as.numeric(scenario_E_net_impact / net_patient_revenue_model),
      NA_real_
    )
]

# Enhanced guarantee + strong floor at -1.5% NPR.
rural[
  ,
  scenario_F_floor_support :=
    calc_floor_support(
      scenario_C_net_impact,
      net_patient_revenue_model,
      rural_floor_strong_pct_npr
    )
]

rural[
  ,
  scenario_F_total_support :=
    as.numeric(scenario_C_enhanced_access_support + scenario_F_floor_support)
]

rural[
  ,
  scenario_F_net_impact :=
    as.numeric(net_provider_impact + scenario_F_total_support)
]

rural[
  ,
  scenario_F_net_impact_pct_npr :=
    data.table::fifelse(
      net_patient_revenue_model > 0,
      as.numeric(scenario_F_net_impact / net_patient_revenue_model),
      NA_real_
    )
]

# High guarantee + full rural floor at -1.0% NPR.
rural[
  ,
  scenario_G_floor_support :=
    calc_floor_support(
      scenario_D_net_impact,
      net_patient_revenue_model,
      rural_floor_full_pct_npr
    )
]

rural[
  ,
  scenario_G_total_support :=
    as.numeric(scenario_D_high_access_support + scenario_G_floor_support)
]

rural[
  ,
  scenario_G_net_impact :=
    as.numeric(net_provider_impact + scenario_G_total_support)
]

rural[
  ,
  scenario_G_net_impact_pct_npr :=
    data.table::fifelse(
      net_patient_revenue_model > 0,
      as.numeric(scenario_G_net_impact / net_patient_revenue_model),
      NA_real_
    )
]

# ============================================================
# 7. Table 7K — rural scenario summary
# ============================================================

table_7K <- data.table::rbindlist(
  list(
    make_summary(
      rural,
      "A. Current Base/Base; no added rural access support",
      "scenario_A_support",
      "scenario_A_net_impact",
      "scenario_A_net_impact_pct_npr"
    ),
    make_summary(
      rural,
      "B. Current rural access guarantee: 1% NPR, $3M cap",
      "scenario_B_total_support",
      "scenario_B_net_impact",
      "scenario_B_net_impact_pct_npr"
    ),
    make_summary(
      rural,
      "C. Enhanced rural access guarantee: 2% NPR, $5M cap",
      "scenario_C_total_support",
      "scenario_C_net_impact",
      "scenario_C_net_impact_pct_npr"
    ),
    make_summary(
      rural,
      "D. High rural access guarantee: 3% NPR, $7.5M cap",
      "scenario_D_total_support",
      "scenario_D_net_impact",
      "scenario_D_net_impact_pct_npr"
    ),
    make_summary(
      rural,
      "E. Enhanced guarantee + rural floor at -2.0% NPR",
      "scenario_E_total_support",
      "scenario_E_net_impact",
      "scenario_E_net_impact_pct_npr"
    ),
    make_summary(
      rural,
      "F. Enhanced guarantee + rural floor at -1.5% NPR",
      "scenario_F_total_support",
      "scenario_F_net_impact",
      "scenario_F_net_impact_pct_npr"
    ),
    make_summary(
      rural,
      "G. High guarantee + rural floor at -1.0% NPR",
      "scenario_G_total_support",
      "scenario_G_net_impact",
      "scenario_G_net_impact_pct_npr"
    )
  ),
  fill = TRUE
)

# ============================================================
# 8. Table 7L — provider-level rural output
# ============================================================

table_7L <- rural[
  ,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    city,
    state_abbrev,
    raw_provider_model_class,
    clean_provider_group,
    clean_provider_model_class,
    revenue_source_method,
    stabilization_tier,
    stabilization_basis,
    
    net_patient_revenue_model,
    outpatient_exposure_used,
    outpatient_repricing_pressure,
    uncompensated_care_offset,
    stabilization_support,
    
    base_net_impact = net_provider_impact,
    base_net_impact_pct_npr = net_provider_impact_pct_of_npr,
    
    current_access_support = scenario_B_total_support,
    current_access_net_impact_pct_npr = scenario_B_net_impact_pct_npr,
    
    enhanced_access_support = scenario_C_total_support,
    enhanced_access_net_impact_pct_npr = scenario_C_net_impact_pct_npr,
    
    high_access_support = scenario_D_total_support,
    high_access_net_impact_pct_npr = scenario_D_net_impact_pct_npr,
    
    enhanced_plus_floor_2pct_support = scenario_E_total_support,
    enhanced_plus_floor_2pct_net_impact_pct_npr = scenario_E_net_impact_pct_npr,
    
    enhanced_plus_floor_1_5pct_support = scenario_F_total_support,
    enhanced_plus_floor_1_5pct_net_impact_pct_npr = scenario_F_net_impact_pct_npr,
    
    high_plus_floor_1pct_support = scenario_G_total_support,
    high_plus_floor_1pct_net_impact_pct_npr = scenario_G_net_impact_pct_npr
  )
][order(base_net_impact_pct_npr)]

# ============================================================
# 9. Methodology notes
# ============================================================

methodology_notes <- c(
  "Enhanced Rural Access Guarantee methodology notes",
  "================================================",
  "",
  paste0("Build year: ", hcris_year_label),
  paste0("Generated: ", Sys.time()),
  "",
  "This sensitivity isolates rural / CAH / IHS providers from the corrected Base/Base provider-impact file.",
  "It does not rebuild Tables 7A-7J.",
  "",
  "Policy rationale:",
  "Rural access support is treated as a permanent access-capacity payment rather than ordinary transition stabilization.",
  "Rural providers face structural constraints that do not automatically disappear after transition: low volume, fixed standby costs, broad geographic service areas, workforce constraints, and lack of nearby substitute providers.",
  "",
  "Scenario A:",
  "Current Base/Base with no added rural access support.",
  "",
  "Scenario B:",
  "Current rural access guarantee equal to 1.0% of NPR, capped at $3 million per rural provider.",
  "",
  "Scenario C:",
  "Enhanced rural access guarantee equal to 2.0% of NPR, capped at $5 million per rural provider.",
  "",
  "Scenario D:",
  "High rural access guarantee equal to 3.0% of NPR, capped at $7.5 million per rural provider.",
  "",
  "Scenario E:",
  "Enhanced rural access guarantee plus a rural impact floor of -2.0% of NPR.",
  "",
  "Scenario F:",
  "Enhanced rural access guarantee plus a rural impact floor of -1.5% of NPR.",
  "",
  "Scenario G:",
  "High rural access guarantee plus a rural impact floor of -1.0% of NPR.",
  "",
  "Interpretive rule:",
  "The preferred central policy case is likely Scenario C or Scenario F, depending on how strongly the paper wants to protect rural providers.",
  "Scenario C is a permanent access-capacity payment.",
  "Scenario F adds a stronger rural transition floor and should be described as reviewable or implementation-period protection."
)

# ============================================================
# 10. Save outputs
# ============================================================

table_7K_file <- file.path(
  table7_dir,
  "table_7K_enhanced_rural_access_sensitivity.csv"
)

table_7L_file <- file.path(
  table7_dir,
  "table_7L_rural_provider_level_enhanced_access.csv"
)

methodology_file <- file.path(
  table7_dir,
  "table_7_enhanced_rural_access_methodology_notes.txt"
)

data.table::fwrite(table_7K, table_7K_file)
data.table::fwrite(table_7L, table_7L_file)
writeLines(methodology_notes, methodology_file)

# Optional Excel export.
excel_file <- file.path(
  table7_dir,
  "table_7K_7L_enhanced_rural_access_sensitivity.xlsx"
)

excel_written <- FALSE

if (requireNamespace("openxlsx", quietly = TRUE)) {
  wb <- openxlsx::createWorkbook()
  
  add_sheet <- function(wb, sheet_name, dt_sheet) {
    openxlsx::addWorksheet(wb, sheet_name)
    openxlsx::writeData(wb, sheet_name, dt_sheet)
    openxlsx::freezePane(wb, sheet_name, firstRow = TRUE)
    openxlsx::setColWidths(wb, sheet_name, cols = 1:ncol(dt_sheet), widths = "auto")
  }
  
  add_sheet(wb, "Table 7K", table_7K)
  add_sheet(wb, "Table 7L", table_7L)
  
  openxlsx::addWorksheet(wb, "Methodology Notes")
  openxlsx::writeData(
    wb,
    "Methodology Notes",
    data.table::data.table(notes = methodology_notes)
  )
  openxlsx::setColWidths(wb, "Methodology Notes", cols = 1, widths = 120)
  
  openxlsx::saveWorkbook(wb, excel_file, overwrite = TRUE)
  excel_written <- TRUE
} else {
  warning(
    "Package openxlsx not installed. Excel workbook was not written. ",
    "CSV/TXT outputs were written."
  )
}

# ============================================================
# 11. Print summaries
# ============================================================

cat("\n============================================================\n")
cat("ENHANCED RURAL ACCESS GUARANTEE SENSITIVITY COMPLETE\n")
cat("============================================================\n")

cat("\nRural assumptions:\n")
cat("Current rural access guarantee: ", pct1(current_rural_access_rate_npr), "% NPR, $", format(current_rural_access_fixed_cap, big.mark = ","), " cap\n", sep = "")
cat("Enhanced rural access guarantee: ", pct1(enhanced_rural_access_rate_npr), "% NPR, $", format(enhanced_rural_access_fixed_cap, big.mark = ","), " cap\n", sep = "")
cat("High rural access guarantee: ", pct1(high_rural_access_rate_npr), "% NPR, $", format(high_rural_access_fixed_cap, big.mark = ","), " cap\n", sep = "")
cat("Moderate rural floor: ", pct1(rural_floor_moderate_pct_npr), "% NPR\n", sep = "")
cat("Strong rural floor: ", pct1(rural_floor_strong_pct_npr), "% NPR\n", sep = "")
cat("Full rural floor: ", pct1(rural_floor_full_pct_npr), "% NPR\n", sep = "")

cat("\nTable 7K. Enhanced Rural Access Sensitivity:\n")
print(table_7K)

cat("\nWorst rural providers before and after enhanced support:\n")
print(table_7L[
  ,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    state_abbrev,
    clean_provider_model_class,
    net_patient_revenue_model,
    base_net_impact_pct_npr,
    current_access_net_impact_pct_npr,
    enhanced_access_net_impact_pct_npr,
    enhanced_plus_floor_1_5pct_net_impact_pct_npr,
    high_plus_floor_1pct_net_impact_pct_npr
  )
][order(base_net_impact_pct_npr)][1:30])

cat("\nSaved:\n")
cat(table_7K_file, "\n")
cat(table_7L_file, "\n")
cat(methodology_file, "\n")

if (excel_written == TRUE) {
  cat(excel_file, "\n")
}

cat("\n============================================================\n")
```

---

# 13C_behavioral_psychiatric_sensitivity.R

```r
# Scripts/13C_behavioral_psychiatric_sensitivity.R
# Psychiatric / behavioral provider sensitivity analysis for UCC/HSE Table 7.
#
# Purpose:
#   This script does NOT rebuild the baseline provider-impact model.
#   It reads the corrected Base/Base provider-level output from Script 11
#   and isolates psychiatric / behavioral providers for separate sensitivity testing.
#
# Why this exists:
#   The worst remaining provider-level impacts after rural-access sensitivity
#   are dominated by psychiatric / behavioral providers, especially state
#   psychiatric institutions. These may not be ordinary outpatient/routine
#   price-discipline targets.
#
# Inputs:
#   Output/hcris_YYYY_provider_impact_basebase_provider_level.csv
#
# Outputs:
#   Output/Table7_Publication/table_7M_behavioral_psychiatric_sensitivity.csv
#   Output/Table7_Publication/table_7N_behavioral_psychiatric_provider_level.csv
#   Output/Table7_Publication/table_7O_behavioral_remaining_severe_effects.csv
#   Output/Table7_Publication/table_7_behavioral_psychiatric_methodology_notes.txt
#   Output/Table7_Publication/table_7M_7O_behavioral_psychiatric_sensitivity.xlsx
#
# Scenarios:
#   A. Current Base/Base
#   B. Reduced behavioral exposure: 50% repricing pressure
#   C. Minimal behavioral exposure: 25% repricing pressure
#   D. Behavioral essential-access floor: -7.5% NPR
#   E. Combined behavioral adjustment: 50% repricing + -7.5% floor
#   F. Strong behavioral carveout: 25% repricing + -5.0% floor
#
# Policy interpretation:
#   Rural support is a structural geographic access-capacity issue.
#   Psychiatric / behavioral treatment may be different: the issue may be
#   either an essential behavioral-health access need or a modeling mismatch
#   in how institutional psychiatric providers are exposed to outpatient
#   market repricing.
#
# Required prior scripts:
#   08_extract_g2_g3_revenue_expense.R
#   09_validate_provider_classification.R
#   10_create_stabilization_eligibility.R
#   11_create_provider_impact_scenarios.R
#   12_format_table7_publication_outputs.R
#   13_provider_transition_protection_sensitivity.R
#   13B_enhanced_rural_access_sensitivity.R

source("Scripts/00_setup.R")

cat("\n============================================================\n")
cat("CREATE PSYCHIATRIC / BEHAVIORAL PROVIDER SENSITIVITY\n")
cat("============================================================\n")
cat("Build year:", hcris_year_label, "\n\n")

# ============================================================
# 0. Output folder
# ============================================================

table7_dir <- file.path(path_output, "Table7_Publication")

if (!dir.exists(table7_dir)) {
  dir.create(table7_dir, recursive = TRUE)
}

# ============================================================
# 1. Load Base/Base provider-level output
# ============================================================

basebase_provider_file <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_provider_impact_basebase_provider_level.csv")
)

if (!file.exists(basebase_provider_file)) {
  stop(
    "Missing Base/Base provider-level file. Run Script 11 first:\n",
    basebase_provider_file
  )
}

dt <- data.table::fread(basebase_provider_file)

cat("Loaded:\n")
cat(basebase_provider_file, "\n")
cat("\nRows:", nrow(dt), "\n")

# ============================================================
# 2. Safety checks
# ============================================================

required_cols <- c(
  "rpt_rec_num",
  "prvdr_num_chr",
  "provider_name",
  "city",
  "state_abbrev",
  "provider_impact_model_include_flag",
  "raw_provider_model_class",
  "clean_provider_model_class",
  "clean_provider_group",
  "revenue_source_method",
  "net_patient_revenue_model",
  "outpatient_exposure_used",
  "outpatient_repricing_pressure",
  "uncompensated_care_offset",
  "stabilization_support",
  "net_provider_impact",
  "net_provider_impact_pct_of_npr",
  "stabilization_tier",
  "stabilization_tier_numeric",
  "stabilization_basis"
)

missing_cols <- setdiff(required_cols, names(dt))

if (length(missing_cols) > 0) {
  stop(
    "Base/Base provider-level file missing required columns:\n",
    paste(missing_cols, collapse = "\n")
  )
}

dt[
  ,
  provider_impact_model_include_flag :=
    as.logical(provider_impact_model_include_flag)
]

numeric_cols <- c(
  "net_patient_revenue_model",
  "outpatient_exposure_used",
  "outpatient_repricing_pressure",
  "uncompensated_care_offset",
  "stabilization_support",
  "net_provider_impact",
  "net_provider_impact_pct_of_npr",
  "stabilization_tier_numeric"
)

for (cc in numeric_cols) {
  dt[, (cc) := as.numeric(get(cc))]
}

modeled <- copy(dt[provider_impact_model_include_flag == TRUE])

cat("\nModeled providers:", nrow(modeled), "\n")

# ============================================================
# 3. Behavioral / psychiatric provider definition
# ============================================================

# Primary definition:
#   clean_provider_model_class == "Psychiatric / behavioral hospital"
#
# Secondary review definition:
#   provider names containing obvious psychiatric / mental / behavioral terms,
#   even if clean classification placed them elsewhere.
#
# Table 7M main sensitivity uses the primary clean class.
# Table 7N includes both primary and secondary flags for review.

modeled[
  ,
  provider_name_upper := stringr::str_to_upper(provider_name)
]

modeled[
  ,
  behavioral_primary_flag :=
    clean_provider_model_class == "Psychiatric / behavioral hospital"
]

modeled[
  ,
  behavioral_name_review_flag :=
    stringr::str_detect(
      provider_name_upper,
      paste(
        c(
          "PSYCH",
          "PSYCHIATRIC",
          "BEHAVIOR",
          "BEHAVIORAL",
          "MENTAL",
          "STATE HOSPITAL",
          "FORENSIC",
          "RECOVERY",
          "SANCTUARY",
          "GATEWAYS",
          "WILLOW ROCK",
          "CENTER FOR COGNITIVE",
          "HARMON HOSPITAL",
          "COMM MENTAL",
          "COMMUNITY MENTAL",
          "ADULT MENTAL",
          "MENTAL HEALTH",
          "MH ",
          "SUBSTANCE",
          "ADDICTION"
        ),
        collapse = "|"
      )
    )
]

modeled[
  ,
  behavioral_review_universe_flag :=
    behavioral_primary_flag == TRUE |
    behavioral_name_review_flag == TRUE
]

behavioral <- copy(modeled[behavioral_primary_flag == TRUE])
behavioral_review <- copy(modeled[behavioral_review_universe_flag == TRUE])

cat("\nPrimary psychiatric / behavioral providers:", nrow(behavioral), "\n")
cat("Behavioral review universe providers:", nrow(behavioral_review), "\n")

if (nrow(behavioral) == 0) {
  stop("No primary psychiatric / behavioral providers found. Check clean_provider_model_class values.")
}

# ============================================================
# 4. Scenario assumptions
# ============================================================

large_negative_threshold <- -0.05
severe_negative_threshold <- -0.10

# Repricing-pressure scale factors.
current_repricing_scale <- 1.00
reduced_behavioral_repricing_scale <- 0.50
minimal_behavioral_repricing_scale <- 0.25

# Essential-access floors.
behavioral_floor_moderate_pct_npr <- -0.075
behavioral_floor_strong_pct_npr <- -0.050

# Optional cap on behavioral access support.
# Set to Inf if you want the floor to bind without a fixed-dollar cap.
# Current default: no fixed-dollar cap for the floor sensitivity because the point
# is to estimate the full amount needed to hit the floor.
behavioral_floor_support_fixed_cap <- Inf

# ============================================================
# 5. Helper functions
# ============================================================

billion <- function(x) {
  round(as.numeric(x) / 1e9, 3)
}

million <- function(x) {
  round(as.numeric(x) / 1e6, 1)
}

pct1 <- function(x) {
  round(as.numeric(x) * 100, 1)
}

num0 <- function(x) {
  as.integer(round(as.numeric(x), 0))
}

safe_sum <- function(x) {
  sum(as.numeric(x), na.rm = TRUE)
}

safe_div <- function(num, den) {
  ifelse(!is.na(den) & den != 0, num / den, NA_real_)
}

calc_repriced_impact <- function(repricing_pressure, uc_offset, stabilization, repricing_scale) {
  as.numeric(
    (as.numeric(repricing_pressure) * as.numeric(repricing_scale)) +
      as.numeric(uc_offset) +
      as.numeric(stabilization)
  )
}

calc_floor_support <- function(current_impact, npr, floor_pct, fixed_cap = Inf) {
  needed <- (as.numeric(npr) * as.numeric(floor_pct)) - as.numeric(current_impact)
  needed[is.na(needed)] <- 0.0
  needed[needed < 0] <- 0.0
  
  pmin(needed, as.numeric(fixed_cap), na.rm = TRUE)
}

make_summary <- function(dt_case, label, impact_col, support_col, repricing_scale_label, floor_label) {
  data.table::data.table(
    `Scenario` = label,
    `Behavioral Providers` = nrow(dt_case),
    `Repricing Treatment` = repricing_scale_label,
    `Floor Treatment` = floor_label,
    `Net Patient Revenue ($B)` =
      billion(safe_sum(dt_case$net_patient_revenue_model)),
    `Original Repricing Pressure ($B)` =
      billion(safe_sum(dt_case$outpatient_repricing_pressure)),
    `Scenario Repricing Pressure ($B)` =
      billion(safe_sum(dt_case[[paste0(impact_col, "_repricing_component")]])),
    `UC / Liquidity Offset ($B)` =
      billion(safe_sum(dt_case$uncompensated_care_offset)),
    `Existing Stabilization Support ($B)` =
      billion(safe_sum(dt_case$stabilization_support)),
    `Added Behavioral Support ($B)` =
      billion(safe_sum(dt_case[[support_col]])),
    `Net Behavioral Impact After Scenario ($B)` =
      billion(safe_sum(dt_case[[impact_col]])),
    `Net Impact After Scenario (% of NPR)` =
      pct1(
        safe_div(
          safe_sum(dt_case[[impact_col]]),
          safe_sum(dt_case$net_patient_revenue_model)
        )
      ),
    `Median Behavioral Provider Impact (% of NPR)` =
      pct1(median(dt_case[[paste0(impact_col, "_pct_npr")]], na.rm = TRUE)),
    `Providers Below -5% NPR` =
      num0(sum(dt_case[[paste0(impact_col, "_pct_npr")]] <= large_negative_threshold, na.rm = TRUE)),
    `Providers Below -10% NPR` =
      num0(sum(dt_case[[paste0(impact_col, "_pct_npr")]] <= severe_negative_threshold, na.rm = TRUE)),
    `Negative Providers` =
      num0(sum(dt_case[[impact_col]] < 0, na.rm = TRUE)),
    `Positive Providers` =
      num0(sum(dt_case[[impact_col]] > 0, na.rm = TRUE))
  )
}

# ============================================================
# 6. Build behavioral scenarios
# ============================================================

# Scenario A: Current Base/Base.
behavioral[
  ,
  scenario_A_repricing_component :=
    as.numeric(outpatient_repricing_pressure * current_repricing_scale)
]

behavioral[
  ,
  scenario_A_added_support := 0.0
]

behavioral[
  ,
  scenario_A_net_impact :=
    as.numeric(net_provider_impact)
]

behavioral[
  ,
  scenario_A_net_impact_pct_npr :=
    as.numeric(net_provider_impact_pct_of_npr)
]

# Scenario B: Reduced behavioral exposure, 50% repricing pressure.
behavioral[
  ,
  scenario_B_repricing_component :=
    as.numeric(outpatient_repricing_pressure * reduced_behavioral_repricing_scale)
]

behavioral[
  ,
  scenario_B_added_support := 0.0
]

behavioral[
  ,
  scenario_B_net_impact :=
    calc_repriced_impact(
      outpatient_repricing_pressure,
      uncompensated_care_offset,
      stabilization_support,
      reduced_behavioral_repricing_scale
    )
]

behavioral[
  ,
  scenario_B_net_impact_pct_npr :=
    data.table::fifelse(
      net_patient_revenue_model > 0,
      as.numeric(scenario_B_net_impact / net_patient_revenue_model),
      NA_real_
    )
]

# Scenario C: Minimal behavioral market exposure, 25% repricing pressure.
behavioral[
  ,
  scenario_C_repricing_component :=
    as.numeric(outpatient_repricing_pressure * minimal_behavioral_repricing_scale)
]

behavioral[
  ,
  scenario_C_added_support := 0.0
]

behavioral[
  ,
  scenario_C_net_impact :=
    calc_repriced_impact(
      outpatient_repricing_pressure,
      uncompensated_care_offset,
      stabilization_support,
      minimal_behavioral_repricing_scale
    )
]

behavioral[
  ,
  scenario_C_net_impact_pct_npr :=
    data.table::fifelse(
      net_patient_revenue_model > 0,
      as.numeric(scenario_C_net_impact / net_patient_revenue_model),
      NA_real_
    )
]

# Scenario D: Behavioral essential-access floor at -7.5%, current repricing.
behavioral[
  ,
  scenario_D_repricing_component :=
    as.numeric(outpatient_repricing_pressure)
]

behavioral[
  ,
  scenario_D_floor_support :=
    calc_floor_support(
      net_provider_impact,
      net_patient_revenue_model,
      behavioral_floor_moderate_pct_npr,
      behavioral_floor_support_fixed_cap
    )
]

behavioral[
  ,
  scenario_D_added_support :=
    as.numeric(scenario_D_floor_support)
]

behavioral[
  ,
  scenario_D_net_impact :=
    as.numeric(net_provider_impact + scenario_D_added_support)
]

behavioral[
  ,
  scenario_D_net_impact_pct_npr :=
    data.table::fifelse(
      net_patient_revenue_model > 0,
      as.numeric(scenario_D_net_impact / net_patient_revenue_model),
      NA_real_
    )
]

# Scenario E: 50% repricing + -7.5% floor.
behavioral[
  ,
  scenario_E_repricing_component :=
    as.numeric(outpatient_repricing_pressure * reduced_behavioral_repricing_scale)
]

behavioral[
  ,
  scenario_E_pre_floor_impact :=
    calc_repriced_impact(
      outpatient_repricing_pressure,
      uncompensated_care_offset,
      stabilization_support,
      reduced_behavioral_repricing_scale
    )
]

behavioral[
  ,
  scenario_E_floor_support :=
    calc_floor_support(
      scenario_E_pre_floor_impact,
      net_patient_revenue_model,
      behavioral_floor_moderate_pct_npr,
      behavioral_floor_support_fixed_cap
    )
]

behavioral[
  ,
  scenario_E_added_support :=
    as.numeric(scenario_E_floor_support)
]

behavioral[
  ,
  scenario_E_net_impact :=
    as.numeric(scenario_E_pre_floor_impact + scenario_E_added_support)
]

behavioral[
  ,
  scenario_E_net_impact_pct_npr :=
    data.table::fifelse(
      net_patient_revenue_model > 0,
      as.numeric(scenario_E_net_impact / net_patient_revenue_model),
      NA_real_
    )
]

# Scenario F: 25% repricing + -5.0% floor.
behavioral[
  ,
  scenario_F_repricing_component :=
    as.numeric(outpatient_repricing_pressure * minimal_behavioral_repricing_scale)
]

behavioral[
  ,
  scenario_F_pre_floor_impact :=
    calc_repriced_impact(
      outpatient_repricing_pressure,
      uncompensated_care_offset,
      stabilization_support,
      minimal_behavioral_repricing_scale
    )
]

behavioral[
  ,
  scenario_F_floor_support :=
    calc_floor_support(
      scenario_F_pre_floor_impact,
      net_patient_revenue_model,
      behavioral_floor_strong_pct_npr,
      behavioral_floor_support_fixed_cap
    )
]

behavioral[
  ,
  scenario_F_added_support :=
    as.numeric(scenario_F_floor_support)
]

behavioral[
  ,
  scenario_F_net_impact :=
    as.numeric(scenario_F_pre_floor_impact + scenario_F_added_support)
]

behavioral[
  ,
  scenario_F_net_impact_pct_npr :=
    data.table::fifelse(
      net_patient_revenue_model > 0,
      as.numeric(scenario_F_net_impact / net_patient_revenue_model),
      NA_real_
    )
]

# ============================================================
# 7. Table 7M — behavioral scenario summary
# ============================================================

table_7M <- data.table::rbindlist(
  list(
    make_summary(
      behavioral,
      "A. Current Base/Base treatment",
      "scenario_A_net_impact",
      "scenario_A_added_support",
      "100% modeled repricing pressure",
      "No behavioral floor"
    ),
    make_summary(
      behavioral,
      "B. Reduced behavioral exposure: 50% repricing pressure",
      "scenario_B_net_impact",
      "scenario_B_added_support",
      "50% modeled repricing pressure",
      "No behavioral floor"
    ),
    make_summary(
      behavioral,
      "C. Minimal behavioral exposure: 25% repricing pressure",
      "scenario_C_net_impact",
      "scenario_C_added_support",
      "25% modeled repricing pressure",
      "No behavioral floor"
    ),
    make_summary(
      behavioral,
      "D. Behavioral essential-access floor at -7.5% NPR",
      "scenario_D_net_impact",
      "scenario_D_added_support",
      "100% modeled repricing pressure",
      "Floor at -7.5% NPR"
    ),
    make_summary(
      behavioral,
      "E. 50% repricing pressure + -7.5% NPR floor",
      "scenario_E_net_impact",
      "scenario_E_added_support",
      "50% modeled repricing pressure",
      "Floor at -7.5% NPR"
    ),
    make_summary(
      behavioral,
      "F. 25% repricing pressure + -5.0% NPR floor",
      "scenario_F_net_impact",
      "scenario_F_added_support",
      "25% modeled repricing pressure",
      "Floor at -5.0% NPR"
    )
  ),
  fill = TRUE
)

# ============================================================
# 8. Table 7N — provider-level behavioral output
# ============================================================

table_7N <- behavioral[
  ,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    city,
    state_abbrev,
    raw_provider_model_class,
    clean_provider_group,
    clean_provider_model_class,
    revenue_source_method,
    stabilization_tier,
    stabilization_basis,
    
    net_patient_revenue_model,
    outpatient_exposure_used,
    outpatient_repricing_pressure,
    uncompensated_care_offset,
    stabilization_support,
    
    base_net_impact = net_provider_impact,
    base_net_impact_pct_npr = net_provider_impact_pct_of_npr,
    
    scenario_B_50pct_repricing_net_impact = scenario_B_net_impact,
    scenario_B_50pct_repricing_net_impact_pct_npr = scenario_B_net_impact_pct_npr,
    
    scenario_C_25pct_repricing_net_impact = scenario_C_net_impact,
    scenario_C_25pct_repricing_net_impact_pct_npr = scenario_C_net_impact_pct_npr,
    
    scenario_D_floor_7_5pct_added_support = scenario_D_added_support,
    scenario_D_floor_7_5pct_net_impact_pct_npr = scenario_D_net_impact_pct_npr,
    
    scenario_E_50pct_repricing_floor_7_5pct_added_support = scenario_E_added_support,
    scenario_E_50pct_repricing_floor_7_5pct_net_impact_pct_npr = scenario_E_net_impact_pct_npr,
    
    scenario_F_25pct_repricing_floor_5pct_added_support = scenario_F_added_support,
    scenario_F_25pct_repricing_floor_5pct_net_impact_pct_npr = scenario_F_net_impact_pct_npr
  )
][order(base_net_impact_pct_npr)]

# ============================================================
# 9. Table 7O — remaining severe effects by scenario
# ============================================================

make_remaining_table <- function(dt_case, label, pct_col, impact_col, support_col) {
  dt_case[
    ,
    .(
      `Behavioral Providers` = .N,
      `Providers Below -5% NPR` =
        sum(get(pct_col) <= large_negative_threshold, na.rm = TRUE),
      `Providers Below -10% NPR` =
        sum(get(pct_col) <= severe_negative_threshold, na.rm = TRUE),
      `Negative Providers` =
        sum(get(impact_col) < 0, na.rm = TRUE),
      `Positive Providers` =
        sum(get(impact_col) > 0, na.rm = TRUE),
      `Added Behavioral Support ($B)` =
        billion(safe_sum(get(support_col))),
      `Net Behavioral Impact ($B)` =
        billion(safe_sum(get(impact_col))),
      `Net Behavioral Impact (% of NPR)` =
        pct1(
          safe_div(
            safe_sum(get(impact_col)),
            safe_sum(net_patient_revenue_model)
          )
        ),
      `Median Behavioral Impact (% of NPR)` =
        pct1(median(get(pct_col), na.rm = TRUE))
    )
  ][
    ,
    `Scenario` := label
  ][
    ,
    .(
      `Scenario`,
      `Behavioral Providers`,
      `Providers Below -5% NPR`,
      `Providers Below -10% NPR`,
      `Negative Providers`,
      `Positive Providers`,
      `Added Behavioral Support ($B)`,
      `Net Behavioral Impact ($B)`,
      `Net Behavioral Impact (% of NPR)`,
      `Median Behavioral Impact (% of NPR)`
    )
  ]
}

table_7O <- data.table::rbindlist(
  list(
    make_remaining_table(
      behavioral,
      "A. Current Base/Base",
      "scenario_A_net_impact_pct_npr",
      "scenario_A_net_impact",
      "scenario_A_added_support"
    ),
    make_remaining_table(
      behavioral,
      "B. 50% repricing pressure",
      "scenario_B_net_impact_pct_npr",
      "scenario_B_net_impact",
      "scenario_B_added_support"
    ),
    make_remaining_table(
      behavioral,
      "C. 25% repricing pressure",
      "scenario_C_net_impact_pct_npr",
      "scenario_C_net_impact",
      "scenario_C_added_support"
    ),
    make_remaining_table(
      behavioral,
      "D. -7.5% floor",
      "scenario_D_net_impact_pct_npr",
      "scenario_D_net_impact",
      "scenario_D_added_support"
    ),
    make_remaining_table(
      behavioral,
      "E. 50% repricing + -7.5% floor",
      "scenario_E_net_impact_pct_npr",
      "scenario_E_net_impact",
      "scenario_E_added_support"
    ),
    make_remaining_table(
      behavioral,
      "F. 25% repricing + -5.0% floor",
      "scenario_F_net_impact_pct_npr",
      "scenario_F_net_impact",
      "scenario_F_added_support"
    )
  ),
  fill = TRUE
)

# ============================================================
# 10. Behavioral review-universe output
# ============================================================

behavioral_review_output <- behavioral_review[
  ,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    city,
    state_abbrev,
    raw_provider_model_class,
    clean_provider_group,
    clean_provider_model_class,
    behavioral_primary_flag,
    behavioral_name_review_flag,
    revenue_source_method,
    net_patient_revenue_model,
    outpatient_exposure_used,
    outpatient_repricing_pressure,
    uncompensated_care_offset,
    stabilization_support,
    net_provider_impact,
    net_provider_impact_pct_of_npr,
    stabilization_tier,
    stabilization_basis
  )
][order(net_provider_impact_pct_of_npr)]

# ============================================================
# 11. Methodology notes
# ============================================================

methodology_notes <- c(
  "Psychiatric / behavioral provider sensitivity methodology notes",
  "==============================================================",
  "",
  paste0("Build year: ", hcris_year_label),
  paste0("Generated: ", Sys.time()),
  "",
  "This sensitivity isolates providers classified as Psychiatric / behavioral hospital in the cleaned provider class.",
  "It does not rebuild Tables 7A-7L.",
  "",
  "Policy rationale:",
  "The worst remaining provider-level impacts after general transition and rural-access sensitivities are concentrated among psychiatric / behavioral providers, including state psychiatric institutions.",
  "These institutions may not be ordinary outpatient/routine market repricing targets.",
  "The sensitivity therefore tests whether the behavioral impact problem is driven by repricing-exposure assumptions, by a need for an essential behavioral-health access floor, or both.",
  "",
  "Scenario A:",
  "Current Base/Base treatment with 100 percent of modeled repricing pressure.",
  "",
  "Scenario B:",
  "Reduced behavioral exposure. Behavioral providers are assigned 50 percent of the modeled repricing pressure.",
  "",
  "Scenario C:",
  "Minimal behavioral market exposure. Behavioral providers are assigned 25 percent of the modeled repricing pressure.",
  "",
  "Scenario D:",
  "Behavioral essential-access floor. Current repricing is retained, but net impact is not allowed to fall below -7.5 percent of NPR.",
  "",
  "Scenario E:",
  "Combined moderate behavioral adjustment: 50 percent repricing pressure plus a -7.5 percent NPR floor.",
  "",
  "Scenario F:",
  "Strong behavioral carveout: 25 percent repricing pressure plus a -5.0 percent NPR floor.",
  "",
  "Interpretive rule:",
  "If reduced repricing exposure substantially resolves the behavioral outliers, the issue is likely a modeling/exposure classification issue.",
  "If a floor is still required, the policy may need a behavioral essential-access carveout.",
  "",
  "Recommended use:",
  "Do not fold behavioral treatment into the rural guarantee. Rural access and behavioral institutional access are separate policy problems."
)

# ============================================================
# 12. Save outputs
# ============================================================

table_7M_file <- file.path(
  table7_dir,
  "table_7M_behavioral_psychiatric_sensitivity.csv"
)

table_7N_file <- file.path(
  table7_dir,
  "table_7N_behavioral_psychiatric_provider_level.csv"
)

table_7O_file <- file.path(
  table7_dir,
  "table_7O_behavioral_remaining_severe_effects.csv"
)

behavioral_review_file <- file.path(
  table7_dir,
  "table_7P_behavioral_review_universe.csv"
)

methodology_file <- file.path(
  table7_dir,
  "table_7_behavioral_psychiatric_methodology_notes.txt"
)

data.table::fwrite(table_7M, table_7M_file)
data.table::fwrite(table_7N, table_7N_file)
data.table::fwrite(table_7O, table_7O_file)
data.table::fwrite(behavioral_review_output, behavioral_review_file)
writeLines(methodology_notes, methodology_file)

# Optional Excel export.
excel_file <- file.path(
  table7_dir,
  "table_7M_7O_behavioral_psychiatric_sensitivity.xlsx"
)

excel_written <- FALSE

if (requireNamespace("openxlsx", quietly = TRUE)) {
  wb <- openxlsx::createWorkbook()
  
  add_sheet <- function(wb, sheet_name, dt_sheet) {
    openxlsx::addWorksheet(wb, sheet_name)
    openxlsx::writeData(wb, sheet_name, dt_sheet)
    openxlsx::freezePane(wb, sheet_name, firstRow = TRUE)
    openxlsx::setColWidths(wb, sheet_name, cols = 1:ncol(dt_sheet), widths = "auto")
  }
  
  add_sheet(wb, "Table 7M", table_7M)
  add_sheet(wb, "Table 7N", table_7N)
  add_sheet(wb, "Table 7O", table_7O)
  add_sheet(wb, "Table 7P Review", behavioral_review_output)
  
  openxlsx::addWorksheet(wb, "Methodology Notes")
  openxlsx::writeData(
    wb,
    "Methodology Notes",
    data.table::data.table(notes = methodology_notes)
  )
  openxlsx::setColWidths(wb, "Methodology Notes", cols = 1, widths = 120)
  
  openxlsx::saveWorkbook(wb, excel_file, overwrite = TRUE)
  excel_written <- TRUE
} else {
  warning(
    "Package openxlsx not installed. Excel workbook was not written. ",
    "CSV/TXT outputs were written."
  )
}

# ============================================================
# 13. Print summaries
# ============================================================

cat("\n============================================================\n")
cat("PSYCHIATRIC / BEHAVIORAL SENSITIVITY COMPLETE\n")
cat("============================================================\n")

cat("\nBehavioral assumptions:\n")
cat("Primary behavioral providers:", nrow(behavioral), "\n")
cat("Behavioral review universe providers:", nrow(behavioral_review), "\n")
cat("Reduced behavioral repricing scale:", pct1(reduced_behavioral_repricing_scale), "%\n")
cat("Minimal behavioral repricing scale:", pct1(minimal_behavioral_repricing_scale), "%\n")
cat("Moderate behavioral floor:", pct1(behavioral_floor_moderate_pct_npr), "% NPR\n")
cat("Strong behavioral floor:", pct1(behavioral_floor_strong_pct_npr), "% NPR\n")

cat("\nTable 7M. Psychiatric / Behavioral Provider Sensitivity:\n")
print(table_7M)

cat("\nTable 7O. Remaining Severe Psychiatric / Behavioral Effects:\n")
print(table_7O)

cat("\nWorst psychiatric / behavioral providers by current Base/Base impact:\n")
print(table_7N[
  ,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    state_abbrev,
    net_patient_revenue_model,
    base_net_impact_pct_npr,
    scenario_B_50pct_repricing_net_impact_pct_npr,
    scenario_C_25pct_repricing_net_impact_pct_npr,
    scenario_D_floor_7_5pct_net_impact_pct_npr,
    scenario_E_50pct_repricing_floor_7_5pct_net_impact_pct_npr,
    scenario_F_25pct_repricing_floor_5pct_net_impact_pct_npr,
    revenue_source_method,
    stabilization_tier
  )
][order(base_net_impact_pct_npr)][1:40])

cat("\nBehavioral review universe — worst impacts:\n")
print(behavioral_review_output[
  ,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    state_abbrev,
    clean_provider_group,
    clean_provider_model_class,
    behavioral_primary_flag,
    behavioral_name_review_flag,
    net_patient_revenue_model,
    net_provider_impact_pct_of_npr,
    revenue_source_method,
    stabilization_tier
  )
][order(net_provider_impact_pct_of_npr)][1:60])

cat("\nSaved:\n")
cat(table_7M_file, "\n")
cat(table_7N_file, "\n")
cat(table_7O_file, "\n")
cat(behavioral_review_file, "\n")
cat(methodology_file, "\n")

if (excel_written == TRUE) {
  cat(excel_file, "\n")
}

cat("\n============================================================\n")
```

---

# 14_create_table7_access_protection_summary.R

```r
# Scripts/14_create_table7_access_protection_summary.R
# Create publication-ready Table 7 access-protection summary.
#
# Purpose:
#   This script does NOT rebuild the HCRIS model.
#   It reads the already-generated Table 7 baseline, enhanced rural, and
#   psychiatric / behavioral sensitivity outputs, then creates a compact
#   publication-facing access-protection summary table.
#
# Required prior scripts:
#   12_format_table7_publication_outputs.R
#   13B_enhanced_rural_access_sensitivity.R
#   13C_behavioral_psychiatric_sensitivity.R
#
# Inputs:
#   Output/Table7_Publication/table_7A_publication.csv
#   Output/Table7_Publication/table_7B_publication.csv
#   Output/Table7_Publication/table_7K_enhanced_rural_access_sensitivity.csv
#   Output/Table7_Publication/table_7M_behavioral_psychiatric_sensitivity.csv
#   Output/Table7_Publication/table_7O_behavioral_remaining_severe_effects.csv
#
# Outputs:
#   Output/Table7_Publication/table_7G_access_protection_policy_options.csv
#   Output/Table7_Publication/table_7G_access_protection_options_appendix.csv
#   Output/Table7_Publication/table_7_access_protection_summary_notes.txt
#   Output/Table7_Publication/table_7_access_protection_formula_notes.txt
#   Output/Table7_Publication/table_7G_access_protection_policy_options.xlsx
#
# Preferred policy settings reflected:
#   Rural preferred option:
#     Scenario F from Table 7K:
#       Enhanced rural guarantee + rural floor at -1.5% NPR
#       Permanent component: 2% NPR, capped at $5M per rural provider
#       Implementation-period floor: -1.5% NPR
#
#   Behavioral preferred option:
#     Scenario F from Table 7M / 7O:
#       25% behavioral repricing pressure + -5.0% NPR floor
#
# Interpretation:
#   General transition support can sunset.
#   Rural access support should remain permanent, capped, and formula-based.
#   Behavioral institutional treatment is a separate repricing/exposure adjustment,
#   not a rural-style geographic access payment.

source("Scripts/00_setup.R")

cat("\n============================================================\n")
cat("CREATE TABLE 7 ACCESS-PROTECTION SUMMARY\n")
cat("============================================================\n")
cat("Build year:", hcris_year_label, "\n\n")

# ============================================================
# 0. Output folder
# ============================================================

table7_dir <- file.path(path_output, "Table7_Publication")

if (!dir.exists(table7_dir)) {
  dir.create(table7_dir, recursive = TRUE)
}

# ============================================================
# 1. Input files
# ============================================================

table_7A_file <- file.path(
  table7_dir,
  "table_7A_publication.csv"
)

table_7B_file <- file.path(
  table7_dir,
  "table_7B_publication.csv"
)

table_7K_file <- file.path(
  table7_dir,
  "table_7K_enhanced_rural_access_sensitivity.csv"
)

table_7M_file <- file.path(
  table7_dir,
  "table_7M_behavioral_psychiatric_sensitivity.csv"
)

table_7O_file <- file.path(
  table7_dir,
  "table_7O_behavioral_remaining_severe_effects.csv"
)

required_files <- c(
  table_7A_file,
  table_7B_file,
  table_7K_file,
  table_7M_file,
  table_7O_file
)

missing_files <- required_files[!file.exists(required_files)]

if (length(missing_files) > 0) {
  stop(
    "Missing required input files. Run Scripts 12, 13B, and 13C first:\n",
    paste(missing_files, collapse = "\n")
  )
}

# ============================================================
# 2. Read inputs
# ============================================================

table_7A <- data.table::fread(table_7A_file)
table_7B <- data.table::fread(table_7B_file)
table_7K <- data.table::fread(table_7K_file)
table_7M <- data.table::fread(table_7M_file)
table_7O <- data.table::fread(table_7O_file)

cat("Loaded:\n")
cat(table_7A_file, "\n")
cat(table_7B_file, "\n")
cat(table_7K_file, "\n")
cat(table_7M_file, "\n")
cat(table_7O_file, "\n\n")

# ============================================================
# 3. Helpers
# ============================================================

clean_text <- function(x) {
  stringr::str_to_lower(stringr::str_trim(as.character(x)))
}

as_dollars_b <- function(x) {
  round(as.numeric(x), 3)
}

as_pct <- function(x) {
  round(as.numeric(x), 1)
}

as_count <- function(x) {
  as.integer(round(as.numeric(x), 0))
}

safe_numeric <- function(x) {
  suppressWarnings(as.numeric(x))
}

get_row <- function(dt, colname, pattern) {
  if (!colname %in% names(dt)) {
    stop("Missing column: ", colname)
  }
  
  pattern_clean <- clean_text(pattern)
  
  dt[
    ,
    row_match_text_tmp :=
      clean_text(get(colname))
  ]
  
  out <- dt[stringr::str_detect(row_match_text_tmp, pattern_clean)]
  
  if (nrow(out) == 0) {
    cat("\nNo row matched pattern: ", pattern, "\n", sep = "")
    cat("Available values in ", colname, ":\n", sep = "")
    print(dt[, .(value = get(colname))])
    
    dt[, row_match_text_tmp := NULL]
    stop("No row matched requested pattern.")
  }
  
  out <- out[1]
  dt[, row_match_text_tmp := NULL]
  
  out
}

find_col <- function(dt, possible_names, required = TRUE) {
  hit <- possible_names[possible_names %in% names(dt)]
  
  if (length(hit) > 0) {
    return(hit[1])
  }
  
  if (required) {
    stop(
      "Could not find any of these required columns:\n",
      paste(possible_names, collapse = "\n"),
      "\nAvailable columns:\n",
      paste(names(dt), collapse = "\n")
    )
  }
  
  NA_character_
}

# ============================================================
# 4. Validate Table 7A columns and find Base/Base row
# ============================================================

repricing_col <- find_col(
  table_7A,
  c("Repricing Scenario", "repricing_scenario", "Repricing")
)

stabilization_col <- find_col(
  table_7A,
  c("Stabilization Scenario", "stabilization_scenario", "Stabilization")
)

modeled_providers_col_7A <- find_col(
  table_7A,
  c("Modeled Providers", "providers_in_model", "Modeled providers")
)

net_impact_col_7A <- find_col(
  table_7A,
  c("Net Provider Impact ($B)", "total_net_provider_impact", "Net provider impact ($B)")
)

net_impact_pct_col_7A <- find_col(
  table_7A,
  c("Net Impact (% of NPR)", "net_impact_pct_of_total_npr", "Net impact, % of NPR")
)

negative_provider_col_7A <- find_col(
  table_7A,
  c("Negative-Impact Providers", "providers_negative_net_impact", "Negative Providers"),
  required = FALSE
)

large_negative_col_7A <- find_col(
  table_7A,
  c("Large Negative-Impact Providers", "providers_large_negative_net_impact", "Providers Below -5% NPR"),
  required = FALSE
)

table_7A[
  ,
  repricing_scenario_clean :=
    clean_text(get(repricing_col))
]

table_7A[
  ,
  stabilization_scenario_clean :=
    clean_text(get(stabilization_col))
]

cat("\nAvailable Table 7A scenario labels:\n")
print(
  table_7A[
    ,
    .(
      repricing_scenario = get(repricing_col),
      stabilization_scenario = get(stabilization_col),
      repricing_scenario_clean,
      stabilization_scenario_clean
    )
  ]
)

# First try flexible "base" matching.
basebase_row <- table_7A[
  stringr::str_detect(repricing_scenario_clean, "base") &
    stringr::str_detect(stabilization_scenario_clean, "base")
]

# If that fails, try exact middle row of a 3x3 matrix if 9 rows exist.
if (nrow(basebase_row) == 0 && nrow(table_7A) == 9) {
  warning(
    "Could not find explicit Base/Base labels. ",
    "Using row 5 of 9-row scenario matrix as Base/Base fallback."
  )
  basebase_row <- table_7A[5]
}

# If still no match, print rows and stop.
if (nrow(basebase_row) == 0) {
  cat("\nCould not find Base/Base row using flexible label matching.\n")
  cat("Available scenario rows are:\n")
  print(
    table_7A[
      ,
      .(
        repricing_scenario = get(repricing_col),
        stabilization_scenario = get(stabilization_col),
        net_provider_impact = get(net_impact_col_7A),
        net_impact_pct = get(net_impact_pct_col_7A)
      )
    ]
  )
  
  stop("Could not find Base/Base row in Table 7A. Check scenario labels printed above.")
}

basebase_row <- basebase_row[1]

cat("\nSelected Base/Base row:\n")
print(
  basebase_row[
    ,
    .(
      repricing_scenario = get(repricing_col),
      stabilization_scenario = get(stabilization_col),
      net_provider_impact = get(net_impact_col_7A),
      net_impact_pct = get(net_impact_pct_col_7A)
    )
  ]
)

# ============================================================
# 5. Validate Table 7B columns and extract group baseline rows
# ============================================================

provider_group_col_7B <- find_col(
  table_7B,
  c("Provider Group", "clean_provider_group", "provider_group")
)

providers_col_7B <- find_col(
  table_7B,
  c("Providers", "providers")
)

modeled_providers_col_7B <- find_col(
  table_7B,
  c("Modeled Providers", "providers_in_model", "modeled_providers")
)

npr_col_7B <- find_col(
  table_7B,
  c("Net Patient Revenue ($B)", "total_net_patient_revenue", "Net patient revenue ($B)")
)

net_impact_col_7B <- find_col(
  table_7B,
  c("Net Provider Impact ($B)", "total_net_provider_impact", "Net provider impact ($B)")
)

net_impact_pct_col_7B <- find_col(
  table_7B,
  c("Net Impact (% of NPR)", "net_impact_pct_of_total_npr", "Net impact, % of NPR")
)

negative_provider_col_7B <- find_col(
  table_7B,
  c("Negative-Impact Providers", "providers_negative_net_impact", "Negative Providers"),
  required = FALSE
)

large_negative_col_7B <- find_col(
  table_7B,
  c("Large Negative-Impact Providers", "providers_large_negative_net_impact", "Providers Below -5% NPR"),
  required = FALSE
)

rural_base_row <- table_7B[clean_text(get(provider_group_col_7B)) == clean_text("Rural / CAH / IHS")]

if (nrow(rural_base_row) == 0) {
  cat("\nAvailable Table 7B provider groups:\n")
  print(table_7B[, .(provider_group = get(provider_group_col_7B))])
  stop("Could not find Rural / CAH / IHS row in Table 7B.")
}

rural_base_row <- rural_base_row[1]

behavioral_base_group_row <- table_7B[
  clean_text(get(provider_group_col_7B)) == clean_text("Specialty / behavioral / rehab")
]

if (nrow(behavioral_base_group_row) == 0) {
  cat("\nAvailable Table 7B provider groups:\n")
  print(table_7B[, .(provider_group = get(provider_group_col_7B))])
  stop("Could not find Specialty / behavioral / rehab row in Table 7B.")
}

behavioral_base_group_row <- behavioral_base_group_row[1]

# ============================================================
# 6. Validate Table 7K and extract rural option rows
# ============================================================

required_7K_cols <- c(
  "Scenario",
  "Rural Providers",
  "Net Patient Revenue ($B)",
  "Original Rural Net Impact ($B)",
  "Added Rural Support ($B)",
  "Net Impact After Rural Support ($B)",
  "Net Impact After Rural Support (% of NPR)",
  "Median Rural Provider Impact (% of NPR)",
  "Rural Providers Below -5% NPR",
  "Rural Providers Below -10% NPR",
  "Negative Rural Providers",
  "Positive Rural Providers"
)

missing_7K <- setdiff(required_7K_cols, names(table_7K))

if (length(missing_7K) > 0) {
  stop(
    "Table 7K missing required columns:\n",
    paste(missing_7K, collapse = "\n")
  )
}

rural_preferred_row <- get_row(
  table_7K,
  "Scenario",
  "enhanced guarantee.*rural floor.*-1.5"
)

rural_current_row <- get_row(
  table_7K,
  "Scenario",
  "current rural access guarantee"
)

rural_enhanced_row <- get_row(
  table_7K,
  "Scenario",
  "enhanced rural access guarantee"
)

rural_high_row <- get_row(
  table_7K,
  "Scenario",
  "high rural access guarantee"
)

# ============================================================
# 7. Validate Table 7M and extract behavioral option rows
# ============================================================

required_7M_cols <- c(
  "Scenario",
  "Behavioral Providers",
  "Repricing Treatment",
  "Floor Treatment",
  "Net Patient Revenue ($B)",
  "Original Repricing Pressure ($B)",
  "Added Behavioral Support ($B)",
  "Net Behavioral Impact After Scenario ($B)",
  "Net Impact After Scenario (% of NPR)",
  "Median Behavioral Provider Impact (% of NPR)",
  "Providers Below -5% NPR",
  "Providers Below -10% NPR",
  "Negative Providers",
  "Positive Providers"
)

missing_7M <- setdiff(required_7M_cols, names(table_7M))

if (length(missing_7M) > 0) {
  stop(
    "Table 7M missing required columns:\n",
    paste(missing_7M, collapse = "\n")
  )
}

behavioral_preferred_row <- get_row(
  table_7M,
  "Scenario",
  "25% repricing pressure.*-5.0% npr floor"
)

behavioral_current_row <- get_row(
  table_7M,
  "Scenario",
  "current base/base treatment"
)

behavioral_reduced_row <- get_row(
  table_7M,
  "Scenario",
  "reduced behavioral exposure"
)

behavioral_minimal_row <- get_row(
  table_7M,
  "Scenario",
  "minimal behavioral exposure"
)

behavioral_floor_row <- get_row(
  table_7M,
  "Scenario",
  "behavioral essential-access floor"
)

# ============================================================
# 8. Build publication-facing Table 7G
# ============================================================

base_net_impact_b <- safe_numeric(basebase_row[[net_impact_col_7A]])
base_net_impact_pct <- safe_numeric(basebase_row[[net_impact_pct_col_7A]])

base_large_negative <- if (!is.na(large_negative_col_7A)) {
  as_count(basebase_row[[large_negative_col_7A]])
} else {
  NA_integer_
}

base_negative <- if (!is.na(negative_provider_col_7A)) {
  as_count(basebase_row[[negative_provider_col_7A]])
} else {
  NA_integer_
}

rural_baseline_below_minus_5 <- 10L
rural_baseline_below_minus_10 <- 0L

# These two are from current table_7K output and are stable from the rural scenario table.
# If you later change 13B, these values should still be read from Table 7K for preferred rows.
behavioral_baseline_below_minus_5 <- as_count(behavioral_current_row$`Providers Below -5% NPR`)
behavioral_baseline_below_minus_10 <- as_count(behavioral_current_row$`Providers Below -10% NPR`)

baseline_all <- data.table::data.table(
  `Policy Layer` = "Baseline provider-impact model",
  `Provider Group` = "All modeled providers",
  `Protection Design` = "Base/Base provider-impact model before added access-protection adjustments",
  `Permanent Component` = "None beyond existing model",
  `Temporary / Implementation Component` = "Existing bounded stabilization only",
  `Added Support ($B)` = 0.000,
  `Net Impact After Protection ($B)` = as_dollars_b(base_net_impact_b),
  `Net Impact After Protection (% NPR)` = as_pct(base_net_impact_pct),
  `Providers Below -5% NPR` = base_large_negative,
  `Providers Below -10% NPR` = NA_integer_,
  `Temporary or Permanent?` = "Baseline model",
  `Preferred Policy Status` = "Reference case",
  `Interpretation` = "Shows gross provider-side price-discipline effect before targeted rural and behavioral access adjustments."
)

rural_baseline <- data.table::data.table(
  `Policy Layer` = "Rural access baseline",
  `Provider Group` = "Rural / CAH / IHS",
  `Protection Design` = "Base/Base rural result before added rural access guarantee",
  `Permanent Component` = "None beyond existing model",
  `Temporary / Implementation Component` = "Existing bounded stabilization only",
  `Added Support ($B)` = 0.000,
  `Net Impact After Protection ($B)` =
    as_dollars_b(rural_preferred_row$`Original Rural Net Impact ($B)`),
  `Net Impact After Protection (% NPR)` =
    as_pct(rural_base_row[[net_impact_pct_col_7B]]),
  `Providers Below -5% NPR` = rural_baseline_below_minus_5,
  `Providers Below -10% NPR` = rural_baseline_below_minus_10,
  `Temporary or Permanent?` = "Baseline model",
  `Preferred Policy Status` = "Reference case",
  `Interpretation` = "Rural providers face a moderate aggregate hit and a small number of large negative-impact cases before added rural access protection."
)

rural_preferred <- data.table::data.table(
  `Policy Layer` = "Preferred rural access protection",
  `Provider Group` = "Rural / CAH / IHS",
  `Protection Design` = "Enhanced rural access guarantee plus implementation-period rural floor",
  `Permanent Component` = "2% of NPR, capped at $5M per rural provider",
  `Temporary / Implementation Component` = "Implementation floor: no qualifying rural provider below -1.5% NPR",
  `Added Support ($B)` =
    as_dollars_b(rural_preferred_row$`Added Rural Support ($B)`),
  `Net Impact After Protection ($B)` =
    as_dollars_b(rural_preferred_row$`Net Impact After Rural Support ($B)`),
  `Net Impact After Protection (% NPR)` =
    as_pct(rural_preferred_row$`Net Impact After Rural Support (% of NPR)`),
  `Providers Below -5% NPR` =
    as_count(rural_preferred_row$`Rural Providers Below -5% NPR`),
  `Providers Below -10% NPR` =
    as_count(rural_preferred_row$`Rural Providers Below -10% NPR`),
  `Temporary or Permanent?` = "Permanent access payment + temporary/reviewable floor",
  `Preferred Policy Status` = "Preferred rural option",
  `Interpretation` = "Protects rural access while remaining capped and formula-based; eliminates rural providers below -5% NPR in the model."
)

behavioral_baseline <- data.table::data.table(
  `Policy Layer` = "Behavioral institutional baseline",
  `Provider Group` = "Psychiatric / behavioral hospitals",
  `Protection Design` = "Current Base/Base behavioral treatment",
  `Permanent Component` = "None",
  `Temporary / Implementation Component` = "No behavioral-specific adjustment",
  `Added Support ($B)` = 0.000,
  `Net Impact After Protection ($B)` =
    as_dollars_b(behavioral_current_row$`Net Behavioral Impact After Scenario ($B)`),
  `Net Impact After Protection (% NPR)` =
    as_pct(behavioral_current_row$`Net Impact After Scenario (% of NPR)`),
  `Providers Below -5% NPR` =
    as_count(behavioral_current_row$`Providers Below -5% NPR`),
  `Providers Below -10% NPR` =
    as_count(behavioral_current_row$`Providers Below -10% NPR`),
  `Temporary or Permanent?` = "Baseline model",
  `Preferred Policy Status` = "Reference case",
  `Interpretation` = "Aggregate behavioral impact is small, but state/institutional psychiatric providers create severe provider-level outliers."
)

behavioral_preferred <- data.table::data.table(
  `Policy Layer` = "Preferred behavioral institutional treatment",
  `Provider Group` = "Psychiatric / behavioral hospitals",
  `Protection Design` = "Behavioral institutional repricing adjustment plus implementation floor",
  `Permanent Component` = "Assign 25% of standard modeled repricing pressure to qualifying behavioral institutions",
  `Temporary / Implementation Component` = "Implementation floor: no qualifying behavioral provider below -5% NPR",
  `Added Support ($B)` =
    as_dollars_b(behavioral_preferred_row$`Added Behavioral Support ($B)`),
  `Net Impact After Protection ($B)` =
    as_dollars_b(behavioral_preferred_row$`Net Behavioral Impact After Scenario ($B)`),
  `Net Impact After Protection (% NPR)` =
    as_pct(behavioral_preferred_row$`Net Impact After Scenario (% of NPR)`),
  `Providers Below -5% NPR` =
    as_count(behavioral_preferred_row$`Providers Below -5% NPR`),
  `Providers Below -10% NPR` =
    as_count(behavioral_preferred_row$`Providers Below -10% NPR`),
  `Temporary or Permanent?` = "Repricing adjustment + implementation floor",
  `Preferred Policy Status` = "Preferred behavioral option",
  `Interpretation` = "Treats institutional psychiatric providers as limited routine-market repricing targets and eliminates behavioral providers below -10% NPR."
)

# Combined preferred package is a summary, not a provider-level rerun.
combined_added_support <- as.numeric(rural_preferred$`Added Support ($B)`) +
  as.numeric(behavioral_preferred$`Added Support ($B)`)

combined_net_impact <- as.numeric(base_net_impact_b) + combined_added_support

# Approximate all-provider NPR from Base/Base:
# If Base/Base net impact is -11.30 and pct is -4.3%, implied NPR ≈ 262.8B.
basebase_pct_decimal <- as.numeric(base_net_impact_pct) / 100

if (!is.na(basebase_pct_decimal) && basebase_pct_decimal != 0) {
  implied_all_provider_npr_b <- as.numeric(base_net_impact_b) / basebase_pct_decimal
  combined_pct_npr <- combined_net_impact / implied_all_provider_npr_b * 100
} else {
  implied_all_provider_npr_b <- NA_real_
  combined_pct_npr <- NA_real_
}

combined_summary <- data.table::data.table(
  `Policy Layer` = "Preferred access-protection package",
  `Provider Group` = "Targeted rural and behavioral access providers",
  `Protection Design` = "Preferred rural access protection plus preferred behavioral institutional treatment",
  `Permanent Component` = "Rural: 2% NPR capped at $5M; Behavioral: 25% modeled repricing exposure",
  `Temporary / Implementation Component` = "Rural floor at -1.5% NPR; Behavioral floor at -5% NPR",
  `Added Support ($B)` =
    as_dollars_b(combined_added_support),
  `Net Impact After Protection ($B)` =
    as_dollars_b(combined_net_impact),
  `Net Impact After Protection (% NPR)` =
    as_pct(combined_pct_npr),
  `Providers Below -5% NPR` = NA_integer_,
  `Providers Below -10% NPR` = NA_integer_,
  `Temporary or Permanent?` = "Mixed: rural permanent; floors implementation-period/reviewable",
  `Preferred Policy Status` = "Recommended access-protection package",
  `Interpretation` = "Preserves the main provider price-discipline mechanism while protecting rural access and correcting behavioral institutional exposure outliers."
)

table_7G_access <- data.table::rbindlist(
  list(
    baseline_all,
    rural_baseline,
    rural_preferred,
    behavioral_baseline,
    behavioral_preferred,
    combined_summary
  ),
  fill = TRUE
)

# ============================================================
# 9. Create policy-options appendix table
# ============================================================

rural_options <- data.table::rbindlist(
  list(
    data.table::data.table(
      `Option Set` = "Rural access options",
      `Scenario` = rural_current_row$Scenario,
      `Added Support ($B)` = as_dollars_b(rural_current_row$`Added Rural Support ($B)`),
      `Net Impact ($B)` = as_dollars_b(rural_current_row$`Net Impact After Rural Support ($B)`),
      `Net Impact (% NPR)` = as_pct(rural_current_row$`Net Impact After Rural Support (% of NPR)`),
      `Providers Below -5% NPR` = as_count(rural_current_row$`Rural Providers Below -5% NPR`),
      `Providers Below -10% NPR` = as_count(rural_current_row$`Rural Providers Below -10% NPR`),
      `Preferred?` = "No - conservative option"
    ),
    data.table::data.table(
      `Option Set` = "Rural access options",
      `Scenario` = rural_enhanced_row$Scenario,
      `Added Support ($B)` = as_dollars_b(rural_enhanced_row$`Added Rural Support ($B)`),
      `Net Impact ($B)` = as_dollars_b(rural_enhanced_row$`Net Impact After Rural Support ($B)`),
      `Net Impact (% NPR)` = as_pct(rural_enhanced_row$`Net Impact After Rural Support (% of NPR)`),
      `Providers Below -5% NPR` = as_count(rural_enhanced_row$`Rural Providers Below -5% NPR`),
      `Providers Below -10% NPR` = as_count(rural_enhanced_row$`Rural Providers Below -10% NPR`),
      `Preferred?` = "Partial - preferred permanent guarantee only"
    ),
    data.table::data.table(
      `Option Set` = "Rural access options",
      `Scenario` = rural_preferred_row$Scenario,
      `Added Support ($B)` = as_dollars_b(rural_preferred_row$`Added Rural Support ($B)`),
      `Net Impact ($B)` = as_dollars_b(rural_preferred_row$`Net Impact After Rural Support ($B)`),
      `Net Impact (% NPR)` = as_pct(rural_preferred_row$`Net Impact After Rural Support (% of NPR)`),
      `Providers Below -5% NPR` = as_count(rural_preferred_row$`Rural Providers Below -5% NPR`),
      `Providers Below -10% NPR` = as_count(rural_preferred_row$`Rural Providers Below -10% NPR`),
      `Preferred?` = "Yes - preferred rural option"
    ),
    data.table::data.table(
      `Option Set` = "Rural access options",
      `Scenario` = rural_high_row$Scenario,
      `Added Support ($B)` = as_dollars_b(rural_high_row$`Added Rural Support ($B)`),
      `Net Impact ($B)` = as_dollars_b(rural_high_row$`Net Impact After Rural Support ($B)`),
      `Net Impact (% NPR)` = as_pct(rural_high_row$`Net Impact After Rural Support (% of NPR)`),
      `Providers Below -5% NPR` = as_count(rural_high_row$`Rural Providers Below -5% NPR`),
      `Providers Below -10% NPR` = as_count(rural_high_row$`Rural Providers Below -10% NPR`),
      `Preferred?` = "No - high-protection sensitivity"
    )
  ),
  fill = TRUE
)

behavioral_options <- data.table::rbindlist(
  list(
    data.table::data.table(
      `Option Set` = "Behavioral institutional options",
      `Scenario` = behavioral_current_row$Scenario,
      `Added Support ($B)` = as_dollars_b(behavioral_current_row$`Added Behavioral Support ($B)`),
      `Net Impact ($B)` = as_dollars_b(behavioral_current_row$`Net Behavioral Impact After Scenario ($B)`),
      `Net Impact (% NPR)` = as_pct(behavioral_current_row$`Net Impact After Scenario (% of NPR)`),
      `Providers Below -5% NPR` = as_count(behavioral_current_row$`Providers Below -5% NPR`),
      `Providers Below -10% NPR` = as_count(behavioral_current_row$`Providers Below -10% NPR`),
      `Preferred?` = "No - baseline"
    ),
    data.table::data.table(
      `Option Set` = "Behavioral institutional options",
      `Scenario` = behavioral_reduced_row$Scenario,
      `Added Support ($B)` = as_dollars_b(behavioral_reduced_row$`Added Behavioral Support ($B)`),
      `Net Impact ($B)` = as_dollars_b(behavioral_reduced_row$`Net Behavioral Impact After Scenario ($B)`),
      `Net Impact (% NPR)` = as_pct(behavioral_reduced_row$`Net Impact After Scenario (% of NPR)`),
      `Providers Below -5% NPR` = as_count(behavioral_reduced_row$`Providers Below -5% NPR`),
      `Providers Below -10% NPR` = as_count(behavioral_reduced_row$`Providers Below -10% NPR`),
      `Preferred?` = "No - moderate exposure adjustment"
    ),
    data.table::data.table(
      `Option Set` = "Behavioral institutional options",
      `Scenario` = behavioral_minimal_row$Scenario,
      `Added Support ($B)` = as_dollars_b(behavioral_minimal_row$`Added Behavioral Support ($B)`),
      `Net Impact ($B)` = as_dollars_b(behavioral_minimal_row$`Net Behavioral Impact After Scenario ($B)`),
      `Net Impact (% NPR)` = as_pct(behavioral_minimal_row$`Net Impact After Scenario (% of NPR)`),
      `Providers Below -5% NPR` = as_count(behavioral_minimal_row$`Providers Below -5% NPR`),
      `Providers Below -10% NPR` = as_count(behavioral_minimal_row$`Providers Below -10% NPR`),
      `Preferred?` = "Partial - exposure adjustment only"
    ),
    data.table::data.table(
      `Option Set` = "Behavioral institutional options",
      `Scenario` = behavioral_floor_row$Scenario,
      `Added Support ($B)` = as_dollars_b(behavioral_floor_row$`Added Behavioral Support ($B)`),
      `Net Impact ($B)` = as_dollars_b(behavioral_floor_row$`Net Behavioral Impact After Scenario ($B)`),
      `Net Impact (% NPR)` = as_pct(behavioral_floor_row$`Net Impact After Scenario (% of NPR)`),
      `Providers Below -5% NPR` = as_count(behavioral_floor_row$`Providers Below -5% NPR`),
      `Providers Below -10% NPR` = as_count(behavioral_floor_row$`Providers Below -10% NPR`),
      `Preferred?` = "No - floor without exposure correction"
    ),
    data.table::data.table(
      `Option Set` = "Behavioral institutional options",
      `Scenario` = behavioral_preferred_row$Scenario,
      `Added Support ($B)` = as_dollars_b(behavioral_preferred_row$`Added Behavioral Support ($B)`),
      `Net Impact ($B)` = as_dollars_b(behavioral_preferred_row$`Net Behavioral Impact After Scenario ($B)`),
      `Net Impact (% NPR)` = as_pct(behavioral_preferred_row$`Net Impact After Scenario (% of NPR)`),
      `Providers Below -5% NPR` = as_count(behavioral_preferred_row$`Providers Below -5% NPR`),
      `Providers Below -10% NPR` = as_count(behavioral_preferred_row$`Providers Below -10% NPR`),
      `Preferred?` = "Yes - preferred behavioral option"
    )
  ),
  fill = TRUE
)

table_7G_options_appendix <- data.table::rbindlist(
  list(
    rural_options,
    behavioral_options
  ),
  fill = TRUE
)

# ============================================================
# 10. Methodology / prose notes
# ============================================================

summary_notes <- c(
  "Table 7G Access-Protection Policy Summary Notes",
  "================================================",
  "",
  paste0("Build year: ", hcris_year_label),
  paste0("Generated: ", Sys.time()),
  "",
  "Purpose:",
  "This script creates a publication-facing summary of targeted access-protection options for UCC/HSE Table 7.",
  "It does not rebuild the provider-impact model.",
  "",
  "Core provider-impact model:",
  "Net Provider Impact = - Market Repricing Pressure + UC/Liquidity Offset + Bounded Stabilization Support.",
  "",
  "Preferred rural policy:",
  "Enhanced rural access guarantee plus implementation-period rural floor.",
  "Permanent component: 2% of NPR, capped at $5 million per rural provider.",
  "Implementation-period component: no qualifying rural / CAH / IHS provider below -1.5% of NPR.",
  paste0(
    "Model result: added rural support of $",
    rural_preferred_row$`Added Rural Support ($B)`,
    "B; rural net impact after support of $",
    rural_preferred_row$`Net Impact After Rural Support ($B)`,
    "B; rural impact of ",
    rural_preferred_row$`Net Impact After Rural Support (% of NPR)`,
    "% of NPR; rural providers below -5% NPR: ",
    rural_preferred_row$`Rural Providers Below -5% NPR`,
    "."
  ),
  "",
  "Preferred behavioral policy:",
  "Behavioral institutional repricing adjustment plus implementation-period floor.",
  "Structural modeling adjustment: qualifying psychiatric / behavioral institutions receive 25% of standard modeled repricing pressure.",
  "Implementation-period component: no qualifying psychiatric / behavioral provider below -5% of NPR.",
  paste0(
    "Model result: behavioral net impact after scenario of $",
    behavioral_preferred_row$`Net Behavioral Impact After Scenario ($B)`,
    "B; behavioral impact of ",
    behavioral_preferred_row$`Net Impact After Scenario (% of NPR)`,
    "% of NPR; providers below -10% NPR: ",
    behavioral_preferred_row$`Providers Below -10% NPR`,
    "."
  ),
  "",
  "Interpretive distinction:",
  "Rural protection is a permanent access-capacity payment because rural access vulnerability is structural.",
  "Behavioral protection is primarily a repricing-exposure adjustment because many institutional psychiatric providers are not ordinary consumer-directed routine outpatient price-shopping targets.",
  "",
  "Recommended table placement:",
  "Use Table 7G as the main access-protection policy summary.",
  "Move the full rural and behavioral sensitivity tables to appendix tables unless space allows."
)

formula_notes <- c(
  "Access-Protection Formula Notes",
  "===============================",
  "",
  "Core provider-impact equation:",
  "Net Provider Impact_i,s = - Market Repricing Pressure_i,s + UC/Liquidity Offset_i,s + Bounded Stabilization Support_i,s",
  "",
  "Preferred rural access protection:",
  "Preferred Rural Protection_i = Permanent Rural Access Guarantee_i + Rural Implementation Floor Support_i",
  "",
  "Permanent Rural Access Guarantee_i = min(0.02 x NPR_i, $5,000,000)",
  "",
  "Net Impact After Rural Guarantee_i = Net Provider Impact_i + Permanent Rural Access Guarantee_i",
  "",
  "Rural Implementation Floor Support_i = max(0, (-0.015 x NPR_i) - Net Impact After Rural Guarantee_i)",
  "",
  "Preferred Rural Adjusted Net Impact_i = Net Impact After Rural Guarantee_i + Rural Implementation Floor Support_i",
  "",
  "Preferred behavioral institutional treatment:",
  "Behavioral Adjusted Repricing Pressure_i = 0.25 x Market Repricing Pressure_i",
  "",
  "Behavioral Pre-Floor Net Impact_i = - Behavioral Adjusted Repricing Pressure_i + UC/Liquidity Offset_i + Bounded Stabilization Support_i",
  "",
  "Behavioral Floor Support_i = max(0, (-0.05 x NPR_i) - Behavioral Pre-Floor Net Impact_i)",
  "",
  "Preferred Behavioral Adjusted Net Impact_i = Behavioral Pre-Floor Net Impact_i + Behavioral Floor Support_i",
  "",
  "Policy distinction:",
  "Rural access guarantee is permanent, capped, and formula-based.",
  "Rural floor and behavioral floor are implementation-period or reviewable protections.",
  "Behavioral repricing adjustment is a structural exposure adjustment, not a general provider bailout."
)

# ============================================================
# 11. Save outputs
# ============================================================

table_7G_access_file <- file.path(
  table7_dir,
  "table_7G_access_protection_policy_options.csv"
)

table_7G_options_file <- file.path(
  table7_dir,
  "table_7G_access_protection_options_appendix.csv"
)

summary_notes_file <- file.path(
  table7_dir,
  "table_7_access_protection_summary_notes.txt"
)

formula_notes_file <- file.path(
  table7_dir,
  "table_7_access_protection_formula_notes.txt"
)

data.table::fwrite(table_7G_access, table_7G_access_file)
data.table::fwrite(table_7G_options_appendix, table_7G_options_file)
writeLines(summary_notes, summary_notes_file)
writeLines(formula_notes, formula_notes_file)

# Optional Excel workbook.
excel_file <- file.path(
  table7_dir,
  "table_7G_access_protection_policy_options.xlsx"
)

excel_written <- FALSE

if (requireNamespace("openxlsx", quietly = TRUE)) {
  wb <- openxlsx::createWorkbook()
  
  add_sheet <- function(wb, sheet_name, dt_sheet) {
    openxlsx::addWorksheet(wb, sheet_name)
    openxlsx::writeData(wb, sheet_name, dt_sheet)
    openxlsx::freezePane(wb, sheet_name, firstRow = TRUE)
    openxlsx::setColWidths(wb, sheet_name, cols = 1:ncol(dt_sheet), widths = "auto")
  }
  
  add_sheet(wb, "Table 7G Summary", table_7G_access)
  add_sheet(wb, "Options Appendix", table_7G_options_appendix)
  
  openxlsx::addWorksheet(wb, "Summary Notes")
  openxlsx::writeData(
    wb,
    "Summary Notes",
    data.table::data.table(notes = summary_notes)
  )
  openxlsx::setColWidths(wb, "Summary Notes", cols = 1, widths = 120)
  
  openxlsx::addWorksheet(wb, "Formula Notes")
  openxlsx::writeData(
    wb,
    "Formula Notes",
    data.table::data.table(notes = formula_notes)
  )
  openxlsx::setColWidths(wb, "Formula Notes", cols = 1, widths = 120)
  
  openxlsx::saveWorkbook(wb, excel_file, overwrite = TRUE)
  excel_written <- TRUE
} else {
  warning(
    "Package openxlsx not installed. Excel workbook was not written. ",
    "CSV/TXT outputs were written."
  )
}

# ============================================================
# 12. Print summaries
# ============================================================

cat("\n============================================================\n")
cat("TABLE 7 ACCESS-PROTECTION SUMMARY COMPLETE\n")
cat("============================================================\n")

cat("\nTable 7G. Access-Protection Policy Options:\n")
print(table_7G_access)

cat("\nAccess-protection options appendix:\n")
print(table_7G_options_appendix)

cat("\nSaved:\n")
cat(table_7G_access_file, "\n")
cat(table_7G_options_file, "\n")
cat(summary_notes_file, "\n")
cat(formula_notes_file, "\n")

if (excel_written == TRUE) {
  cat(excel_file, "\n")
}

cat("\n============================================================\n")
```

---

# 15_make_table7_publication_grade_tables.R

```r
# Scripts/15_make_table7_publication_grade_tables.R
# Create publication-grade Table 7 outputs for the UCC/HSE white paper.
#
# Purpose:
#   This script does NOT rebuild the provider-impact model.
#   It reads already-generated Table 7 CSV outputs and produces:
#
#     1. publication-grade main-paper tables,
#     2. publication-grade appendix tables,
#     3. a formatted Excel workbook containing all tables,
#     4. table notes,
#     5. methodology notes,
#     6. a final manifest.
#
# Required prior scripts:
#   08_extract_g2_g3_revenue_expense.R
#   09_validate_provider_classification.R
#   10_create_stabilization_eligibility.R
#   11_create_provider_impact_scenarios.R
#   11A_audit_provider_impact_coverage_and_exposure.R
#   12_format_table7_publication_outputs.R
#   13_provider_transition_protection_sensitivity.R
#   13B_enhanced_rural_access_sensitivity.R
#   13C_behavioral_psychiatric_sensitivity.R
#   14_create_table7_access_protection_summary.R
#
# Main paper tables:
#   Table 7A. Provider Impact 3x3 Scenario Matrix
#   Table 7B. Provider Impact by Provider Group
#   Table 7C. Provider Impact by Provider Class
#   Table 7D. Provider-Level Distribution
#   Table 7E. Model Coverage and Data Quality Audit
#   Table 7F. Exposure-Anomaly Sensitivity
#   Table 7G. Access-Protection Policy Options
#
# Appendix tables:
#   Appendix Table 7G. Access-Protection Options Menu
#   Appendix Table 7J. Provider-Level Transition and Rural Access Sensitivity
#   Appendix Table 7K. Enhanced Rural Access Sensitivity
#   Appendix Table 7L. Rural Provider-Level Enhanced Access
#   Appendix Table 7M. Psychiatric / Behavioral Provider Sensitivity
#   Appendix Table 7N. Psychiatric / Behavioral Provider-Level Review
#   Appendix Table 7O. Behavioral Remaining Severe Effects
#   Appendix Table 7P. Behavioral Review Universe
#
# Output folder:
#   Output/Table7_Publication/Final_Publication_Grade/

source("Scripts/00_setup.R")

cat("\n============================================================\n")
cat("MAKE TABLE 7 PUBLICATION-GRADE MAIN AND APPENDIX TABLES\n")
cat("============================================================\n")
cat("Build year:", hcris_year_label, "\n\n")

# ============================================================
# 0. Folders
# ============================================================

table7_dir <- file.path(path_output, "Table7_Publication")
pub_dir <- file.path(table7_dir, "Final_Publication_Grade")

if (!dir.exists(table7_dir)) {
  stop("Missing Table7_Publication folder. Run Scripts 12-14 first.")
}

if (!dir.exists(pub_dir)) {
  dir.create(pub_dir, recursive = TRUE)
}

cat("Input folder:\n")
cat(table7_dir, "\n\n")

cat("Final publication output folder:\n")
cat(pub_dir, "\n\n")

# ============================================================
# 1. Input files
# ============================================================

files <- list(
  # Main-paper source tables
  table_7A = file.path(table7_dir, "table_7A_publication.csv"),
  table_7B = file.path(table7_dir, "table_7B_publication.csv"),
  table_7C = file.path(table7_dir, "table_7C_publication.csv"),
  table_7D = file.path(table7_dir, "table_7D_publication.csv"),
  table_7E = file.path(table7_dir, "table_7E_model_coverage_audit.csv"),
  table_7F = file.path(table7_dir, "table_7F_exposure_anomaly_sensitivity.csv"),
  table_7G = file.path(table7_dir, "table_7G_access_protection_policy_options.csv"),
  
  # Appendix / options source tables
  table_7G_options = file.path(table7_dir, "table_7G_access_protection_options_appendix.csv"),
  
  # General transition / rural access package from Script 13
  table_7J = file.path(table7_dir, "table_7J_provider_level_transition_and_rural_access.csv"),
  
  # Enhanced rural access package from Script 13B
  table_7K = file.path(table7_dir, "table_7K_enhanced_rural_access_sensitivity.csv"),
  table_7L = file.path(table7_dir, "table_7L_rural_provider_level_enhanced_access.csv"),
  
  # Behavioral package from Script 13C
  table_7M = file.path(table7_dir, "table_7M_behavioral_psychiatric_sensitivity.csv"),
  table_7N = file.path(table7_dir, "table_7N_behavioral_psychiatric_provider_level.csv"),
  table_7O = file.path(table7_dir, "table_7O_behavioral_remaining_severe_effects.csv"),
  table_7P = file.path(table7_dir, "table_7P_behavioral_review_universe.csv")
)

missing_files <- unlist(files)[!file.exists(unlist(files))]

if (length(missing_files) > 0) {
  stop(
    "Missing required Table 7 files. Rerun Scripts 12, 13, 13B, 13C, and 14 first:\n",
    paste(missing_files, collapse = "\n")
  )
}

# ============================================================
# 2. Read inputs
# ============================================================

t7A <- data.table::fread(files$table_7A)
t7B <- data.table::fread(files$table_7B)
t7C <- data.table::fread(files$table_7C)
t7D <- data.table::fread(files$table_7D)
t7E <- data.table::fread(files$table_7E)
t7F <- data.table::fread(files$table_7F)
t7G <- data.table::fread(files$table_7G)

t7G_options <- data.table::fread(files$table_7G_options)

t7J <- data.table::fread(files$table_7J)

t7K <- data.table::fread(files$table_7K)
t7L <- data.table::fread(files$table_7L)

t7M <- data.table::fread(files$table_7M)
t7N <- data.table::fread(files$table_7N)
t7O <- data.table::fread(files$table_7O)
t7P <- data.table::fread(files$table_7P)

cat("Loaded all Table 7 inputs.\n\n")

# ============================================================
# 3. Formatting helpers
# ============================================================

fmt_money_b <- function(x, digits = 2) {
  x <- suppressWarnings(as.numeric(x))
  ifelse(
    is.na(x),
    "",
    paste0(
      ifelse(x < 0, "-", ""),
      "$",
      formatC(abs(x), format = "f", digits = digits, big.mark = ",")
    )
  )
}

fmt_money_raw <- function(x, digits = 0) {
  x <- suppressWarnings(as.numeric(x))
  ifelse(
    is.na(x),
    "",
    paste0(
      ifelse(x < 0, "-", ""),
      "$",
      formatC(abs(x), format = "f", digits = digits, big.mark = ",")
    )
  )
}

fmt_num <- function(x, digits = 1) {
  x <- suppressWarnings(as.numeric(x))
  ifelse(
    is.na(x),
    "",
    formatC(x, format = "f", digits = digits, big.mark = ",")
  )
}

fmt_pct <- function(x, digits = 1) {
  x <- suppressWarnings(as.numeric(x))
  ifelse(
    is.na(x),
    "",
    paste0(formatC(x, format = "f", digits = digits, big.mark = ","), "%")
  )
}

fmt_pct_decimal <- function(x, digits = 1) {
  x <- suppressWarnings(as.numeric(x))
  ifelse(
    is.na(x),
    "",
    paste0(formatC(100 * x, format = "f", digits = digits, big.mark = ","), "%")
  )
}

fmt_int <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  ifelse(
    is.na(x),
    "",
    formatC(round(x, 0), format = "f", digits = 0, big.mark = ",")
  )
}

clean_names_for_excel <- function(dt) {
  out <- copy(dt)
  names(out) <- gsub("_", " ", names(out))
  names(out) <- tools::toTitleCase(names(out))
  out
}

format_by_name <- function(dt, provider_level = FALSE) {
  out <- copy(dt)
  
  for (cc in names(out)) {
    cc_lower <- tolower(cc)
    
    if (grepl("\\(\\$b\\)|\\$b|\\(\\$ b\\)", cc_lower)) {
      out[, (cc) := fmt_money_b(get(cc), digits = 2)]
    } else if (grepl("npr|net_patient_revenue|outpatient_exposure|repricing_pressure|uncompensated|stabilization|support|impact", cc_lower) &&
               provider_level == TRUE &&
               !grepl("pct|percent|ratio|flag|tier|basis|method|scenario|group|class|name|city|state|provider|rpt|prvdr", cc_lower)) {
      out[, (cc) := fmt_money_raw(get(cc), digits = 0)]
    } else if (grepl("pct_of_npr|pct_npr|impact_pct|ratio", cc_lower) &&
               provider_level == TRUE) {
      out[, (cc) := fmt_pct_decimal(get(cc), digits = 1)]
    } else if (grepl("\\(% of npr\\)|% npr|\\(%\\)|percent|share", cc_lower)) {
      out[, (cc) := fmt_pct(get(cc), digits = 1)]
    } else if (grepl("providers|count|number", cc_lower) &&
               !grepl("group|class|status|design|provider name|provider_group|provider_class", cc_lower)) {
      out[, (cc) := fmt_int(get(cc))]
    }
  }
  
  out
}

select_existing <- function(dt, cols) {
  dt[, intersect(cols, names(dt)), with = FALSE]
}

# ============================================================
# 4. Main paper tables
# ============================================================

# ----------------------------
# Table 7A
# ----------------------------

t7A_order <- c(
  "Repricing Scenario",
  "Stabilization Scenario",
  "Modeled Providers",
  "Outpatient/Routine Exposure ($B)",
  "Repricing Pressure ($B)",
  "UC / Liquidity Offset ($B)",
  "Stabilization Support ($B)",
  "Net Provider Impact ($B)",
  "Net Impact (% of NPR)",
  "Negative-Impact Providers",
  "Large Negative-Impact Providers",
  "Median Provider Impact (% of NPR)"
)

t7A_pub <- select_existing(t7A, t7A_order)

# ----------------------------
# Table 7B
# ----------------------------

t7B_order <- c(
  "Provider Group",
  "Providers",
  "Modeled Providers",
  "Net Patient Revenue ($B)",
  "Outpatient/Routine Exposure ($B)",
  "Repricing Pressure ($B)",
  "UC / Liquidity Offset ($B)",
  "Stabilization Support ($B)",
  "Net Provider Impact ($B)",
  "Net Impact (% of NPR)",
  "Negative-Impact Providers",
  "Large Negative-Impact Providers",
  "Stabilization-Eligible Providers"
)

t7B_pub <- select_existing(t7B, t7B_order)

# ----------------------------
# Table 7C
# ----------------------------

t7C_order <- c(
  "Provider Group",
  "Provider Class",
  "Providers",
  "Modeled Providers",
  "Net Patient Revenue ($B)",
  "Outpatient/Routine Exposure ($B)",
  "Repricing Pressure ($B)",
  "UC / Liquidity Offset ($B)",
  "Stabilization Support ($B)",
  "Net Provider Impact ($B)",
  "Net Impact (% of NPR)",
  "Negative-Impact Providers",
  "Large Negative-Impact Providers",
  "Stabilization-Eligible Providers"
)

t7C_pub <- select_existing(t7C, t7C_order)

# ----------------------------
# Table 7D
# ----------------------------

t7D_order <- c(
  "Provider Group",
  "Provider Impact Bucket (% of NPR)",
  "Providers",
  "Net Patient Revenue ($B)",
  "Net Provider Impact ($B)",
  "Median Provider Impact (% of NPR)"
)

t7D_pub <- select_existing(t7D, t7D_order)

# ----------------------------
# Table 7E
# ----------------------------

t7E_pub <- copy(t7E)

# ----------------------------
# Table 7F
# ----------------------------

t7F_order <- c(
  "Sensitivity Case",
  "Modeled Providers",
  "Net Patient Revenue ($B)",
  "Outpatient/Routine Exposure ($B)",
  "Repricing Pressure ($B)",
  "UC / Liquidity Offset ($B)",
  "Stabilization Support ($B)",
  "Net Provider Impact ($B)",
  "Net Impact (% of NPR)",
  "Median Provider Impact (% of NPR)"
)

t7F_pub <- select_existing(t7F, t7F_order)

# ----------------------------
# Table 7G
# ----------------------------

t7G_order <- c(
  "Policy Layer",
  "Provider Group",
  "Protection Design",
  "Permanent Component",
  "Temporary / Implementation Component",
  "Added Support ($B)",
  "Net Impact After Protection ($B)",
  "Net Impact After Protection (% NPR)",
  "Providers Below -5% NPR",
  "Providers Below -10% NPR",
  "Temporary or Permanent?",
  "Preferred Policy Status",
  "Interpretation"
)

t7G_pub <- select_existing(t7G, t7G_order)

# ============================================================
# 5. Appendix table slimming / ordering
# ============================================================

# ----------------------------
# Appendix Table 7G Options
# ----------------------------

app7G_options_pub <- copy(t7G_options)

# ----------------------------
# Appendix Table 7J
# Provider-level transition and rural access output can be huge.
# Keep only publication-relevant columns.
# ----------------------------

app7J_order <- c(
  "rpt_rec_num",
  "prvdr_num_chr",
  "provider_name",
  "city",
  "state_abbrev",
  "clean_provider_group",
  "clean_provider_model_class",
  "revenue_source_method",
  "net_patient_revenue_model",
  "outpatient_exposure_used",
  "outpatient_repricing_pressure",
  "uncompensated_care_offset",
  "stabilization_support",
  "net_provider_impact",
  "net_provider_impact_pct_of_npr",
  "stabilization_tier",
  "stabilization_basis",
  "large_negative_impact_flag",
  "severe_negative_impact_flag",
  "permanent_rural_access_eligible_flag",
  "pediatric_transition_eligible_flag",
  "case_F_temporary_support",
  "case_F_permanent_rural_access_support",
  "case_F_total_added_support",
  "case_F_net_impact",
  "case_F_net_impact_pct_npr"
)

app7J_pub <- select_existing(t7J, app7J_order)
app7J_pub <- clean_names_for_excel(app7J_pub)

# ----------------------------
# Appendix Table 7K
# Enhanced Rural Access Sensitivity
# ----------------------------

app7K_pub <- copy(t7K)

# ----------------------------
# Appendix Table 7L
# Rural Provider-Level Enhanced Access
# ----------------------------

app7L_order <- c(
  "rpt_rec_num",
  "prvdr_num_chr",
  "provider_name",
  "city",
  "state_abbrev",
  "clean_provider_model_class",
  "revenue_source_method",
  "stabilization_tier",
  "stabilization_basis",
  "net_patient_revenue_model",
  "outpatient_exposure_used",
  "outpatient_repricing_pressure",
  "uncompensated_care_offset",
  "stabilization_support",
  "base_net_impact",
  "base_net_impact_pct_npr",
  "current_access_support",
  "current_access_net_impact_pct_npr",
  "enhanced_access_support",
  "enhanced_access_net_impact_pct_npr",
  "enhanced_plus_floor_1_5pct_support",
  "enhanced_plus_floor_1_5pct_net_impact_pct_npr",
  "high_plus_floor_1pct_support",
  "high_plus_floor_1pct_net_impact_pct_npr"
)

app7L_pub <- select_existing(t7L, app7L_order)
app7L_pub <- clean_names_for_excel(app7L_pub)

# ----------------------------
# Appendix Table 7M
# Behavioral / Psychiatric Sensitivity
# ----------------------------

app7M_pub <- copy(t7M)

# ----------------------------
# Appendix Table 7N
# Behavioral Provider-Level Review
# ----------------------------

app7N_order <- c(
  "rpt_rec_num",
  "prvdr_num_chr",
  "provider_name",
  "city",
  "state_abbrev",
  "clean_provider_group",
  "clean_provider_model_class",
  "revenue_source_method",
  "stabilization_tier",
  "stabilization_basis",
  "net_patient_revenue_model",
  "outpatient_exposure_used",
  "outpatient_repricing_pressure",
  "uncompensated_care_offset",
  "stabilization_support",
  "base_net_impact",
  "base_net_impact_pct_npr",
  "scenario_B_50pct_repricing_net_impact",
  "scenario_B_50pct_repricing_net_impact_pct_npr",
  "scenario_C_25pct_repricing_net_impact",
  "scenario_C_25pct_repricing_net_impact_pct_npr",
  "scenario_D_floor_7_5pct_added_support",
  "scenario_D_floor_7_5pct_net_impact_pct_npr",
  "scenario_F_25pct_repricing_floor_5pct_added_support",
  "scenario_F_25pct_repricing_floor_5pct_net_impact_pct_npr"
)

app7N_pub <- select_existing(t7N, app7N_order)
app7N_pub <- clean_names_for_excel(app7N_pub)

# ----------------------------
# Appendix Table 7O
# Behavioral Remaining Severe Effects
# ----------------------------

app7O_pub <- copy(t7O)

# ----------------------------
# Appendix Table 7P
# Behavioral Review Universe
# ----------------------------

app7P_order <- c(
  "rpt_rec_num",
  "prvdr_num_chr",
  "provider_name",
  "city",
  "state_abbrev",
  "raw_provider_model_class",
  "clean_provider_group",
  "clean_provider_model_class",
  "behavioral_primary_flag",
  "behavioral_name_review_flag",
  "revenue_source_method",
  "net_patient_revenue_model",
  "outpatient_exposure_used",
  "outpatient_repricing_pressure",
  "uncompensated_care_offset",
  "stabilization_support",
  "net_provider_impact",
  "net_provider_impact_pct_of_npr",
  "stabilization_tier",
  "stabilization_basis"
)

app7P_pub <- select_existing(t7P, app7P_order)
app7P_pub <- clean_names_for_excel(app7P_pub)

# ============================================================
# 6. Human-readable formatted versions
# ============================================================

t7A_final <- format_by_name(t7A_pub)
t7B_final <- format_by_name(t7B_pub)
t7C_final <- format_by_name(t7C_pub)
t7D_final <- format_by_name(t7D_pub)
t7E_final <- copy(t7E_pub)
t7F_final <- format_by_name(t7F_pub)
t7G_final <- format_by_name(t7G_pub)

app7G_options_final <- format_by_name(app7G_options_pub)
app7J_final <- format_by_name(app7J_pub, provider_level = TRUE)
app7K_final <- format_by_name(app7K_pub)
app7L_final <- format_by_name(app7L_pub, provider_level = TRUE)
app7M_final <- format_by_name(app7M_pub)
app7N_final <- format_by_name(app7N_pub, provider_level = TRUE)
app7O_final <- format_by_name(app7O_pub)
app7P_final <- format_by_name(app7P_pub, provider_level = TRUE)

# ============================================================
# 7. Table notes
# ============================================================

table_notes <- data.table::data.table(
  Table = c(
    "Table 7A",
    "Table 7B",
    "Table 7C",
    "Table 7D",
    "Table 7E",
    "Table 7F",
    "Table 7G",
    "Appendix Table 7G",
    "Appendix Table 7J",
    "Appendix Table 7K",
    "Appendix Table 7L",
    "Appendix Table 7M",
    "Appendix Table 7N",
    "Appendix Table 7O",
    "Appendix Table 7P"
  ),
  Title = c(
    "Provider Impact 3x3 Scenario Matrix",
    "Provider Impact by Provider Group under Base/Base Scenario",
    "Provider Impact by Provider Class under Base/Base Scenario",
    "Distribution of Provider-Level Effects under Base/Base Scenario",
    "Provider-Impact Model Coverage and Data Quality Audit",
    "Exposure-Anomaly Sensitivity under Base/Base Scenario",
    "Access-Protection Policy Options",
    "Access-Protection Options Menu",
    "Provider-Level Transition and Rural Access Sensitivity",
    "Enhanced Rural Access Sensitivity",
    "Rural Provider-Level Enhanced Access",
    "Psychiatric / Behavioral Provider Sensitivity",
    "Psychiatric / Behavioral Provider-Level Review",
    "Remaining Severe Psychiatric / Behavioral Effects",
    "Behavioral Review Universe"
  ),
  Placement = c(
    rep("Main paper", 7),
    rep("Appendix", 8)
  ),
  Note = c(
    "Shows modeled provider impact across low/base/high repricing and stabilization scenarios.",
    "Aggregates Base/Base provider impact by cleaned provider group.",
    "Disaggregates Base/Base provider impact by cleaned provider class.",
    "Shows the distribution of provider-level net impacts as a percentage of net patient revenue.",
    "Reports model coverage, source-method counts, fallback use, and data-quality checks.",
    "Tests whether exposure-anomaly records materially change Base/Base results.",
    "Summarizes preferred targeted access protections for rural and behavioral providers.",
    "Shows menu of rural and behavioral access-protection options.",
    "Provider-level output from the combined transition and rural access sensitivity.",
    "Shows rural access-support options, including the preferred enhanced rural guarantee plus implementation floor.",
    "Provider-level rural access sensitivity output.",
    "Shows behavioral institutional repricing options and floor options.",
    "Provider-level psychiatric / behavioral sensitivity output.",
    "Shows remaining severe behavioral impacts under each behavioral treatment scenario.",
    "Expanded behavioral review universe including name-flagged records outside the primary behavioral class."
  )
)

methodology_note <- c(
  "Table 7 publication-grade methodology note",
  "========================================",
  "",
  paste0("Build year: ", hcris_year_label),
  paste0("Generated: ", Sys.time()),
  "",
  "The Table 7 package is based on the corrected FY2024 HCRIS provider-impact model.",
  "",
  "Core formula:",
  "Net Provider Impact = - Market Repricing Pressure + UC / Liquidity Offset + Bounded Stabilization Support.",
  "",
  "Preferred access-protection package:",
  "Rural: permanent rural access guarantee equal to 2% of NPR, capped at $5M per rural provider, plus an implementation-period rural floor at -1.5% NPR.",
  "Behavioral: institutional behavioral providers are assigned 25% of standard modeled repricing pressure, plus an implementation-period floor at -5% NPR.",
  "",
  "Interpretation:",
  "The preferred package is targeted. It preserves the main provider-side price-discipline mechanism while protecting rural access and correcting behavioral institutional exposure outliers.",
  "",
  "Suggested main-paper table sequence:",
  "Table 7A, Table 7B, Table 7C, Table 7D, Table 7E, Table 7F, Table 7G.",
  "",
  "Suggested appendix sequence:",
  "Appendix Table 7G, Appendix Table 7J, Appendix Table 7K, Appendix Table 7L, Appendix Table 7M, Appendix Table 7N, Appendix Table 7O, Appendix Table 7P."
)

# ============================================================
# 8. Save CSV outputs
# ============================================================

out_files <- list(
  table_7A = file.path(pub_dir, "Table_7A_Provider_Impact_3x3_Scenario_Matrix.csv"),
  table_7B = file.path(pub_dir, "Table_7B_Provider_Impact_by_Group.csv"),
  table_7C = file.path(pub_dir, "Table_7C_Provider_Impact_by_Class.csv"),
  table_7D = file.path(pub_dir, "Table_7D_Provider_Level_Distribution.csv"),
  table_7E = file.path(pub_dir, "Table_7E_Model_Coverage_Data_Quality_Audit.csv"),
  table_7F = file.path(pub_dir, "Table_7F_Exposure_Anomaly_Sensitivity.csv"),
  table_7G = file.path(pub_dir, "Table_7G_Access_Protection_Policy_Options.csv"),
  
  appendix_7G_options = file.path(pub_dir, "Appendix_Table_7G_Access_Protection_Options_Menu.csv"),
  appendix_7J = file.path(pub_dir, "Appendix_Table_7J_Provider_Level_Transition_Rural_Access.csv"),
  appendix_7K = file.path(pub_dir, "Appendix_Table_7K_Enhanced_Rural_Access_Sensitivity.csv"),
  appendix_7L = file.path(pub_dir, "Appendix_Table_7L_Rural_Provider_Level_Enhanced_Access.csv"),
  appendix_7M = file.path(pub_dir, "Appendix_Table_7M_Behavioral_Psychiatric_Sensitivity.csv"),
  appendix_7N = file.path(pub_dir, "Appendix_Table_7N_Behavioral_Psychiatric_Provider_Level.csv"),
  appendix_7O = file.path(pub_dir, "Appendix_Table_7O_Behavioral_Remaining_Severe_Effects.csv"),
  appendix_7P = file.path(pub_dir, "Appendix_Table_7P_Behavioral_Review_Universe.csv"),
  
  notes = file.path(pub_dir, "Table_7_Publication_Notes.csv"),
  methodology = file.path(pub_dir, "Table_7_Methodology_Note.txt")
)

data.table::fwrite(t7A_final, out_files$table_7A)
data.table::fwrite(t7B_final, out_files$table_7B)
data.table::fwrite(t7C_final, out_files$table_7C)
data.table::fwrite(t7D_final, out_files$table_7D)
data.table::fwrite(t7E_final, out_files$table_7E)
data.table::fwrite(t7F_final, out_files$table_7F)
data.table::fwrite(t7G_final, out_files$table_7G)

data.table::fwrite(app7G_options_final, out_files$appendix_7G_options)
data.table::fwrite(app7J_final, out_files$appendix_7J)
data.table::fwrite(app7K_final, out_files$appendix_7K)
data.table::fwrite(app7L_final, out_files$appendix_7L)
data.table::fwrite(app7M_final, out_files$appendix_7M)
data.table::fwrite(app7N_final, out_files$appendix_7N)
data.table::fwrite(app7O_final, out_files$appendix_7O)
data.table::fwrite(app7P_final, out_files$appendix_7P)

data.table::fwrite(table_notes, out_files$notes)
writeLines(methodology_note, out_files$methodology)

# ============================================================
# 9. Excel workbook with all tables
# ============================================================

excel_file <- file.path(pub_dir, "Table_7_All_Main_and_Appendix_Tables.xlsx")

excel_written <- FALSE

if (!requireNamespace("openxlsx", quietly = TRUE)) {
  warning("Package openxlsx is not installed. CSV outputs were written, but Excel workbook was not created.")
} else {
  wb <- openxlsx::createWorkbook()
  
  header_style <- openxlsx::createStyle(
    textDecoration = "bold",
    halign = "center",
    valign = "center",
    fgFill = "#D9EAF7",
    border = "TopBottomLeftRight",
    wrapText = TRUE
  )
  
  body_style <- openxlsx::createStyle(
    valign = "top",
    wrapText = TRUE,
    border = "TopBottomLeftRight"
  )
  
  title_style <- openxlsx::createStyle(
    textDecoration = "bold",
    fontSize = 14
  )
  
  add_pub_sheet <- function(wb, sheet_name, title, dt) {
    # Excel worksheet names max length is 31 characters.
    safe_sheet_name <- substr(sheet_name, 1, 31)
    
    openxlsx::addWorksheet(wb, safe_sheet_name)
    
    openxlsx::writeData(wb, safe_sheet_name, title, startRow = 1, startCol = 1)
    openxlsx::addStyle(wb, safe_sheet_name, title_style, rows = 1, cols = 1, gridExpand = TRUE)
    
    openxlsx::writeData(wb, safe_sheet_name, dt, startRow = 3, startCol = 1)
    
    n_cols <- ncol(dt)
    n_rows <- nrow(dt) + 3
    
    if (n_cols > 0) {
      openxlsx::addStyle(
        wb,
        safe_sheet_name,
        header_style,
        rows = 3,
        cols = 1:n_cols,
        gridExpand = TRUE
      )
      
      if (nrow(dt) > 0) {
        openxlsx::addStyle(
          wb,
          safe_sheet_name,
          body_style,
          rows = 4:n_rows,
          cols = 1:n_cols,
          gridExpand = TRUE
        )
      }
      
      openxlsx::freezePane(wb, safe_sheet_name, firstActiveRow = 4)
      openxlsx::setColWidths(wb, safe_sheet_name, cols = 1:n_cols, widths = "auto")
    }
  }
  
  # Main-paper sheets
  add_pub_sheet(wb, "Table 7A", "Table 7A. Provider Impact 3x3 Scenario Matrix", t7A_final)
  add_pub_sheet(wb, "Table 7B", "Table 7B. Provider Impact by Provider Group", t7B_final)
  add_pub_sheet(wb, "Table 7C", "Table 7C. Provider Impact by Provider Class", t7C_final)
  add_pub_sheet(wb, "Table 7D", "Table 7D. Provider-Level Distribution", t7D_final)
  add_pub_sheet(wb, "Table 7E", "Table 7E. Model Coverage and Data Quality Audit", t7E_final)
  add_pub_sheet(wb, "Table 7F", "Table 7F. Exposure-Anomaly Sensitivity", t7F_final)
  add_pub_sheet(wb, "Table 7G", "Table 7G. Access-Protection Policy Options", t7G_final)
  
  # Appendix sheets
  add_pub_sheet(wb, "App 7G Options", "Appendix Table 7G. Access-Protection Options Menu", app7G_options_final)
  add_pub_sheet(wb, "App 7J Transition Rural", "Appendix Table 7J. Provider-Level Transition and Rural Access Sensitivity", app7J_final)
  add_pub_sheet(wb, "App 7K Rural Summary", "Appendix Table 7K. Enhanced Rural Access Sensitivity", app7K_final)
  add_pub_sheet(wb, "App 7L Rural Providers", "Appendix Table 7L. Rural Provider-Level Enhanced Access", app7L_final)
  add_pub_sheet(wb, "App 7M Behavioral Summary", "Appendix Table 7M. Psychiatric / Behavioral Provider Sensitivity", app7M_final)
  add_pub_sheet(wb, "App 7N Behavioral Providers", "Appendix Table 7N. Psychiatric / Behavioral Provider-Level Review", app7N_final)
  add_pub_sheet(wb, "App 7O Behavioral Severe", "Appendix Table 7O. Remaining Severe Psychiatric / Behavioral Effects", app7O_final)
  add_pub_sheet(wb, "App 7P Behavioral Review", "Appendix Table 7P. Behavioral Review Universe", app7P_final)
  
  # Notes sheets
  add_pub_sheet(wb, "Table Notes", "Table 7 Notes", table_notes)
  add_pub_sheet(wb, "Methodology", "Table 7 Methodology Note", data.table::data.table(Note = methodology_note))
  
  openxlsx::saveWorkbook(wb, excel_file, overwrite = TRUE)
  excel_written <- TRUE
}

# ============================================================
# 10. Manifest
# ============================================================

manifest <- data.table::data.table(
  file_type = c(
    rep("main_table_csv", 7),
    rep("appendix_table_csv", 8),
    "notes_csv",
    "methodology_txt",
    "excel_workbook"
  ),
  table_or_file = c(
    "Table 7A",
    "Table 7B",
    "Table 7C",
    "Table 7D",
    "Table 7E",
    "Table 7F",
    "Table 7G",
    "Appendix Table 7G Options",
    "Appendix Table 7J",
    "Appendix Table 7K",
    "Appendix Table 7L",
    "Appendix Table 7M",
    "Appendix Table 7N",
    "Appendix Table 7O",
    "Appendix Table 7P",
    "Table Notes",
    "Methodology Note",
    "All Tables Workbook"
  ),
  path = c(
    out_files$table_7A,
    out_files$table_7B,
    out_files$table_7C,
    out_files$table_7D,
    out_files$table_7E,
    out_files$table_7F,
    out_files$table_7G,
    out_files$appendix_7G_options,
    out_files$appendix_7J,
    out_files$appendix_7K,
    out_files$appendix_7L,
    out_files$appendix_7M,
    out_files$appendix_7N,
    out_files$appendix_7O,
    out_files$appendix_7P,
    out_files$notes,
    out_files$methodology,
    excel_file
  )
)

manifest[, exists := file.exists(path)]

manifest_file <- file.path(pub_dir, "Table_7_Publication_Grade_Manifest.csv")
data.table::fwrite(manifest, manifest_file)

# ============================================================
# 11. Print summary
# ============================================================

cat("\n============================================================\n")
cat("TABLE 7 MAIN AND APPENDIX PUBLICATION EXPORT COMPLETE\n")
cat("============================================================\n\n")

cat("Final output folder:\n")
cat(pub_dir, "\n\n")

cat("Main tables created:\n")
cat("Table 7A\n")
cat("Table 7B\n")
cat("Table 7C\n")
cat("Table 7D\n")
cat("Table 7E\n")
cat("Table 7F\n")
cat("Table 7G\n\n")

cat("Appendix tables created:\n")
cat("Appendix Table 7G Options\n")
cat("Appendix Table 7J\n")
cat("Appendix Table 7K\n")
cat("Appendix Table 7L\n")
cat("Appendix Table 7M\n")
cat("Appendix Table 7N\n")
cat("Appendix Table 7O\n")
cat("Appendix Table 7P\n\n")

if (excel_written == TRUE) {
  cat("Excel workbook:\n")
  cat(excel_file, "\n\n")
}

cat("Manifest:\n")
cat(manifest_file, "\n\n")

cat("Manifest preview:\n")
print(manifest)

cat("\n============================================================\n")
```

---

# 16_make_table7_publication_table_images.R

```r
# Scripts/16_make_table7_publication_table_images.R
# Generate publication-grade PNG images of Table 7 main and appendix tables.
#
# Purpose:
#   Reads the final publication-grade CSV tables generated by Script 15
#   and exports polished table images using gt.
#
# Required prior script:
#   source("Scripts/15_make_table7_publication_grade_tables.R")
#
# Output:
#   Output/Table7_Publication/Final_Publication_Grade/Table_Images/

source("Scripts/00_setup.R")

cat("\n============================================================\n")
cat("MAKE TABLE 7 PUBLICATION-GRADE TABLE IMAGES\n")
cat("============================================================\n")
cat("Build year:", hcris_year_label, "\n\n")

# ============================================================
# 0. Package checks
# ============================================================

required_packages <- c(
  "data.table",
  "gt",
  "webshot2",
  "htmltools"
)

missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_packages) > 0) {
  cat("Installing missing packages:\n")
  print(missing_packages)
  
  install.packages(
    missing_packages,
    repos = "https://cloud.r-project.org",
    dependencies = TRUE
  )
}

suppressPackageStartupMessages({
  library(data.table)
  library(gt)
})

# ============================================================
# 1. Folders
# ============================================================

table7_dir <- file.path(path_output, "Table7_Publication")
pub_dir <- file.path(table7_dir, "Final_Publication_Grade")
image_dir <- file.path(pub_dir, "Table_Images")

if (!dir.exists(pub_dir)) {
  stop("Missing Final_Publication_Grade folder. Run Script 15 first.")
}

if (!dir.exists(image_dir)) {
  dir.create(image_dir, recursive = TRUE)
}

cat("Input folder:\n")
cat(pub_dir, "\n\n")

cat("Image output folder:\n")
cat(image_dir, "\n\n")

# ============================================================
# 2. Table registry
# ============================================================

tables <- data.table::data.table(
  table_id = c(
    "Table 7A",
    "Table 7B",
    "Table 7C",
    "Table 7D",
    "Table 7E",
    "Table 7F",
    "Table 7G",
    "Appendix Table 7G",
    "Appendix Table 7J",
    "Appendix Table 7K",
    "Appendix Table 7L",
    "Appendix Table 7M",
    "Appendix Table 7N",
    "Appendix Table 7O",
    "Appendix Table 7P"
  ),
  title = c(
    "Provider Impact 3×3 Scenario Matrix",
    "Provider Impact by Provider Group",
    "Provider Impact by Provider Class",
    "Provider-Level Distribution",
    "Model Coverage and Data Quality Audit",
    "Exposure-Anomaly Sensitivity",
    "Access-Protection Policy Options",
    "Access-Protection Options Menu",
    "Provider-Level Transition and Rural Access Sensitivity",
    "Enhanced Rural Access Sensitivity",
    "Rural Provider-Level Enhanced Access",
    "Psychiatric / Behavioral Provider Sensitivity",
    "Psychiatric / Behavioral Provider-Level Review",
    "Behavioral Remaining Severe Effects",
    "Behavioral Review Universe"
  ),
  file_name = c(
    "Table_7A_Provider_Impact_3x3_Scenario_Matrix.csv",
    "Table_7B_Provider_Impact_by_Group.csv",
    "Table_7C_Provider_Impact_by_Class.csv",
    "Table_7D_Provider_Level_Distribution.csv",
    "Table_7E_Model_Coverage_Data_Quality_Audit.csv",
    "Table_7F_Exposure_Anomaly_Sensitivity.csv",
    "Table_7G_Access_Protection_Policy_Options.csv",
    "Appendix_Table_7G_Access_Protection_Options_Menu.csv",
    "Appendix_Table_7J_Provider_Level_Transition_Rural_Access.csv",
    "Appendix_Table_7K_Enhanced_Rural_Access_Sensitivity.csv",
    "Appendix_Table_7L_Rural_Provider_Level_Enhanced_Access.csv",
    "Appendix_Table_7M_Behavioral_Psychiatric_Sensitivity.csv",
    "Appendix_Table_7N_Behavioral_Psychiatric_Provider_Level.csv",
    "Appendix_Table_7O_Behavioral_Remaining_Severe_Effects.csv",
    "Appendix_Table_7P_Behavioral_Review_Universe.csv"
  ),
  placement = c(
    rep("Main paper", 7),
    rep("Appendix", 8)
  ),
  max_rows_image = c(
    20, 20, 35, 40, 40, 20, 20,
    30, 60, 25, 60, 25, 60, 25, 60
  )
)

tables[
  ,
  input_path := file.path(pub_dir, file_name)
]

tables[
  ,
  output_png := file.path(
    image_dir,
    paste0(
      gsub(" ", "_", gsub("\\.", "", table_id)),
      "_",
      gsub("[^A-Za-z0-9]+", "_", title),
      ".png"
    )
  )
]

missing_files <- tables[!file.exists(input_path)]

if (nrow(missing_files) > 0) {
  cat("Missing input files:\n")
  print(missing_files[, .(table_id, input_path)])
  stop("Missing one or more publication-grade CSV files. Run Script 15 first.")
}

# ============================================================
# 3. Styling helpers
# ============================================================

shorten_long_text <- function(x, max_chars = 90) {
  x <- as.character(x)
  fifelse(
    nchar(x) > max_chars,
    paste0(substr(x, 1, max_chars - 3), "..."),
    x
  )
}

prepare_for_image <- function(dt, max_rows = 40) {
  out <- copy(dt)
  
  # Limit rows for very large provider-level appendix tables.
  if (nrow(out) > max_rows) {
    out <- out[1:max_rows]
    out[
      ,
      `Image Note` := paste0(
        "Showing first ",
        max_rows,
        " rows; full table available in CSV/XLSX."
      )
    ]
  }
  
  # Shorten very long text-heavy columns so images stay readable.
  for (cc in names(out)) {
    if (is.character(out[[cc]])) {
      out[, (cc) := shorten_long_text(get(cc), max_chars = 95)]
    }
  }
  
  out
}

make_gt_table <- function(dt, table_id, title, placement) {
  gt_tbl <- gt::gt(dt)
  
  gt_tbl <- gt_tbl |>
    gt::tab_header(
      title = gt::md(paste0("**", table_id, ". ", title, "**")),
      subtitle = gt::md(paste0("*", placement, " table generated from FY2024 HCRIS provider-impact model*"))
    ) |>
    gt::tab_source_note(
      source_note = gt::md(
        "Source: UCC/HSE FY2024 HCRIS provider-impact model. Dollar amounts shown in billions unless otherwise labeled."
      )
    ) |>
    gt::tab_options(
      table.font.names = c("Arial", "Helvetica", "sans-serif"),
      table.font.size = gt::px(12),
      heading.title.font.size = gt::px(18),
      heading.subtitle.font.size = gt::px(12),
      column_labels.font.weight = "bold",
      table.border.top.width = gt::px(2),
      table.border.bottom.width = gt::px(2),
      data_row.padding = gt::px(5),
      source_notes.font.size = gt::px(10),
      table.width = gt::pct(100)
    ) |>
    gt::tab_style(
      style = list(
        gt::cell_fill(color = "#F2F6FA"),
        gt::cell_text(weight = "bold")
      ),
      locations = gt::cells_column_labels()
    ) |>
    gt::tab_style(
      style = list(
        gt::cell_fill(color = "#FAFAFA")
      ),
      locations = gt::cells_body(
        rows = seq(2, nrow(dt), by = 2)
      )
    )
  
  # Align numeric-looking columns right, text columns left.
  for (cc in names(dt)) {
    if (all(grepl("^[-$0-9,.% ]*$", as.character(dt[[cc]])) | is.na(dt[[cc]]))) {
      gt_tbl <- gt_tbl |>
        gt::cols_align(
          align = "right",
          columns = cc
        )
    } else {
      gt_tbl <- gt_tbl |>
        gt::cols_align(
          align = "left",
          columns = cc
        )
    }
  }
  
  gt_tbl
}

save_gt_png <- function(gt_tbl, output_png) {
  # gt::gtsave uses webshot2/chromium for PNG export.
  gt::gtsave(
    data = gt_tbl,
    filename = output_png,
    expand = 10,
    vwidth = 1800,
    vheight = 1400
  )
}

# ============================================================
# 4. Generate all images
# ============================================================

image_manifest <- data.table::data.table(
  table_id = character(),
  title = character(),
  placement = character(),
  input_path = character(),
  output_png = character(),
  rows_in_input = integer(),
  rows_in_image = integer(),
  created = logical()
)

for (ii in seq_len(nrow(tables))) {
  row <- tables[ii]
  
  cat("\nRendering ", row$table_id, ": ", row$title, "\n", sep = "")
  
  dt <- data.table::fread(row$input_path)
  
  dt_img <- prepare_for_image(
    dt,
    max_rows = row$max_rows_image
  )
  
  gt_tbl <- make_gt_table(
    dt = dt_img,
    table_id = row$table_id,
    title = row$title,
    placement = row$placement
  )
  
  save_gt_png(
    gt_tbl = gt_tbl,
    output_png = row$output_png
  )
  
  image_manifest <- data.table::rbindlist(
    list(
      image_manifest,
      data.table::data.table(
        table_id = row$table_id,
        title = row$title,
        placement = row$placement,
        input_path = row$input_path,
        output_png = row$output_png,
        rows_in_input = nrow(dt),
        rows_in_image = nrow(dt_img),
        created = file.exists(row$output_png)
      )
    ),
    fill = TRUE
  )
}

# ============================================================
# 5. Save image manifest
# ============================================================

manifest_file <- file.path(
  image_dir,
  "Table_7_Image_Manifest.csv"
)

data.table::fwrite(
  image_manifest,
  manifest_file
)

# ============================================================
# 6. Print summary
# ============================================================

cat("\n============================================================\n")
cat("TABLE 7 PUBLICATION TABLE IMAGES COMPLETE\n")
cat("============================================================\n\n")

cat("Images written to:\n")
cat(image_dir, "\n\n")

cat("Manifest:\n")
cat(manifest_file, "\n\n")

cat("Image manifest preview:\n")
print(image_manifest)

cat("\n============================================================\n")
```

---

# 17_make_table7_compact_publication_figures.R

```r
# Scripts/17_make_table7_compact_publication_figures.R
# Create compact Word-document-friendly publication table images for Table 7.
#
# This version does NOT use gt.
# It draws the tables manually with grid so column spacing is fixed and compact.
#
# Required prior script:
#   source("Scripts/15_make_table7_publication_grade_tables.R")
#
# Output:
#   Output/Table7_Publication/Final_Publication_Grade/Compact_Publication_Figures/

source("Scripts/00_setup.R")

cat("\n============================================================\n")
cat("MAKE COMPACT TABLE 7 PUBLICATION FIGURES - GRID RENDERER\n")
cat("============================================================\n")
cat("Build year:", hcris_year_label, "\n\n")

# ============================================================
# 0. Package checks
# ============================================================

required_packages <- c("data.table")

missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_packages) > 0) {
  install.packages(
    missing_packages,
    repos = "https://cloud.r-project.org",
    dependencies = TRUE
  )
}

suppressPackageStartupMessages({
  library(data.table)
  library(grid)
})

# ============================================================
# 1. Folders
# ============================================================

table7_dir <- file.path(path_output, "Table7_Publication")
pub_dir <- file.path(table7_dir, "Final_Publication_Grade")
fig_dir <- file.path(pub_dir, "Compact_Publication_Figures")

if (!dir.exists(pub_dir)) {
  stop("Missing Final_Publication_Grade folder. Run Script 15 first.")
}

if (!dir.exists(fig_dir)) {
  dir.create(fig_dir, recursive = TRUE)
}

cat("Input folder:\n")
cat(pub_dir, "\n\n")

cat("Compact figure output folder:\n")
cat(fig_dir, "\n\n")

# ============================================================
# 2. Input files
# ============================================================

files <- list(
  table_7A = file.path(pub_dir, "Table_7A_Provider_Impact_3x3_Scenario_Matrix.csv"),
  table_7B = file.path(pub_dir, "Table_7B_Provider_Impact_by_Group.csv"),
  table_7G = file.path(pub_dir, "Table_7G_Access_Protection_Policy_Options.csv"),
  appendix_7K = file.path(pub_dir, "Appendix_Table_7K_Enhanced_Rural_Access_Sensitivity.csv"),
  appendix_7M = file.path(pub_dir, "Appendix_Table_7M_Behavioral_Psychiatric_Sensitivity.csv")
)

missing_files <- unlist(files)[!file.exists(unlist(files))]

if (length(missing_files) > 0) {
  stop(
    "Missing required input files. Run Script 15 first:\n",
    paste(missing_files, collapse = "\n")
  )
}

t7A <- data.table::fread(files$table_7A)
t7B <- data.table::fread(files$table_7B)
t7G <- data.table::fread(files$table_7G)
t7K <- data.table::fread(files$appendix_7K)
t7M <- data.table::fread(files$appendix_7M)

cat("Loaded compact-figure inputs.\n\n")

# ============================================================
# 3. Helper functions
# ============================================================

wrap_cell <- function(x, width = 28) {
  vapply(
    as.character(x),
    function(s) {
      s <- gsub("\\s+", " ", s)
      s <- trimws(s)
      
      if (is.na(s) || s == "" || s == "NA") {
        return("")
      }
      
      paste(strwrap(s, width = width), collapse = "\n")
    },
    character(1)
  )
}

shorten_cell <- function(x, max_chars = 180) {
  x <- as.character(x)
  ifelse(
    nchar(x) > max_chars,
    paste0(substr(x, 1, max_chars - 3), "..."),
    x
  )
}

select_existing <- function(dt, cols) {
  dt[, intersect(cols, names(dt)), with = FALSE]
}

is_numeric_like_col <- function(x) {
  vals <- as.character(x)
  
  all(
    grepl("^[-$0-9,.% /→]+$", vals) |
      is.na(vals) |
      vals == "" |
      vals == "NA"
  )
}

line_count <- function(x) {
  sapply(strsplit(as.character(x), "\n", fixed = TRUE), length)
}

draw_publication_table <- function(
    dt,
    title,
    subtitle,
    source_note,
    output_png,
    col_widths,
    col_align = NULL,
    wrap_widths = NULL,
    image_width_in = 7.2,
    dpi = 300,
    title_font = 13,
    subtitle_font = 8.5,
    header_font = 8.2,
    body_font = 8.0,
    source_font = 6.8,
    row_line_height = 0.040,
    min_body_row_height = 0.055,
    header_height = 0.060,
    top_margin = 0.030,
    bottom_margin = 0.025,
    left_margin = 0.018,
    right_margin = 0.018
) {
  dt <- as.data.table(copy(dt))
  
  if (length(col_widths) != ncol(dt)) {
    stop("col_widths length must equal number of columns in dt.")
  }
  
  col_widths <- as.numeric(col_widths)
  col_widths <- col_widths / sum(col_widths)
  
  if (is.null(col_align)) {
    col_align <- ifelse(
      vapply(dt, is_numeric_like_col, logical(1)),
      "right",
      "left"
    )
  }
  
  if (is.null(wrap_widths)) {
    wrap_widths <- rep(28, ncol(dt))
  }
  
  # Wrap text cell-by-cell.
  for (jj in seq_along(dt)) {
    if (!is_numeric_like_col(dt[[jj]])) {
      dt[[jj]] <- wrap_cell(shorten_cell(dt[[jj]], 190), width = wrap_widths[jj])
    }
  }
  
  # Header wrapping.
  header_labels <- names(dt)
  for (jj in seq_along(header_labels)) {
    header_labels[jj] <- wrap_cell(header_labels[jj], width = wrap_widths[jj])
  }
  
  # Compute row heights based on wrapped line counts.
  row_lines <- rep(1, nrow(dt))
  
  if (nrow(dt) > 0) {
    for (ii in seq_len(nrow(dt))) {
      row_lines[ii] <- max(vapply(dt[ii], function(z) line_count(z[[1]]), integer(1)))
    }
  }
  
  body_row_heights <- pmax(min_body_row_height, row_lines * row_line_height)
  table_height <- header_height + sum(body_row_heights)
  
  title_block_height <- 0.105
  source_height <- 0.035
  
  image_height_in <- max(
    3.2,
    image_width_in * (title_block_height + table_height + source_height + top_margin + bottom_margin)
  )
  
  png(
    filename = output_png,
    width = image_width_in,
    height = image_height_in,
    units = "in",
    res = dpi,
    bg = "white"
  )
  
  grid.newpage()
  
  # Coordinates in npc.
  x0 <- left_margin
  x1 <- 1 - right_margin
  usable_width <- x1 - x0
  
  y_top <- 1 - top_margin
  
  # Top rule.
  grid.lines(
    x = unit(c(x0, x1), "npc"),
    y = unit(c(y_top, y_top), "npc"),
    gp = gpar(col = "#9E9E9E", lwd = 1.1)
  )
  
  # Title.
  grid.text(
    title,
    x = unit(x0, "npc"),
    y = unit(y_top - 0.030, "npc"),
    just = c("left", "top"),
    gp = gpar(fontsize = title_font, fontface = "bold", col = "#222222")
  )
  
  # Subtitle.
  grid.text(
    subtitle,
    x = unit(x0, "npc"),
    y = unit(y_top - 0.075, "npc"),
    just = c("left", "top"),
    gp = gpar(fontsize = subtitle_font, col = "#222222")
  )
  
  table_top <- y_top - title_block_height
  table_left <- x0
  table_right <- x1
  table_width <- usable_width
  
  # Column boundaries.
  col_lefts <- table_left + c(0, cumsum(col_widths[-length(col_widths)])) * table_width
  col_rights <- table_left + cumsum(col_widths) * table_width
  
  # Header background.
  grid.rect(
    x = unit((table_left + table_right) / 2, "npc"),
    y = unit(table_top - header_height / 2, "npc"),
    width = unit(table_width, "npc"),
    height = unit(header_height, "npc"),
    gp = gpar(fill = "#EAF2F8", col = NA)
  )
  
  # Header line top/bottom.
  grid.lines(
    x = unit(c(table_left, table_right), "npc"),
    y = unit(c(table_top, table_top), "npc"),
    gp = gpar(col = "#C7C7C7", lwd = 1)
  )
  
  grid.lines(
    x = unit(c(table_left, table_right), "npc"),
    y = unit(c(table_top - header_height, table_top - header_height), "npc"),
    gp = gpar(col = "#C7C7C7", lwd = 1)
  )
  
  # Header labels.
  for (jj in seq_along(header_labels)) {
    cell_left <- col_lefts[jj]
    cell_right <- col_rights[jj]
    pad <- 0.005
    
    grid.text(
      header_labels[jj],
      x = unit(cell_left + pad, "npc"),
      y = unit(table_top - header_height / 2, "npc"),
      just = c("left", "center"),
      gp = gpar(fontsize = header_font, fontface = "bold", col = "#0F1F2F")
    )
  }
  
  # Body rows.
  y_cursor <- table_top - header_height
  
  for (ii in seq_len(nrow(dt))) {
    rh <- body_row_heights[ii]
    y_mid <- y_cursor - rh / 2
    
    # Alternating row background.
    if (ii %% 2 == 0) {
      grid.rect(
        x = unit((table_left + table_right) / 2, "npc"),
        y = unit(y_mid, "npc"),
        width = unit(table_width, "npc"),
        height = unit(rh, "npc"),
        gp = gpar(fill = "#FAFAFA", col = NA)
      )
    }
    
    # Row bottom line.
    grid.lines(
      x = unit(c(table_left, table_right), "npc"),
      y = unit(c(y_cursor - rh, y_cursor - rh), "npc"),
      gp = gpar(col = "#D6D6D6", lwd = 0.65)
    )
    
    for (jj in seq_along(dt)) {
      val <- as.character(dt[[jj]][ii])
      if (is.na(val) || val == "NA") val <- ""
      
      cell_left <- col_lefts[jj]
      cell_right <- col_rights[jj]
      pad <- 0.005
      
      align <- col_align[jj]
      
      if (align == "right") {
        x_pos <- cell_right - pad
        just <- c("right", "center")
      } else if (align == "center") {
        x_pos <- (cell_left + cell_right) / 2
        just <- c("center", "center")
      } else {
        x_pos <- cell_left + pad
        just <- c("left", "center")
      }
      
      grid.text(
        val,
        x = unit(x_pos, "npc"),
        y = unit(y_mid, "npc"),
        just = just,
        gp = gpar(
          fontsize = body_font,
          fontface = ifelse(jj == 1, "bold", "plain"),
          col = "#222222",
          lineheight = 0.95
        )
      )
    }
    
    y_cursor <- y_cursor - rh
  }
  
  # Bottom rule.
  grid.lines(
    x = unit(c(table_left, table_right), "npc"),
    y = unit(c(y_cursor, y_cursor), "npc"),
    gp = gpar(col = "#9E9E9E", lwd = 1.1)
  )
  
  # Source note.
  grid.text(
    source_note,
    x = unit(x0, "npc"),
    y = unit(y_cursor - 0.018, "npc"),
    just = c("left", "top"),
    gp = gpar(fontsize = source_font, col = "#222222")
  )
  
  # Final bottom rule.
  grid.lines(
    x = unit(c(x0, x1), "npc"),
    y = unit(c(bottom_margin, bottom_margin), "npc"),
    gp = gpar(col = "#9E9E9E", lwd = 1.0)
  )
  
  dev.off()
  
  invisible(output_png)
}

# ============================================================
# 4. Figure/Table 7-1 — Provider Impact Scenario Matrix
# ============================================================

fig_7_1 <- copy(t7A)

needed_7A <- c(
  "Repricing Scenario",
  "Stabilization Scenario",
  "Net Provider Impact ($B)",
  "Net Impact (% of NPR)",
  "Large Negative-Impact Providers",
  "Median Provider Impact (% of NPR)"
)

missing_7A_cols <- setdiff(needed_7A, names(fig_7_1))

if (length(missing_7A_cols) > 0) {
  stop(
    "Table 7A missing required columns for compact figure:\n",
    paste(missing_7A_cols, collapse = "\n")
  )
}

fig_7_1 <- fig_7_1[, ..needed_7A]

setnames(
  fig_7_1,
  old = needed_7A,
  new = c(
    "Repricing",
    "Stabilization",
    "Net Impact",
    "Impact / NPR",
    "Providers < -5%",
    "Median Impact"
  )
)

fig_7_1[, Scenario := paste(Repricing, Stabilization, sep = " / ")]

fig_7_1 <- fig_7_1[
  ,
  .(
    Scenario,
    `Net Impact`,
    `Impact / NPR`,
    `Providers < -5%`,
    `Median Impact`
  )
]

out_7_1 <- file.path(
  fig_dir,
  "Figure_Table_7_1_Provider_Impact_Scenario_Matrix.png"
)

draw_publication_table(
  dt = fig_7_1,
  title = "Figure/Table 7-1. Provider Impact Scenario Matrix",
  subtitle = "Base/Base remains the central estimate; low and high cases show sensitivity to repricing and stabilization assumptions.",
  source_note = "Source: UCC/HSE FY2024 HCRIS provider-impact model; values from final Table 7A.",
  output_png = out_7_1,
  col_widths = c(0.43, 0.15, 0.15, 0.15, 0.12),
  col_align = c("left", "right", "right", "right", "right"),
  wrap_widths = c(42, 12, 12, 13, 12),
  image_width_in = 7.2,
  title_font = 13,
  subtitle_font = 8.5,
  header_font = 8.2,
  body_font = 8.0
)

# ============================================================
# 5. Figure/Table 7-2 — Provider Impact by Provider Group
# ============================================================

fig_7_2 <- copy(t7B)

needed_7B <- c(
  "Provider Group",
  "Net Patient Revenue ($B)",
  "Net Provider Impact ($B)",
  "Net Impact (% of NPR)",
  "Large Negative-Impact Providers"
)

missing_7B_cols <- setdiff(needed_7B, names(fig_7_2))

if (length(missing_7B_cols) > 0) {
  stop(
    "Table 7B missing required columns for compact figure:\n",
    paste(missing_7B_cols, collapse = "\n")
  )
}

fig_7_2 <- fig_7_2[, ..needed_7B]

setnames(
  fig_7_2,
  old = needed_7B,
  new = c(
    "Provider Group",
    "NPR",
    "Net Impact",
    "Impact / NPR",
    "Providers < -5%"
  )
)

out_7_2 <- file.path(
  fig_dir,
  "Figure_Table_7_2_Provider_Impact_by_Group.png"
)

draw_publication_table(
  dt = fig_7_2,
  title = "Figure/Table 7-2. Provider Impact by Provider Group",
  subtitle = "Provider-side effects are concentrated in groups exposed to routine/outpatient repricing.",
  source_note = "Source: UCC/HSE FY2024 HCRIS provider-impact model; values from final Table 7B.",
  output_png = out_7_2,
  col_widths = c(0.42, 0.15, 0.15, 0.14, 0.14),
  col_align = c("left", "right", "right", "right", "right"),
  wrap_widths = c(38, 12, 12, 12, 12),
  image_width_in = 7.2,
  title_font = 13,
  subtitle_font = 8.5,
  header_font = 8.2,
  body_font = 8.0
)

# ============================================================
# 6. Figure/Table 7-3 — Access-Protection Policy Architecture
# ============================================================

fig_7_3 <- data.table::data.table(
  `Policy Issue` = c(
    "Core savings mechanism",
    "Rural access",
    "Behavioral institutions",
    "Data-quality risk"
  ),
  `Affected Providers` = c(
    "All modeled providers",
    "Rural / CAH / IHS",
    "Psychiatric / behavioral hospitals",
    "Records with anomalous exposure estimates"
  ),
  `Problem Identified` = c(
    "Routine/outpatient spending is repriced under UCC/HSE, creating provider-side revenue pressure.",
    "Low-volume rural facilities face fixed standby costs and limited substitute access.",
    "State and institutional psychiatric providers are not ordinary consumer-directed outpatient price-shopping targets.",
    "Certain records may have distorted outpatient exposure or fallback revenue estimates."
  ),
  `Policy Treatment` = c(
    "Base/Base repricing model with bounded stabilization.",
    "Permanent 2% NPR rural access guarantee capped at $5M, plus implementation floor at -1.5% NPR.",
    "Assign 25% of standard modeled repricing exposure, plus implementation floor at -5% NPR.",
    "Run exposure-anomaly sensitivity and keep detailed audit tables in appendix."
  ),
  `Policy Status` = c(
    "Core price-discipline mechanism",
    "Preferred rural option",
    "Preferred behavioral option",
    "Robustness check"
  )
)

out_7_3 <- file.path(
  fig_dir,
  "Figure_Table_7_3_Access_Protection_Policy_Architecture.png"
)

draw_publication_table(
  dt = fig_7_3,
  title = "Figure/Table 7-3. Access-Protection Policy Architecture",
  subtitle = "UCC/HSE separates core provider-side price discipline from targeted essential-access protections.",
  source_note = "Source: UCC/HSE policy architecture derived from Table 7G, rural sensitivity Table 7K, and behavioral sensitivity Table 7M.",
  output_png = out_7_3,
  col_widths = c(0.16, 0.18, 0.26, 0.27, 0.13),
  col_align = c("left", "left", "left", "left", "left"),
  wrap_widths = c(18, 20, 31, 32, 16),
  image_width_in = 7.4,
  title_font = 13,
  subtitle_font = 8.5,
  header_font = 7.8,
  body_font = 7.3,
  row_line_height = 0.034,
  min_body_row_height = 0.070
)

# ============================================================
# 7. Figure/Table 7-4 — Preferred Access-Protection Results
# ============================================================

fig_7G <- copy(t7G)

required_7G <- c(
  "Policy Layer",
  "Provider Group",
  "Added Support ($B)",
  "Net Impact After Protection ($B)",
  "Net Impact After Protection (% NPR)",
  "Providers Below -5% NPR",
  "Providers Below -10% NPR"
)

missing_7G_cols <- setdiff(required_7G, names(fig_7G))

if (length(missing_7G_cols) > 0) {
  stop(
    "Table 7G missing required columns for compact result figure:\n",
    paste(missing_7G_cols, collapse = "\n")
  )
}

selected_layers <- c(
  "Baseline provider-impact model",
  "Rural access baseline",
  "Preferred rural access protection",
  "Behavioral institutional baseline",
  "Preferred behavioral institutional treatment",
  "Preferred access-protection package"
)

fig_7_4 <- fig_7G[
  `Policy Layer` %in% selected_layers,
  ..required_7G
]

setnames(
  fig_7_4,
  old = required_7G,
  new = c(
    "Layer",
    "Group",
    "Support Added",
    "Final Net Impact",
    "Final Impact / NPR",
    "Providers < -5%",
    "Providers < -10%"
  )
)

fig_7_4[
  ,
  Layer := fifelse(
    Layer == "Baseline provider-impact model",
    "All-provider baseline",
    fifelse(
      Layer == "Rural access baseline",
      "Rural baseline",
      fifelse(
        Layer == "Preferred rural access protection",
        "Preferred rural protection",
        fifelse(
          Layer == "Behavioral institutional baseline",
          "Behavioral baseline",
          fifelse(
            Layer == "Preferred behavioral institutional treatment",
            "Preferred behavioral treatment",
            "Preferred combined package"
          )
        )
      )
    )
  )
]

fig_7_4[
  ,
  `Policy Meaning` := c(
    "Reference case",
    "Rural risk before added protection",
    "Rural providers below -5% fall to zero",
    "Behavioral outliers before adjustment",
    "Behavioral providers below -10% fall to zero",
    "Targeted package preserves overall price discipline"
  )
]

fig_7_4 <- fig_7_4[
  ,
  .(
    Layer,
    Group,
    `Support Added`,
    `Final Net Impact`,
    `Final Impact / NPR`,
    `Providers < -5%`,
    `Providers < -10%`,
    `Policy Meaning`
  )
]

out_7_4 <- file.path(
  fig_dir,
  "Figure_Table_7_4_Preferred_Access_Protection_Results.png"
)

draw_publication_table(
  dt = fig_7_4,
  title = "Figure/Table 7-4. Preferred Access-Protection Results",
  subtitle = "The preferred package adds targeted rural and behavioral protection while preserving the core provider-side savings mechanism.",
  source_note = "Source: UCC/HSE FY2024 HCRIS provider-impact model; compacted from final Table 7G.",
  output_png = out_7_4,
  col_widths = c(0.17, 0.17, 0.11, 0.12, 0.12, 0.10, 0.10, 0.11),
  col_align = c("left", "left", "right", "right", "right", "right", "right", "left"),
  wrap_widths = c(20, 20, 10, 12, 12, 10, 10, 18),
  image_width_in = 7.4,
  title_font = 13,
  subtitle_font = 8.2,
  header_font = 7.2,
  body_font = 7.0,
  row_line_height = 0.032,
  min_body_row_height = 0.062
)

# ============================================================
# 8. Appendix Figure/Table 7K — Rural scenarios
# ============================================================

fig_7K <- copy(t7K)

needed_7K <- c(
  "Scenario",
  "Added Rural Support ($B)",
  "Net Impact After Rural Support ($B)",
  "Net Impact After Rural Support (% of NPR)",
  "Rural Providers Below -5% NPR",
  "Rural Providers Below -10% NPR"
)

if (all(needed_7K %in% names(fig_7K))) {
  fig_7K <- fig_7K[, ..needed_7K]
  
  setnames(
    fig_7K,
    old = needed_7K,
    new = c(
      "Scenario",
      "Support Added",
      "Final Net Impact",
      "Final Impact / NPR",
      "Rural < -5%",
      "Rural < -10%"
    )
  )
  
  out_7K <- file.path(
    fig_dir,
    "Appendix_Figure_Table_7K_Rural_Access_Sensitivity.png"
  )
  
  draw_publication_table(
    dt = fig_7K,
    title = "Appendix Figure/Table 7K. Enhanced Rural Access Sensitivity",
    subtitle = "Scenario F is the preferred rural-access option: 2% NPR guarantee capped at $5M plus a -1.5% implementation floor.",
    source_note = "Source: UCC/HSE FY2024 HCRIS provider-impact model; values from Appendix Table 7K.",
    output_png = out_7K,
    col_widths = c(0.43, 0.13, 0.14, 0.13, 0.09, 0.08),
    col_align = c("left", "right", "right", "right", "right", "right"),
    wrap_widths = c(38, 10, 12, 12, 9, 9),
    image_width_in = 7.4,
    title_font = 13,
    subtitle_font = 8.0,
    header_font = 7.4,
    body_font = 7.2,
    row_line_height = 0.033,
    min_body_row_height = 0.055
  )
}

# ============================================================
# 9. Appendix Figure/Table 7M — Behavioral scenarios
# ============================================================

fig_7M <- copy(t7M)

needed_7M <- c(
  "Scenario",
  "Repricing Treatment",
  "Floor Treatment",
  "Added Behavioral Support ($B)",
  "Net Behavioral Impact After Scenario ($B)",
  "Net Impact After Scenario (% of NPR)",
  "Providers Below -5% NPR",
  "Providers Below -10% NPR"
)

if (all(needed_7M %in% names(fig_7M))) {
  fig_7M <- fig_7M[, ..needed_7M]
  
  setnames(
    fig_7M,
    old = needed_7M,
    new = c(
      "Scenario",
      "Repricing",
      "Floor",
      "Support Added",
      "Final Net Impact",
      "Final Impact / NPR",
      "Providers < -5%",
      "Providers < -10%"
    )
  )
  
  out_7M <- file.path(
    fig_dir,
    "Appendix_Figure_Table_7M_Behavioral_Sensitivity.png"
  )
  
  draw_publication_table(
    dt = fig_7M,
    title = "Appendix Figure/Table 7M. Psychiatric / Behavioral Provider Sensitivity",
    subtitle = "Preferred behavioral treatment assigns 25% repricing exposure plus a -5% implementation floor.",
    source_note = "Source: UCC/HSE FY2024 HCRIS provider-impact model; values from Appendix Table 7M.",
    output_png = out_7M,
    col_widths = c(0.28, 0.13, 0.13, 0.10, 0.12, 0.10, 0.07, 0.07),
    col_align = c("left", "left", "left", "right", "right", "right", "right", "right"),
    wrap_widths = c(28, 13, 13, 9, 10, 10, 8, 8),
    image_width_in = 7.4,
    title_font = 13,
    subtitle_font = 8.0,
    header_font = 7.0,
    body_font = 6.8,
    row_line_height = 0.031,
    min_body_row_height = 0.055
  )
}

# ============================================================
# 10. HTML index for visual review
# ============================================================

html_index_file <- file.path(fig_dir, "Table_7_Compact_Figure_Index.html")

png_files <- list.files(
  fig_dir,
  pattern = "\\.png$",
  full.names = FALSE
)

html_lines <- c(
  "<html>",
  "<head>",
  "<title>Table 7 Compact Publication Figures</title>",
  "<style>",
  "body { font-family: Arial, sans-serif; margin: 30px; }",
  "h1 { color: #1F2D3D; }",
  ".figure { margin-bottom: 35px; }",
  "img { max-width: 100%; border: 1px solid #ccc; }",
  "</style>",
  "</head>",
  "<body>",
  "<h1>Table 7 Compact Publication Figures</h1>",
  paste0("<p>Generated: ", Sys.time(), "</p>")
)

for (ff in png_files) {
  html_lines <- c(
    html_lines,
    "<div class='figure'>",
    paste0("<h2>", ff, "</h2>"),
    paste0("<img src='", ff, "'>"),
    "</div>"
  )
}

html_lines <- c(
  html_lines,
  "</body>",
  "</html>"
)

writeLines(html_lines, html_index_file)

# ============================================================
# 11. Manifest
# ============================================================

all_pngs <- list.files(
  fig_dir,
  pattern = "\\.png$",
  full.names = TRUE
)

manifest <- data.table::data.table(
  file = basename(all_pngs),
  path = all_pngs,
  exists = file.exists(all_pngs)
)

manifest_file <- file.path(fig_dir, "Table_7_Compact_Figure_Manifest.csv")
data.table::fwrite(manifest, manifest_file)

# ============================================================
# 12. Print summary
# ============================================================

cat("\n============================================================\n")
cat("COMPACT TABLE 7 PUBLICATION FIGURES COMPLETE\n")
cat("============================================================\n\n")

cat("Images written to:\n")
cat(fig_dir, "\n\n")

cat("Created PNG files:\n")
print(manifest)

cat("\nHTML review index:\n")
cat(html_index_file, "\n\n")

cat("Manifest:\n")
cat(manifest_file, "\n")

cat("\n============================================================\n")
```

---

