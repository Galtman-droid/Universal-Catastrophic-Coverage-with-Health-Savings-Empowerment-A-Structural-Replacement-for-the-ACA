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