# Scripts/13_provider_transition_protection_sensitivity.R
# Provider transition-protection and permanent rural-access sensitivity analysis for Table 7.
#
# Purpose:
#   This script does NOT rebuild the baseline provider-impact model.
#   It reads the corrected Base/Base provider-level output from Script 11
#   and estimates:
#
#     1. temporary transition protections for providers facing large modeled losses; and
#     2. a permanent rural access guarantee that does not sunset.
#
# Inputs:
#   Output/hcris_YYYY_provider_impact_basebase_provider_level.csv
#
# Outputs:
#   Output/Table7_Publication/table_7G_transition_and_rural_access_sensitivity.csv
#   Output/Table7_Publication/table_7H_remaining_large_negative_impacts.csv
#   Output/Table7_Publication/table_7I_support_cost_by_group_class.csv
#   Output/Table7_Publication/table_7J_provider_level_transition_and_rural_access.csv
#   Output/Table7_Publication/table_7_transition_and_rural_access_methodology_notes.txt
#
# Concept:
#   Current Base/Base Table 7 formula:
#
#     Net Provider Impact =
#       - Market Repricing Pressure
#       + UC / Liquidity Offset
#       + Bounded Stabilization Support
#
#   This script tests optional protections:
#
#     Case A: Current Base/Base
#     Case B: Large-negative-impact transition add-on
#     Case C: Pediatric transition hold-harmless
#     Case D: Permanent rural access guarantee
#     Case E: Enhanced Tier 3 / Tier 4 transition stabilization
#     Case F: Combined transition protection + permanent rural access guarantee
#
# Policy principle:
#   The goal is not to hold every provider harmless.
#   The goal is to prevent essential-provider collapse during transition while preserving
#   price discipline. Rural access support is treated differently because rural access is
#   a structural access-capacity problem, not merely a transition problem.
#
# Sunset logic:
#   Temporary transition protections:
#     - large-negative-impact add-on
#     - pediatric hold-harmless
#     - Tier 3 / Tier 4 enhanced stabilization
#   These should sunset after the transition period.
#
#   Permanent support:
#     - rural access guarantee
#   This does not automatically sunset, but remains formula-based, capped, and reviewable.
#
# Important technical note:
#   data.table::fifelse() is strict about class matching. This script uses 0.0
#   and explicit as.numeric() to avoid integer/double class errors.

source("Scripts/00_setup.R")

cat("\n============================================================\n")
cat("CREATE TRANSITION-PROTECTION AND RURAL-ACCESS SENSITIVITY TABLES\n")
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
# 1. Load corrected Base/Base provider-level output
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
  "stabilization_basis",
  "transition_support_cap_rate",
  "annual_transition_support_cap_model",
  "stabilization_eligible_bounded_flag"
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

dt[
  ,
  stabilization_eligible_bounded_flag :=
    as.logical(stabilization_eligible_bounded_flag)
]

numeric_cols <- c(
  "net_patient_revenue_model",
  "outpatient_exposure_used",
  "outpatient_repricing_pressure",
  "uncompensated_care_offset",
  "stabilization_support",
  "net_provider_impact",
  "net_provider_impact_pct_of_npr",
  "stabilization_tier_numeric",
  "transition_support_cap_rate",
  "annual_transition_support_cap_model"
)

for (cc in numeric_cols) {
  dt[, (cc) := as.numeric(get(cc))]
}

modeled <- copy(dt[provider_impact_model_include_flag == TRUE])

cat("\nModeled providers:", nrow(modeled), "\n")

# ============================================================
# 3. Policy assumptions
# ============================================================

# Large negative impact threshold.
# Providers worse than -5% of NPR are considered large-negative-impact providers.
large_negative_threshold <- -0.05

# Severe negative impact threshold.
# Providers worse than -10% of NPR are considered severe-transition-risk providers.
severe_negative_threshold <- -0.10

# Case B: temporary large-negative-impact add-on.
# Offsets a portion of the provider's modeled loss beyond the -5% threshold,
# subject to a cap as a percent of NPR.
large_negative_loss_share_offset <- 0.25
large_negative_addon_cap_npr <- 0.01

# Case C: temporary pediatric hold-harmless floor.
# Pediatric providers should be protected during transition, but this support sunsets.
pediatric_floor_pct_npr <- -0.03

# Case D: permanent rural access guarantee.
# Rural help does not sunset because rural access vulnerability is structural.
permanent_rural_access_rate_npr <- 0.01

# Optional fixed-dollar cap for the permanent rural access guarantee.
# This prevents very large rural-labeled providers from receiving uncapped support.
# Set to Inf if you do not want a fixed-dollar cap.
permanent_rural_access_fixed_cap <- 3000000.0

# Case E: temporary enhanced Tier 3 / Tier 4 stabilization.
# This sunsets after transition.
tier3_incremental_cap_npr <- 0.005
tier4_incremental_cap_npr <- 0.010

# Case F: combined protection guardrail.
# Total temporary added transition support per provider is capped.
# Permanent rural access support is tracked separately because it does not sunset.
combined_temporary_support_cap_npr <- 0.025

# Optional repricing phase-in illustration.
# This is not applied to the steady-state Table 7G cases unless explicitly stated.
repricing_phase_in_year1 <- 0.40
repricing_phase_in_year2 <- 0.60
repricing_phase_in_year3 <- 0.80
repricing_phase_in_year4_plus <- 1.00

# ============================================================
# 4. Provider-level flags
# ============================================================

modeled[
  ,
  large_negative_impact_flag :=
    !is.na(net_provider_impact_pct_of_npr) &
    net_provider_impact_pct_of_npr <= large_negative_threshold
]

modeled[
  ,
  severe_negative_impact_flag :=
    !is.na(net_provider_impact_pct_of_npr) &
    net_provider_impact_pct_of_npr <= severe_negative_threshold
]

modeled[
  ,
  permanent_rural_access_eligible_flag :=
    clean_provider_group == "Rural / CAH / IHS"
]

modeled[
  ,
  pediatric_transition_eligible_flag :=
    clean_provider_group == "Children's / pediatric"
]

modeled[
  ,
  high_stabilization_tier_flag :=
    stabilization_tier_numeric >= 3L
]

modeled[
  ,
  tier3_flag :=
    stabilization_tier_numeric == 3L
]

modeled[
  ,
  tier4_flag :=
    stabilization_tier_numeric == 4L
]

# Amount of loss beyond the -5% NPR threshold.
modeled[
  ,
  loss_beyond_large_negative_threshold :=
    data.table::fifelse(
      large_negative_impact_flag == TRUE,
      as.numeric(
        abs(net_provider_impact) -
          abs(net_patient_revenue_model * large_negative_threshold)
      ),
      0.0
    )
]

modeled[
  loss_beyond_large_negative_threshold < 0 |
    is.na(loss_beyond_large_negative_threshold),
  loss_beyond_large_negative_threshold := 0.0
]

# ============================================================
# 5. Case A: Current Base/Base
# ============================================================

modeled[
  ,
  case_A_temporary_support := 0.0
]

modeled[
  ,
  case_A_permanent_rural_access_support := 0.0
]

modeled[
  ,
  case_A_total_added_support := 0.0
]

modeled[
  ,
  case_A_net_impact := as.numeric(net_provider_impact)
]

modeled[
  ,
  case_A_net_impact_pct_npr :=
    as.numeric(net_provider_impact_pct_of_npr)
]

# ============================================================
# 6. Case B: Temporary large-negative-impact add-on
# ============================================================

modeled[
  ,
  case_B_large_negative_addon :=
    pmin(
      as.numeric(loss_beyond_large_negative_threshold * large_negative_loss_share_offset),
      as.numeric(net_patient_revenue_model * large_negative_addon_cap_npr),
      na.rm = TRUE
    )
]

modeled[
  is.na(case_B_large_negative_addon),
  case_B_large_negative_addon := 0.0
]

modeled[
  ,
  case_B_temporary_support :=
    as.numeric(case_B_large_negative_addon)
]

modeled[
  ,
  case_B_permanent_rural_access_support := 0.0
]

modeled[
  ,
  case_B_total_added_support :=
    as.numeric(case_B_temporary_support + case_B_permanent_rural_access_support)
]

modeled[
  ,
  case_B_net_impact :=
    as.numeric(net_provider_impact + case_B_total_added_support)
]

modeled[
  ,
  case_B_net_impact_pct_npr :=
    data.table::fifelse(
      net_patient_revenue_model > 0,
      as.numeric(case_B_net_impact / net_patient_revenue_model),
      NA_real_
    )
]

# ============================================================
# 7. Case C: Temporary pediatric hold-harmless floor
# ============================================================

modeled[
  ,
  case_C_pediatric_hold_harmless_needed :=
    data.table::fifelse(
      pediatric_transition_eligible_flag == TRUE &
        net_provider_impact_pct_of_npr < pediatric_floor_pct_npr,
      as.numeric(
        (net_patient_revenue_model * pediatric_floor_pct_npr) -
          net_provider_impact
      ),
      0.0
    )
]

modeled[
  case_C_pediatric_hold_harmless_needed < 0 |
    is.na(case_C_pediatric_hold_harmless_needed),
  case_C_pediatric_hold_harmless_needed := 0.0
]

modeled[
  ,
  case_C_temporary_support :=
    as.numeric(case_C_pediatric_hold_harmless_needed)
]

modeled[
  ,
  case_C_permanent_rural_access_support := 0.0
]

modeled[
  ,
  case_C_total_added_support :=
    as.numeric(case_C_temporary_support + case_C_permanent_rural_access_support)
]

modeled[
  ,
  case_C_net_impact :=
    as.numeric(net_provider_impact + case_C_total_added_support)
]

modeled[
  ,
  case_C_net_impact_pct_npr :=
    data.table::fifelse(
      net_patient_revenue_model > 0,
      as.numeric(case_C_net_impact / net_patient_revenue_model),
      NA_real_
    )
]

# ============================================================
# 8. Case D: Permanent rural access guarantee
# ============================================================

modeled[
  ,
  case_D_rural_access_uncapped :=
    data.table::fifelse(
      permanent_rural_access_eligible_flag == TRUE,
      as.numeric(net_patient_revenue_model * permanent_rural_access_rate_npr),
      0.0
    )
]

modeled[
  ,
  case_D_permanent_rural_access_support :=
    pmin(
      as.numeric(case_D_rural_access_uncapped),
      permanent_rural_access_fixed_cap,
      na.rm = TRUE
    )
]

modeled[
  is.na(case_D_permanent_rural_access_support),
  case_D_permanent_rural_access_support := 0.0
]

modeled[
  ,
  case_D_temporary_support := 0.0
]

modeled[
  ,
  case_D_total_added_support :=
    as.numeric(case_D_temporary_support + case_D_permanent_rural_access_support)
]

modeled[
  ,
  case_D_net_impact :=
    as.numeric(net_provider_impact + case_D_total_added_support)
]

modeled[
  ,
  case_D_net_impact_pct_npr :=
    data.table::fifelse(
      net_patient_revenue_model > 0,
      as.numeric(case_D_net_impact / net_patient_revenue_model),
      NA_real_
    )
]

# ============================================================
# 9. Case E: Temporary enhanced Tier 3 / Tier 4 stabilization
# ============================================================

modeled[
  ,
  case_E_tier_enhancement :=
    data.table::fcase(
      tier4_flag == TRUE,
      as.numeric(net_patient_revenue_model * tier4_incremental_cap_npr),
      
      tier3_flag == TRUE,
      as.numeric(net_patient_revenue_model * tier3_incremental_cap_npr),
      
      default = 0.0
    )
]

modeled[
  is.na(case_E_tier_enhancement),
  case_E_tier_enhancement := 0.0
]

modeled[
  ,
  case_E_temporary_support :=
    as.numeric(case_E_tier_enhancement)
]

modeled[
  ,
  case_E_permanent_rural_access_support := 0.0
]

modeled[
  ,
  case_E_total_added_support :=
    as.numeric(case_E_temporary_support + case_E_permanent_rural_access_support)
]

modeled[
  ,
  case_E_net_impact :=
    as.numeric(net_provider_impact + case_E_total_added_support)
]

modeled[
  ,
  case_E_net_impact_pct_npr :=
    data.table::fifelse(
      net_patient_revenue_model > 0,
      as.numeric(case_E_net_impact / net_patient_revenue_model),
      NA_real_
    )
]

# ============================================================
# 10. Case F: Combined transition protection + permanent rural access
# ============================================================

# Temporary support components:
#   - Case B large-negative-impact add-on
#   - Case C pediatric hold-harmless
#   - Case E Tier 3 / Tier 4 enhancement
#
# Permanent rural access component:
#   - Case D rural access guarantee
#
# Temporary support is capped per provider.
# Permanent rural access is not sunset and is tracked separately.

modeled[
  ,
  case_F_uncapped_temporary_support :=
    as.numeric(
      case_B_large_negative_addon +
        case_C_pediatric_hold_harmless_needed +
        case_E_tier_enhancement
    )
]

modeled[
  ,
  case_F_temporary_support_cap :=
    as.numeric(net_patient_revenue_model * combined_temporary_support_cap_npr)
]

modeled[
  ,
  case_F_temporary_support :=
    pmin(
      as.numeric(case_F_uncapped_temporary_support),
      as.numeric(case_F_temporary_support_cap),
      na.rm = TRUE
    )
]

modeled[
  is.na(case_F_temporary_support),
  case_F_temporary_support := 0.0
]

modeled[
  ,
  case_F_permanent_rural_access_support :=
    as.numeric(case_D_permanent_rural_access_support)
]

modeled[
  ,
  case_F_total_added_support :=
    as.numeric(case_F_temporary_support + case_F_permanent_rural_access_support)
]

modeled[
  ,
  case_F_net_impact :=
    as.numeric(net_provider_impact + case_F_total_added_support)
]

modeled[
  ,
  case_F_net_impact_pct_npr :=
    data.table::fifelse(
      net_patient_revenue_model > 0,
      as.numeric(case_F_net_impact / net_patient_revenue_model),
      NA_real_
    )
]

# ============================================================
# 11. Optional repricing phase-in illustration
# ============================================================

modeled[
  ,
  phasein_year1_net_impact :=
    as.numeric(
      (outpatient_repricing_pressure * repricing_phase_in_year1) +
        uncompensated_care_offset +
        stabilization_support
    )
]

modeled[
  ,
  phasein_year2_net_impact :=
    as.numeric(
      (outpatient_repricing_pressure * repricing_phase_in_year2) +
        uncompensated_care_offset +
        stabilization_support
    )
]

modeled[
  ,
  phasein_year3_net_impact :=
    as.numeric(
      (outpatient_repricing_pressure * repricing_phase_in_year3) +
        uncompensated_care_offset +
        stabilization_support
    )
]

modeled[
  ,
  phasein_year4_plus_net_impact :=
    as.numeric(
      (outpatient_repricing_pressure * repricing_phase_in_year4_plus) +
        uncompensated_care_offset +
        stabilization_support
    )
]

for (yy in c("year1", "year2", "year3", "year4_plus")) {
  impact_col <- paste0("phasein_", yy, "_net_impact")
  pct_col <- paste0("phasein_", yy, "_net_impact_pct_npr")
  
  modeled[
    ,
    (pct_col) := data.table::fifelse(
      net_patient_revenue_model > 0,
      as.numeric(get(impact_col) / net_patient_revenue_model),
      NA_real_
    )
  ]
}

# ============================================================
# 12. Helper functions
# ============================================================

billion <- function(x) {
  round(as.numeric(x) / 1e9, 2)
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

make_case_summary <- function(
    dt,
    case_id,
    case_name,
    temporary_support_col,
    permanent_rural_support_col,
    total_support_col,
    impact_col,
    pct_col,
    sunset_status
) {
  data.table::data.table(
    `Case` = case_id,
    `Protection Design` = case_name,
    `Sunset Treatment` = sunset_status,
    `Modeled Providers` = nrow(dt),
    `Total Net Patient Revenue ($B)` =
      billion(safe_sum(dt$net_patient_revenue_model)),
    `Original Repricing Pressure ($B)` =
      billion(safe_sum(dt$outpatient_repricing_pressure)),
    `Original UC / Liquidity Offset ($B)` =
      billion(safe_sum(dt$uncompensated_care_offset)),
    `Original Stabilization Support ($B)` =
      billion(safe_sum(dt$stabilization_support)),
    `Temporary Transition Support ($B)` =
      billion(safe_sum(dt[[temporary_support_col]])),
    `Permanent Rural Access Support ($B)` =
      billion(safe_sum(dt[[permanent_rural_support_col]])),
    `Total Added Support ($B)` =
      billion(safe_sum(dt[[total_support_col]])),
    `Net Provider Impact After Support ($B)` =
      billion(safe_sum(dt[[impact_col]])),
    `Net Impact After Support (% of NPR)` =
      pct1(
        safe_div(
          safe_sum(dt[[impact_col]]),
          safe_sum(dt$net_patient_revenue_model)
        )
      ),
    `Median Provider Impact After Support (% of NPR)` =
      pct1(median(dt[[pct_col]], na.rm = TRUE)),
    `Providers Below -5% NPR` =
      num0(sum(dt[[pct_col]] <= large_negative_threshold, na.rm = TRUE)),
    `Providers Below -10% NPR` =
      num0(sum(dt[[pct_col]] <= severe_negative_threshold, na.rm = TRUE)),
    `Providers Negative` =
      num0(sum(dt[[impact_col]] < 0, na.rm = TRUE)),
    `Providers Positive` =
      num0(sum(dt[[impact_col]] > 0, na.rm = TRUE))
  )
}

# ============================================================
# 13. Table 7G — Transition and rural access sensitivity
# ============================================================

table_7G <- data.table::rbindlist(
  list(
    make_case_summary(
      modeled,
      "A",
      "Current Base/Base; no additional support",
      "case_A_temporary_support",
      "case_A_permanent_rural_access_support",
      "case_A_total_added_support",
      "case_A_net_impact",
      "case_A_net_impact_pct_npr",
      "No additional support"
    ),
    make_case_summary(
      modeled,
      "B",
      "Temporary large-negative-impact add-on for providers below -5% NPR",
      "case_B_temporary_support",
      "case_B_permanent_rural_access_support",
      "case_B_total_added_support",
      "case_B_net_impact",
      "case_B_net_impact_pct_npr",
      "Temporary; sunsets after transition"
    ),
    make_case_summary(
      modeled,
      "C",
      "Temporary pediatric hold-harmless floor at -3% NPR",
      "case_C_temporary_support",
      "case_C_permanent_rural_access_support",
      "case_C_total_added_support",
      "case_C_net_impact",
      "case_C_net_impact_pct_npr",
      "Temporary; sunsets after transition"
    ),
    make_case_summary(
      modeled,
      "D",
      "Permanent rural access guarantee",
      "case_D_temporary_support",
      "case_D_permanent_rural_access_support",
      "case_D_total_added_support",
      "case_D_net_impact",
      "case_D_net_impact_pct_npr",
      "Permanent; formula-based and capped"
    ),
    make_case_summary(
      modeled,
      "E",
      "Temporary enhanced Tier 3 / Tier 4 stabilization",
      "case_E_temporary_support",
      "case_E_permanent_rural_access_support",
      "case_E_total_added_support",
      "case_E_net_impact",
      "case_E_net_impact_pct_npr",
      "Temporary; sunsets after transition"
    ),
    make_case_summary(
      modeled,
      "F",
      "Combined temporary transition protection + permanent rural access guarantee",
      "case_F_temporary_support",
      "case_F_permanent_rural_access_support",
      "case_F_total_added_support",
      "case_F_net_impact",
      "case_F_net_impact_pct_npr",
      "Temporary transition support sunsets; rural access support remains"
    )
  ),
  fill = TRUE
)

# ============================================================
# 14. Table 7H — Remaining large negative impacts by group
# ============================================================

make_remaining_by_group <- function(
    dt,
    case_id,
    case_name,
    pct_col,
    impact_col,
    temporary_support_col,
    permanent_rural_support_col,
    total_support_col,
    sunset_status
) {
  dt[
    ,
    .(
      `Providers` = .N,
      `Providers Below -5% NPR` =
        sum(get(pct_col) <= large_negative_threshold, na.rm = TRUE),
      `Providers Below -10% NPR` =
        sum(get(pct_col) <= severe_negative_threshold, na.rm = TRUE),
      `Negative Providers` =
        sum(get(impact_col) < 0, na.rm = TRUE),
      `Positive Providers` =
        sum(get(impact_col) > 0, na.rm = TRUE),
      `Temporary Support ($B)` =
        billion(safe_sum(get(temporary_support_col))),
      `Permanent Rural Access Support ($B)` =
        billion(safe_sum(get(permanent_rural_support_col))),
      `Total Added Support ($B)` =
        billion(safe_sum(get(total_support_col))),
      `Net Provider Impact ($B)` =
        billion(safe_sum(get(impact_col))),
      `Net Impact (% of NPR)` =
        pct1(
          safe_div(
            safe_sum(get(impact_col)),
            safe_sum(net_patient_revenue_model)
          )
        ),
      `Median Impact (% of NPR)` =
        pct1(median(get(pct_col), na.rm = TRUE))
    ),
    by = clean_provider_group
  ][
    ,
    `Case` := case_id
  ][
    ,
    `Protection Design` := case_name
  ][
    ,
    `Sunset Treatment` := sunset_status
  ][
    ,
    .(
      `Case`,
      `Protection Design`,
      `Sunset Treatment`,
      `Provider Group` = clean_provider_group,
      `Providers`,
      `Providers Below -5% NPR`,
      `Providers Below -10% NPR`,
      `Negative Providers`,
      `Positive Providers`,
      `Temporary Support ($B)`,
      `Permanent Rural Access Support ($B)`,
      `Total Added Support ($B)`,
      `Net Provider Impact ($B)`,
      `Net Impact (% of NPR)`,
      `Median Impact (% of NPR)`
    )
  ]
}

table_7H <- data.table::rbindlist(
  list(
    make_remaining_by_group(
      modeled,
      "A",
      "Current Base/Base",
      "case_A_net_impact_pct_npr",
      "case_A_net_impact",
      "case_A_temporary_support",
      "case_A_permanent_rural_access_support",
      "case_A_total_added_support",
      "No additional support"
    ),
    make_remaining_by_group(
      modeled,
      "B",
      "Temporary large-negative-impact add-on",
      "case_B_net_impact_pct_npr",
      "case_B_net_impact",
      "case_B_temporary_support",
      "case_B_permanent_rural_access_support",
      "case_B_total_added_support",
      "Temporary; sunsets after transition"
    ),
    make_remaining_by_group(
      modeled,
      "C",
      "Temporary pediatric hold-harmless",
      "case_C_net_impact_pct_npr",
      "case_C_net_impact",
      "case_C_temporary_support",
      "case_C_permanent_rural_access_support",
      "case_C_total_added_support",
      "Temporary; sunsets after transition"
    ),
    make_remaining_by_group(
      modeled,
      "D",
      "Permanent rural access guarantee",
      "case_D_net_impact_pct_npr",
      "case_D_net_impact",
      "case_D_temporary_support",
      "case_D_permanent_rural_access_support",
      "case_D_total_added_support",
      "Permanent; formula-based and capped"
    ),
    make_remaining_by_group(
      modeled,
      "E",
      "Temporary enhanced Tier 3 / Tier 4 stabilization",
      "case_E_net_impact_pct_npr",
      "case_E_net_impact",
      "case_E_temporary_support",
      "case_E_permanent_rural_access_support",
      "case_E_total_added_support",
      "Temporary; sunsets after transition"
    ),
    make_remaining_by_group(
      modeled,
      "F",
      "Combined temporary transition protection + permanent rural access guarantee",
      "case_F_net_impact_pct_npr",
      "case_F_net_impact",
      "case_F_temporary_support",
      "case_F_permanent_rural_access_support",
      "case_F_total_added_support",
      "Temporary support sunsets; rural access support remains"
    )
  ),
  fill = TRUE
)[order(`Case`, `Provider Group`)]

# ============================================================
# 15. Table 7I — Support cost by group/class
# ============================================================

table_7I <- modeled[
  ,
  .(
    providers = .N,
    
    current_net_impact =
      safe_sum(case_A_net_impact),
    
    large_negative_addon_cost =
      safe_sum(case_B_temporary_support),
    
    pediatric_hold_harmless_cost =
      safe_sum(case_C_temporary_support),
    
    permanent_rural_access_cost =
      safe_sum(case_D_permanent_rural_access_support),
    
    tier3_tier4_enhancement_cost =
      safe_sum(case_E_temporary_support),
    
    combined_temporary_support =
      safe_sum(case_F_temporary_support),
    
    combined_permanent_rural_access_support =
      safe_sum(case_F_permanent_rural_access_support),
    
    combined_total_added_support =
      safe_sum(case_F_total_added_support),
    
    combined_net_impact =
      safe_sum(case_F_net_impact),
    
    providers_below_minus_5_current =
      sum(case_A_net_impact_pct_npr <= large_negative_threshold, na.rm = TRUE),
    
    providers_below_minus_5_combined =
      sum(case_F_net_impact_pct_npr <= large_negative_threshold, na.rm = TRUE),
    
    providers_below_minus_10_current =
      sum(case_A_net_impact_pct_npr <= severe_negative_threshold, na.rm = TRUE),
    
    providers_below_minus_10_combined =
      sum(case_F_net_impact_pct_npr <= severe_negative_threshold, na.rm = TRUE)
  ),
  by = .(
    clean_provider_group,
    clean_provider_model_class
  )
][
  ,
  .(
    `Provider Group` = clean_provider_group,
    `Provider Class` = clean_provider_model_class,
    `Providers` = providers,
    `Current Net Impact ($B)` = billion(current_net_impact),
    `Large-Negative Add-On Cost ($B)` = billion(large_negative_addon_cost),
    `Pediatric Hold-Harmless Cost ($B)` = billion(pediatric_hold_harmless_cost),
    `Permanent Rural Access Cost ($B)` = billion(permanent_rural_access_cost),
    `Tier 3/4 Enhancement Cost ($B)` = billion(tier3_tier4_enhancement_cost),
    `Combined Temporary Support ($B)` = billion(combined_temporary_support),
    `Combined Permanent Rural Access Support ($B)` = billion(combined_permanent_rural_access_support),
    `Combined Total Added Support ($B)` = billion(combined_total_added_support),
    `Combined Net Impact ($B)` = billion(combined_net_impact),
    `Providers Below -5% Current` = providers_below_minus_5_current,
    `Providers Below -5% Combined` = providers_below_minus_5_combined,
    `Providers Below -10% Current` = providers_below_minus_10_current,
    `Providers Below -10% Combined` = providers_below_minus_10_combined
  )
][order(`Provider Group`, `Provider Class`)]

# ============================================================
# 16. Table 7J — Provider-level output
# ============================================================

table_7J <- modeled[
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
    
    net_patient_revenue_model,
    outpatient_exposure_used,
    outpatient_repricing_pressure,
    uncompensated_care_offset,
    stabilization_support,
    net_provider_impact,
    net_provider_impact_pct_of_npr,
    
    stabilization_tier,
    stabilization_basis,
    transition_support_cap_rate,
    annual_transition_support_cap_model,
    
    large_negative_impact_flag,
    severe_negative_impact_flag,
    permanent_rural_access_eligible_flag,
    pediatric_transition_eligible_flag,
    high_stabilization_tier_flag,
    
    case_B_temporary_support,
    case_C_temporary_support,
    case_D_permanent_rural_access_support,
    case_E_temporary_support,
    case_F_temporary_support,
    case_F_permanent_rural_access_support,
    case_F_total_added_support,
    
    case_A_net_impact,
    case_A_net_impact_pct_npr,
    case_B_net_impact,
    case_B_net_impact_pct_npr,
    case_C_net_impact,
    case_C_net_impact_pct_npr,
    case_D_net_impact,
    case_D_net_impact_pct_npr,
    case_E_net_impact,
    case_E_net_impact_pct_npr,
    case_F_net_impact,
    case_F_net_impact_pct_npr,
    
    phasein_year1_net_impact,
    phasein_year1_net_impact_pct_npr,
    phasein_year2_net_impact,
    phasein_year2_net_impact_pct_npr,
    phasein_year3_net_impact,
    phasein_year3_net_impact_pct_npr,
    phasein_year4_plus_net_impact,
    phasein_year4_plus_net_impact_pct_npr
  )
][order(case_F_net_impact_pct_npr)]

# ============================================================
# 17. Methodology notes
# ============================================================

methodology_notes <- c(
  "Table 7G-7J transition-protection and rural-access methodology notes",
  "====================================================================",
  "",
  paste0("Build year: ", hcris_year_label),
  paste0("Generated: ", Sys.time()),
  "",
  "These tables are sensitivity analyses layered on top of the corrected Base/Base provider-impact model.",
  "They do not rebuild the core provider-impact model and do not alter Tables 7A-7F.",
  "",
  "Core Base/Base equation:",
  "Net Provider Impact = - Market Repricing Pressure + UC/Liquidity Offset + Bounded Stabilization Support.",
  "",
  "Policy distinction:",
  "Temporary transition stabilization and permanent rural access support are treated separately.",
  "",
  "Temporary transition stabilization addresses short-run adjustment stress created by the movement from comprehensive insurance to UCC/HSE routine-care price discipline.",
  "Permanent rural access support addresses structural rural access constraints that do not disappear after transition: low volume, fixed standby costs, large service areas, workforce constraints, and lack of substitute providers.",
  "",
  "Case A: Current Base/Base",
  "No additional support beyond the original bounded stabilization layer.",
  "",
  "Case B: Temporary large-negative-impact add-on",
  paste0(
    "Providers with net impact at or below ",
    pct1(large_negative_threshold),
    "% of net patient revenue receive an add-on equal to ",
    pct1(large_negative_loss_share_offset),
    "% of the loss beyond that threshold, capped at ",
    pct1(large_negative_addon_cap_npr),
    "% of NPR. This support sunsets after transition."
  ),
  "",
  "Case C: Temporary pediatric hold-harmless",
  paste0(
    "Children's / pediatric providers receive enough support to prevent modeled net impact from being worse than ",
    pct1(pediatric_floor_pct_npr),
    "% of NPR. This support sunsets after transition."
  ),
  "",
  "Case D: Permanent rural access guarantee",
  paste0(
    "Rural / CAH / IHS providers receive a permanent rural access payment equal to ",
    pct1(permanent_rural_access_rate_npr),
    "% of NPR, capped at $",
    format(permanent_rural_access_fixed_cap, big.mark = ","),
    " per provider annually. This support does not automatically sunset."
  ),
  "",
  "Case E: Temporary enhanced Tier 3 / Tier 4 stabilization",
  paste0(
    "Tier 3 providers receive an incremental ",
    pct1(tier3_incremental_cap_npr),
    "% of NPR; Tier 4 providers receive an incremental ",
    pct1(tier4_incremental_cap_npr),
    "% of NPR. This support sunsets after transition."
  ),
  "",
  "Case F: Combined transition protection + permanent rural access guarantee",
  paste0(
    "Combines temporary large-negative-impact protection, pediatric hold-harmless, Tier 3 / Tier 4 enhancement, and permanent rural access support. Temporary support is capped at ",
    pct1(combined_temporary_support_cap_npr),
    "% of NPR per provider. Rural access support remains as a permanent formula-based access-capacity payment."
  ),
  "",
  "Interpretive rule:",
  "The goal is not to hold every provider harmless. The goal is to prevent essential-provider collapse during transition while preserving price discipline.",
  "",
  "Recommended policy framing:",
  "Temporary support for transition losses; permanent support for essential rural access.",
  "",
  "Optional repricing phase-in fields:",
  paste0("Year 1 repricing phase-in factor: ", pct1(repricing_phase_in_year1), "%"),
  paste0("Year 2 repricing phase-in factor: ", pct1(repricing_phase_in_year2), "%"),
  paste0("Year 3 repricing phase-in factor: ", pct1(repricing_phase_in_year3), "%"),
  paste0("Year 4+ repricing phase-in factor: ", pct1(repricing_phase_in_year4_plus), "%")
)

# ============================================================
# 18. Save outputs
# ============================================================

table_7G_file <- file.path(
  table7_dir,
  "table_7G_transition_and_rural_access_sensitivity.csv"
)

table_7H_file <- file.path(
  table7_dir,
  "table_7H_remaining_large_negative_impacts.csv"
)

table_7I_file <- file.path(
  table7_dir,
  "table_7I_support_cost_by_group_class.csv"
)

table_7J_file <- file.path(
  table7_dir,
  "table_7J_provider_level_transition_and_rural_access.csv"
)

methodology_file <- file.path(
  table7_dir,
  "table_7_transition_and_rural_access_methodology_notes.txt"
)

data.table::fwrite(table_7G, table_7G_file)
data.table::fwrite(table_7H, table_7H_file)
data.table::fwrite(table_7I, table_7I_file)
data.table::fwrite(table_7J, table_7J_file)
writeLines(methodology_notes, methodology_file)

# Optional Excel workbook.
excel_file <- file.path(
  table7_dir,
  "table_7G_to_7J_transition_and_rural_access_sensitivity.xlsx"
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
  
  add_sheet(wb, "Table 7G", table_7G)
  add_sheet(wb, "Table 7H", table_7H)
  add_sheet(wb, "Table 7I", table_7I)
  add_sheet(wb, "Table 7J", table_7J)
  
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
# 19. Print summaries
# ============================================================

cat("\n============================================================\n")
cat("TRANSITION-PROTECTION AND RURAL-ACCESS SENSITIVITY COMPLETE\n")
cat("============================================================\n")

cat("\nAssumptions:\n")
cat("Large negative threshold:", pct1(large_negative_threshold), "% NPR\n")
cat("Severe negative threshold:", pct1(severe_negative_threshold), "% NPR\n")
cat("Large-negative add-on offset share:", pct1(large_negative_loss_share_offset), "%\n")
cat("Large-negative add-on cap:", pct1(large_negative_addon_cap_npr), "% NPR\n")
cat("Pediatric temporary floor:", pct1(pediatric_floor_pct_npr), "% NPR\n")
cat("Permanent rural access rate:", pct1(permanent_rural_access_rate_npr), "% NPR\n")
cat("Permanent rural access fixed cap: $", format(permanent_rural_access_fixed_cap, big.mark = ","), "\n", sep = "")
cat("Tier 3 incremental cap:", pct1(tier3_incremental_cap_npr), "% NPR\n")
cat("Tier 4 incremental cap:", pct1(tier4_incremental_cap_npr), "% NPR\n")
cat("Combined temporary support cap:", pct1(combined_temporary_support_cap_npr), "% NPR\n")

cat("\nTable 7G. Transition and Rural Access Sensitivity:\n")
print(table_7G)

cat("\nTable 7H. Remaining Large Negative Impacts by Group:\n")
print(table_7H)

cat("\nTable 7I. Support Cost by Group/Class:\n")
print(table_7I)

cat("\nWorst remaining providers under combined protection:\n")
print(table_7J[
  ,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    state_abbrev,
    clean_provider_group,
    clean_provider_model_class,
    net_patient_revenue_model,
    case_A_net_impact_pct_npr,
    case_F_temporary_support,
    case_F_permanent_rural_access_support,
    case_F_total_added_support,
    case_F_net_impact_pct_npr,
    large_negative_impact_flag,
    severe_negative_impact_flag,
    permanent_rural_access_eligible_flag,
    pediatric_transition_eligible_flag,
    stabilization_tier
  )
][order(case_F_net_impact_pct_npr)][1:50])

cat("\nSaved:\n")
cat(table_7G_file, "\n")
cat(table_7H_file, "\n")
cat(table_7I_file, "\n")
cat(table_7J_file, "\n")
cat(methodology_file, "\n")

if (excel_written == TRUE) {
  cat(excel_file, "\n")
}

cat("\n============================================================\n")