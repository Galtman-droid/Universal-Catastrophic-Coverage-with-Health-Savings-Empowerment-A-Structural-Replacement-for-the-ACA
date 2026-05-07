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