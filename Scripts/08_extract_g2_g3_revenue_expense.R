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
