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