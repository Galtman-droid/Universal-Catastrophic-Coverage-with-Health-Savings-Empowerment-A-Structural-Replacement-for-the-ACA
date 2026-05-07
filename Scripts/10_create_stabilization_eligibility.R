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