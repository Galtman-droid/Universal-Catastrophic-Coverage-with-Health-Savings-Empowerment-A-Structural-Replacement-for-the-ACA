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