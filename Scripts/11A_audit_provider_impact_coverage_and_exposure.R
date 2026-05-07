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