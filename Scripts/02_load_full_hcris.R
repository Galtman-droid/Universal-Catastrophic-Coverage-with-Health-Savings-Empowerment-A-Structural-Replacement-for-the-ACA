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