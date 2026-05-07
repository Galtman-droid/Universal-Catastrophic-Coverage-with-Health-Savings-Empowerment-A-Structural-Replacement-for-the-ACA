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