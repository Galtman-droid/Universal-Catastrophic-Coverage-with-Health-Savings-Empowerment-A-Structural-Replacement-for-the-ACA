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