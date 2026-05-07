# Scripts/14_create_table7_access_protection_summary.R
# Create publication-ready Table 7 access-protection summary.
#
# Purpose:
#   This script does NOT rebuild the HCRIS model.
#   It reads the already-generated Table 7 baseline, enhanced rural, and
#   psychiatric / behavioral sensitivity outputs, then creates a compact
#   publication-facing access-protection summary table.
#
# Required prior scripts:
#   12_format_table7_publication_outputs.R
#   13B_enhanced_rural_access_sensitivity.R
#   13C_behavioral_psychiatric_sensitivity.R
#
# Inputs:
#   Output/Table7_Publication/table_7A_publication.csv
#   Output/Table7_Publication/table_7B_publication.csv
#   Output/Table7_Publication/table_7K_enhanced_rural_access_sensitivity.csv
#   Output/Table7_Publication/table_7M_behavioral_psychiatric_sensitivity.csv
#   Output/Table7_Publication/table_7O_behavioral_remaining_severe_effects.csv
#
# Outputs:
#   Output/Table7_Publication/table_7G_access_protection_policy_options.csv
#   Output/Table7_Publication/table_7G_access_protection_options_appendix.csv
#   Output/Table7_Publication/table_7_access_protection_summary_notes.txt
#   Output/Table7_Publication/table_7_access_protection_formula_notes.txt
#   Output/Table7_Publication/table_7G_access_protection_policy_options.xlsx
#
# Preferred policy settings reflected:
#   Rural preferred option:
#     Scenario F from Table 7K:
#       Enhanced rural guarantee + rural floor at -1.5% NPR
#       Permanent component: 2% NPR, capped at $5M per rural provider
#       Implementation-period floor: -1.5% NPR
#
#   Behavioral preferred option:
#     Scenario F from Table 7M / 7O:
#       25% behavioral repricing pressure + -5.0% NPR floor
#
# Interpretation:
#   General transition support can sunset.
#   Rural access support should remain permanent, capped, and formula-based.
#   Behavioral institutional treatment is a separate repricing/exposure adjustment,
#   not a rural-style geographic access payment.

source("Scripts/00_setup.R")

cat("\n============================================================\n")
cat("CREATE TABLE 7 ACCESS-PROTECTION SUMMARY\n")
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
# 1. Input files
# ============================================================

table_7A_file <- file.path(
  table7_dir,
  "table_7A_publication.csv"
)

table_7B_file <- file.path(
  table7_dir,
  "table_7B_publication.csv"
)

table_7K_file <- file.path(
  table7_dir,
  "table_7K_enhanced_rural_access_sensitivity.csv"
)

table_7M_file <- file.path(
  table7_dir,
  "table_7M_behavioral_psychiatric_sensitivity.csv"
)

table_7O_file <- file.path(
  table7_dir,
  "table_7O_behavioral_remaining_severe_effects.csv"
)

required_files <- c(
  table_7A_file,
  table_7B_file,
  table_7K_file,
  table_7M_file,
  table_7O_file
)

missing_files <- required_files[!file.exists(required_files)]

if (length(missing_files) > 0) {
  stop(
    "Missing required input files. Run Scripts 12, 13B, and 13C first:\n",
    paste(missing_files, collapse = "\n")
  )
}

# ============================================================
# 2. Read inputs
# ============================================================

table_7A <- data.table::fread(table_7A_file)
table_7B <- data.table::fread(table_7B_file)
table_7K <- data.table::fread(table_7K_file)
table_7M <- data.table::fread(table_7M_file)
table_7O <- data.table::fread(table_7O_file)

cat("Loaded:\n")
cat(table_7A_file, "\n")
cat(table_7B_file, "\n")
cat(table_7K_file, "\n")
cat(table_7M_file, "\n")
cat(table_7O_file, "\n\n")

# ============================================================
# 3. Helpers
# ============================================================

clean_text <- function(x) {
  stringr::str_to_lower(stringr::str_trim(as.character(x)))
}

as_dollars_b <- function(x) {
  round(as.numeric(x), 3)
}

as_pct <- function(x) {
  round(as.numeric(x), 1)
}

as_count <- function(x) {
  as.integer(round(as.numeric(x), 0))
}

safe_numeric <- function(x) {
  suppressWarnings(as.numeric(x))
}

get_row <- function(dt, colname, pattern) {
  if (!colname %in% names(dt)) {
    stop("Missing column: ", colname)
  }
  
  pattern_clean <- clean_text(pattern)
  
  dt[
    ,
    row_match_text_tmp :=
      clean_text(get(colname))
  ]
  
  out <- dt[stringr::str_detect(row_match_text_tmp, pattern_clean)]
  
  if (nrow(out) == 0) {
    cat("\nNo row matched pattern: ", pattern, "\n", sep = "")
    cat("Available values in ", colname, ":\n", sep = "")
    print(dt[, .(value = get(colname))])
    
    dt[, row_match_text_tmp := NULL]
    stop("No row matched requested pattern.")
  }
  
  out <- out[1]
  dt[, row_match_text_tmp := NULL]
  
  out
}

find_col <- function(dt, possible_names, required = TRUE) {
  hit <- possible_names[possible_names %in% names(dt)]
  
  if (length(hit) > 0) {
    return(hit[1])
  }
  
  if (required) {
    stop(
      "Could not find any of these required columns:\n",
      paste(possible_names, collapse = "\n"),
      "\nAvailable columns:\n",
      paste(names(dt), collapse = "\n")
    )
  }
  
  NA_character_
}

# ============================================================
# 4. Validate Table 7A columns and find Base/Base row
# ============================================================

repricing_col <- find_col(
  table_7A,
  c("Repricing Scenario", "repricing_scenario", "Repricing")
)

stabilization_col <- find_col(
  table_7A,
  c("Stabilization Scenario", "stabilization_scenario", "Stabilization")
)

modeled_providers_col_7A <- find_col(
  table_7A,
  c("Modeled Providers", "providers_in_model", "Modeled providers")
)

net_impact_col_7A <- find_col(
  table_7A,
  c("Net Provider Impact ($B)", "total_net_provider_impact", "Net provider impact ($B)")
)

net_impact_pct_col_7A <- find_col(
  table_7A,
  c("Net Impact (% of NPR)", "net_impact_pct_of_total_npr", "Net impact, % of NPR")
)

negative_provider_col_7A <- find_col(
  table_7A,
  c("Negative-Impact Providers", "providers_negative_net_impact", "Negative Providers"),
  required = FALSE
)

large_negative_col_7A <- find_col(
  table_7A,
  c("Large Negative-Impact Providers", "providers_large_negative_net_impact", "Providers Below -5% NPR"),
  required = FALSE
)

table_7A[
  ,
  repricing_scenario_clean :=
    clean_text(get(repricing_col))
]

table_7A[
  ,
  stabilization_scenario_clean :=
    clean_text(get(stabilization_col))
]

cat("\nAvailable Table 7A scenario labels:\n")
print(
  table_7A[
    ,
    .(
      repricing_scenario = get(repricing_col),
      stabilization_scenario = get(stabilization_col),
      repricing_scenario_clean,
      stabilization_scenario_clean
    )
  ]
)

# First try flexible "base" matching.
basebase_row <- table_7A[
  stringr::str_detect(repricing_scenario_clean, "base") &
    stringr::str_detect(stabilization_scenario_clean, "base")
]

# If that fails, try exact middle row of a 3x3 matrix if 9 rows exist.
if (nrow(basebase_row) == 0 && nrow(table_7A) == 9) {
  warning(
    "Could not find explicit Base/Base labels. ",
    "Using row 5 of 9-row scenario matrix as Base/Base fallback."
  )
  basebase_row <- table_7A[5]
}

# If still no match, print rows and stop.
if (nrow(basebase_row) == 0) {
  cat("\nCould not find Base/Base row using flexible label matching.\n")
  cat("Available scenario rows are:\n")
  print(
    table_7A[
      ,
      .(
        repricing_scenario = get(repricing_col),
        stabilization_scenario = get(stabilization_col),
        net_provider_impact = get(net_impact_col_7A),
        net_impact_pct = get(net_impact_pct_col_7A)
      )
    ]
  )
  
  stop("Could not find Base/Base row in Table 7A. Check scenario labels printed above.")
}

basebase_row <- basebase_row[1]

cat("\nSelected Base/Base row:\n")
print(
  basebase_row[
    ,
    .(
      repricing_scenario = get(repricing_col),
      stabilization_scenario = get(stabilization_col),
      net_provider_impact = get(net_impact_col_7A),
      net_impact_pct = get(net_impact_pct_col_7A)
    )
  ]
)

# ============================================================
# 5. Validate Table 7B columns and extract group baseline rows
# ============================================================

provider_group_col_7B <- find_col(
  table_7B,
  c("Provider Group", "clean_provider_group", "provider_group")
)

providers_col_7B <- find_col(
  table_7B,
  c("Providers", "providers")
)

modeled_providers_col_7B <- find_col(
  table_7B,
  c("Modeled Providers", "providers_in_model", "modeled_providers")
)

npr_col_7B <- find_col(
  table_7B,
  c("Net Patient Revenue ($B)", "total_net_patient_revenue", "Net patient revenue ($B)")
)

net_impact_col_7B <- find_col(
  table_7B,
  c("Net Provider Impact ($B)", "total_net_provider_impact", "Net provider impact ($B)")
)

net_impact_pct_col_7B <- find_col(
  table_7B,
  c("Net Impact (% of NPR)", "net_impact_pct_of_total_npr", "Net impact, % of NPR")
)

negative_provider_col_7B <- find_col(
  table_7B,
  c("Negative-Impact Providers", "providers_negative_net_impact", "Negative Providers"),
  required = FALSE
)

large_negative_col_7B <- find_col(
  table_7B,
  c("Large Negative-Impact Providers", "providers_large_negative_net_impact", "Providers Below -5% NPR"),
  required = FALSE
)

rural_base_row <- table_7B[clean_text(get(provider_group_col_7B)) == clean_text("Rural / CAH / IHS")]

if (nrow(rural_base_row) == 0) {
  cat("\nAvailable Table 7B provider groups:\n")
  print(table_7B[, .(provider_group = get(provider_group_col_7B))])
  stop("Could not find Rural / CAH / IHS row in Table 7B.")
}

rural_base_row <- rural_base_row[1]

behavioral_base_group_row <- table_7B[
  clean_text(get(provider_group_col_7B)) == clean_text("Specialty / behavioral / rehab")
]

if (nrow(behavioral_base_group_row) == 0) {
  cat("\nAvailable Table 7B provider groups:\n")
  print(table_7B[, .(provider_group = get(provider_group_col_7B))])
  stop("Could not find Specialty / behavioral / rehab row in Table 7B.")
}

behavioral_base_group_row <- behavioral_base_group_row[1]

# ============================================================
# 6. Validate Table 7K and extract rural option rows
# ============================================================

required_7K_cols <- c(
  "Scenario",
  "Rural Providers",
  "Net Patient Revenue ($B)",
  "Original Rural Net Impact ($B)",
  "Added Rural Support ($B)",
  "Net Impact After Rural Support ($B)",
  "Net Impact After Rural Support (% of NPR)",
  "Median Rural Provider Impact (% of NPR)",
  "Rural Providers Below -5% NPR",
  "Rural Providers Below -10% NPR",
  "Negative Rural Providers",
  "Positive Rural Providers"
)

missing_7K <- setdiff(required_7K_cols, names(table_7K))

if (length(missing_7K) > 0) {
  stop(
    "Table 7K missing required columns:\n",
    paste(missing_7K, collapse = "\n")
  )
}

rural_preferred_row <- get_row(
  table_7K,
  "Scenario",
  "enhanced guarantee.*rural floor.*-1.5"
)

rural_current_row <- get_row(
  table_7K,
  "Scenario",
  "current rural access guarantee"
)

rural_enhanced_row <- get_row(
  table_7K,
  "Scenario",
  "enhanced rural access guarantee"
)

rural_high_row <- get_row(
  table_7K,
  "Scenario",
  "high rural access guarantee"
)

# ============================================================
# 7. Validate Table 7M and extract behavioral option rows
# ============================================================

required_7M_cols <- c(
  "Scenario",
  "Behavioral Providers",
  "Repricing Treatment",
  "Floor Treatment",
  "Net Patient Revenue ($B)",
  "Original Repricing Pressure ($B)",
  "Added Behavioral Support ($B)",
  "Net Behavioral Impact After Scenario ($B)",
  "Net Impact After Scenario (% of NPR)",
  "Median Behavioral Provider Impact (% of NPR)",
  "Providers Below -5% NPR",
  "Providers Below -10% NPR",
  "Negative Providers",
  "Positive Providers"
)

missing_7M <- setdiff(required_7M_cols, names(table_7M))

if (length(missing_7M) > 0) {
  stop(
    "Table 7M missing required columns:\n",
    paste(missing_7M, collapse = "\n")
  )
}

behavioral_preferred_row <- get_row(
  table_7M,
  "Scenario",
  "25% repricing pressure.*-5.0% npr floor"
)

behavioral_current_row <- get_row(
  table_7M,
  "Scenario",
  "current base/base treatment"
)

behavioral_reduced_row <- get_row(
  table_7M,
  "Scenario",
  "reduced behavioral exposure"
)

behavioral_minimal_row <- get_row(
  table_7M,
  "Scenario",
  "minimal behavioral exposure"
)

behavioral_floor_row <- get_row(
  table_7M,
  "Scenario",
  "behavioral essential-access floor"
)

# ============================================================
# 8. Build publication-facing Table 7G
# ============================================================

base_net_impact_b <- safe_numeric(basebase_row[[net_impact_col_7A]])
base_net_impact_pct <- safe_numeric(basebase_row[[net_impact_pct_col_7A]])

base_large_negative <- if (!is.na(large_negative_col_7A)) {
  as_count(basebase_row[[large_negative_col_7A]])
} else {
  NA_integer_
}

base_negative <- if (!is.na(negative_provider_col_7A)) {
  as_count(basebase_row[[negative_provider_col_7A]])
} else {
  NA_integer_
}

rural_baseline_below_minus_5 <- 10L
rural_baseline_below_minus_10 <- 0L

# These two are from current table_7K output and are stable from the rural scenario table.
# If you later change 13B, these values should still be read from Table 7K for preferred rows.
behavioral_baseline_below_minus_5 <- as_count(behavioral_current_row$`Providers Below -5% NPR`)
behavioral_baseline_below_minus_10 <- as_count(behavioral_current_row$`Providers Below -10% NPR`)

baseline_all <- data.table::data.table(
  `Policy Layer` = "Baseline provider-impact model",
  `Provider Group` = "All modeled providers",
  `Protection Design` = "Base/Base provider-impact model before added access-protection adjustments",
  `Permanent Component` = "None beyond existing model",
  `Temporary / Implementation Component` = "Existing bounded stabilization only",
  `Added Support ($B)` = 0.000,
  `Net Impact After Protection ($B)` = as_dollars_b(base_net_impact_b),
  `Net Impact After Protection (% NPR)` = as_pct(base_net_impact_pct),
  `Providers Below -5% NPR` = base_large_negative,
  `Providers Below -10% NPR` = NA_integer_,
  `Temporary or Permanent?` = "Baseline model",
  `Preferred Policy Status` = "Reference case",
  `Interpretation` = "Shows gross provider-side price-discipline effect before targeted rural and behavioral access adjustments."
)

rural_baseline <- data.table::data.table(
  `Policy Layer` = "Rural access baseline",
  `Provider Group` = "Rural / CAH / IHS",
  `Protection Design` = "Base/Base rural result before added rural access guarantee",
  `Permanent Component` = "None beyond existing model",
  `Temporary / Implementation Component` = "Existing bounded stabilization only",
  `Added Support ($B)` = 0.000,
  `Net Impact After Protection ($B)` =
    as_dollars_b(rural_preferred_row$`Original Rural Net Impact ($B)`),
  `Net Impact After Protection (% NPR)` =
    as_pct(rural_base_row[[net_impact_pct_col_7B]]),
  `Providers Below -5% NPR` = rural_baseline_below_minus_5,
  `Providers Below -10% NPR` = rural_baseline_below_minus_10,
  `Temporary or Permanent?` = "Baseline model",
  `Preferred Policy Status` = "Reference case",
  `Interpretation` = "Rural providers face a moderate aggregate hit and a small number of large negative-impact cases before added rural access protection."
)

rural_preferred <- data.table::data.table(
  `Policy Layer` = "Preferred rural access protection",
  `Provider Group` = "Rural / CAH / IHS",
  `Protection Design` = "Enhanced rural access guarantee plus implementation-period rural floor",
  `Permanent Component` = "2% of NPR, capped at $5M per rural provider",
  `Temporary / Implementation Component` = "Implementation floor: no qualifying rural provider below -1.5% NPR",
  `Added Support ($B)` =
    as_dollars_b(rural_preferred_row$`Added Rural Support ($B)`),
  `Net Impact After Protection ($B)` =
    as_dollars_b(rural_preferred_row$`Net Impact After Rural Support ($B)`),
  `Net Impact After Protection (% NPR)` =
    as_pct(rural_preferred_row$`Net Impact After Rural Support (% of NPR)`),
  `Providers Below -5% NPR` =
    as_count(rural_preferred_row$`Rural Providers Below -5% NPR`),
  `Providers Below -10% NPR` =
    as_count(rural_preferred_row$`Rural Providers Below -10% NPR`),
  `Temporary or Permanent?` = "Permanent access payment + temporary/reviewable floor",
  `Preferred Policy Status` = "Preferred rural option",
  `Interpretation` = "Protects rural access while remaining capped and formula-based; eliminates rural providers below -5% NPR in the model."
)

behavioral_baseline <- data.table::data.table(
  `Policy Layer` = "Behavioral institutional baseline",
  `Provider Group` = "Psychiatric / behavioral hospitals",
  `Protection Design` = "Current Base/Base behavioral treatment",
  `Permanent Component` = "None",
  `Temporary / Implementation Component` = "No behavioral-specific adjustment",
  `Added Support ($B)` = 0.000,
  `Net Impact After Protection ($B)` =
    as_dollars_b(behavioral_current_row$`Net Behavioral Impact After Scenario ($B)`),
  `Net Impact After Protection (% NPR)` =
    as_pct(behavioral_current_row$`Net Impact After Scenario (% of NPR)`),
  `Providers Below -5% NPR` =
    as_count(behavioral_current_row$`Providers Below -5% NPR`),
  `Providers Below -10% NPR` =
    as_count(behavioral_current_row$`Providers Below -10% NPR`),
  `Temporary or Permanent?` = "Baseline model",
  `Preferred Policy Status` = "Reference case",
  `Interpretation` = "Aggregate behavioral impact is small, but state/institutional psychiatric providers create severe provider-level outliers."
)

behavioral_preferred <- data.table::data.table(
  `Policy Layer` = "Preferred behavioral institutional treatment",
  `Provider Group` = "Psychiatric / behavioral hospitals",
  `Protection Design` = "Behavioral institutional repricing adjustment plus implementation floor",
  `Permanent Component` = "Assign 25% of standard modeled repricing pressure to qualifying behavioral institutions",
  `Temporary / Implementation Component` = "Implementation floor: no qualifying behavioral provider below -5% NPR",
  `Added Support ($B)` =
    as_dollars_b(behavioral_preferred_row$`Added Behavioral Support ($B)`),
  `Net Impact After Protection ($B)` =
    as_dollars_b(behavioral_preferred_row$`Net Behavioral Impact After Scenario ($B)`),
  `Net Impact After Protection (% NPR)` =
    as_pct(behavioral_preferred_row$`Net Impact After Scenario (% of NPR)`),
  `Providers Below -5% NPR` =
    as_count(behavioral_preferred_row$`Providers Below -5% NPR`),
  `Providers Below -10% NPR` =
    as_count(behavioral_preferred_row$`Providers Below -10% NPR`),
  `Temporary or Permanent?` = "Repricing adjustment + implementation floor",
  `Preferred Policy Status` = "Preferred behavioral option",
  `Interpretation` = "Treats institutional psychiatric providers as limited routine-market repricing targets and eliminates behavioral providers below -10% NPR."
)

# Combined preferred package is a summary, not a provider-level rerun.
combined_added_support <- as.numeric(rural_preferred$`Added Support ($B)`) +
  as.numeric(behavioral_preferred$`Added Support ($B)`)

combined_net_impact <- as.numeric(base_net_impact_b) + combined_added_support

# Approximate all-provider NPR from Base/Base:
# If Base/Base net impact is -11.30 and pct is -4.3%, implied NPR ≈ 262.8B.
basebase_pct_decimal <- as.numeric(base_net_impact_pct) / 100

if (!is.na(basebase_pct_decimal) && basebase_pct_decimal != 0) {
  implied_all_provider_npr_b <- as.numeric(base_net_impact_b) / basebase_pct_decimal
  combined_pct_npr <- combined_net_impact / implied_all_provider_npr_b * 100
} else {
  implied_all_provider_npr_b <- NA_real_
  combined_pct_npr <- NA_real_
}

combined_summary <- data.table::data.table(
  `Policy Layer` = "Preferred access-protection package",
  `Provider Group` = "Targeted rural and behavioral access providers",
  `Protection Design` = "Preferred rural access protection plus preferred behavioral institutional treatment",
  `Permanent Component` = "Rural: 2% NPR capped at $5M; Behavioral: 25% modeled repricing exposure",
  `Temporary / Implementation Component` = "Rural floor at -1.5% NPR; Behavioral floor at -5% NPR",
  `Added Support ($B)` =
    as_dollars_b(combined_added_support),
  `Net Impact After Protection ($B)` =
    as_dollars_b(combined_net_impact),
  `Net Impact After Protection (% NPR)` =
    as_pct(combined_pct_npr),
  `Providers Below -5% NPR` = NA_integer_,
  `Providers Below -10% NPR` = NA_integer_,
  `Temporary or Permanent?` = "Mixed: rural permanent; floors implementation-period/reviewable",
  `Preferred Policy Status` = "Recommended access-protection package",
  `Interpretation` = "Preserves the main provider price-discipline mechanism while protecting rural access and correcting behavioral institutional exposure outliers."
)

table_7G_access <- data.table::rbindlist(
  list(
    baseline_all,
    rural_baseline,
    rural_preferred,
    behavioral_baseline,
    behavioral_preferred,
    combined_summary
  ),
  fill = TRUE
)

# ============================================================
# 9. Create policy-options appendix table
# ============================================================

rural_options <- data.table::rbindlist(
  list(
    data.table::data.table(
      `Option Set` = "Rural access options",
      `Scenario` = rural_current_row$Scenario,
      `Added Support ($B)` = as_dollars_b(rural_current_row$`Added Rural Support ($B)`),
      `Net Impact ($B)` = as_dollars_b(rural_current_row$`Net Impact After Rural Support ($B)`),
      `Net Impact (% NPR)` = as_pct(rural_current_row$`Net Impact After Rural Support (% of NPR)`),
      `Providers Below -5% NPR` = as_count(rural_current_row$`Rural Providers Below -5% NPR`),
      `Providers Below -10% NPR` = as_count(rural_current_row$`Rural Providers Below -10% NPR`),
      `Preferred?` = "No - conservative option"
    ),
    data.table::data.table(
      `Option Set` = "Rural access options",
      `Scenario` = rural_enhanced_row$Scenario,
      `Added Support ($B)` = as_dollars_b(rural_enhanced_row$`Added Rural Support ($B)`),
      `Net Impact ($B)` = as_dollars_b(rural_enhanced_row$`Net Impact After Rural Support ($B)`),
      `Net Impact (% NPR)` = as_pct(rural_enhanced_row$`Net Impact After Rural Support (% of NPR)`),
      `Providers Below -5% NPR` = as_count(rural_enhanced_row$`Rural Providers Below -5% NPR`),
      `Providers Below -10% NPR` = as_count(rural_enhanced_row$`Rural Providers Below -10% NPR`),
      `Preferred?` = "Partial - preferred permanent guarantee only"
    ),
    data.table::data.table(
      `Option Set` = "Rural access options",
      `Scenario` = rural_preferred_row$Scenario,
      `Added Support ($B)` = as_dollars_b(rural_preferred_row$`Added Rural Support ($B)`),
      `Net Impact ($B)` = as_dollars_b(rural_preferred_row$`Net Impact After Rural Support ($B)`),
      `Net Impact (% NPR)` = as_pct(rural_preferred_row$`Net Impact After Rural Support (% of NPR)`),
      `Providers Below -5% NPR` = as_count(rural_preferred_row$`Rural Providers Below -5% NPR`),
      `Providers Below -10% NPR` = as_count(rural_preferred_row$`Rural Providers Below -10% NPR`),
      `Preferred?` = "Yes - preferred rural option"
    ),
    data.table::data.table(
      `Option Set` = "Rural access options",
      `Scenario` = rural_high_row$Scenario,
      `Added Support ($B)` = as_dollars_b(rural_high_row$`Added Rural Support ($B)`),
      `Net Impact ($B)` = as_dollars_b(rural_high_row$`Net Impact After Rural Support ($B)`),
      `Net Impact (% NPR)` = as_pct(rural_high_row$`Net Impact After Rural Support (% of NPR)`),
      `Providers Below -5% NPR` = as_count(rural_high_row$`Rural Providers Below -5% NPR`),
      `Providers Below -10% NPR` = as_count(rural_high_row$`Rural Providers Below -10% NPR`),
      `Preferred?` = "No - high-protection sensitivity"
    )
  ),
  fill = TRUE
)

behavioral_options <- data.table::rbindlist(
  list(
    data.table::data.table(
      `Option Set` = "Behavioral institutional options",
      `Scenario` = behavioral_current_row$Scenario,
      `Added Support ($B)` = as_dollars_b(behavioral_current_row$`Added Behavioral Support ($B)`),
      `Net Impact ($B)` = as_dollars_b(behavioral_current_row$`Net Behavioral Impact After Scenario ($B)`),
      `Net Impact (% NPR)` = as_pct(behavioral_current_row$`Net Impact After Scenario (% of NPR)`),
      `Providers Below -5% NPR` = as_count(behavioral_current_row$`Providers Below -5% NPR`),
      `Providers Below -10% NPR` = as_count(behavioral_current_row$`Providers Below -10% NPR`),
      `Preferred?` = "No - baseline"
    ),
    data.table::data.table(
      `Option Set` = "Behavioral institutional options",
      `Scenario` = behavioral_reduced_row$Scenario,
      `Added Support ($B)` = as_dollars_b(behavioral_reduced_row$`Added Behavioral Support ($B)`),
      `Net Impact ($B)` = as_dollars_b(behavioral_reduced_row$`Net Behavioral Impact After Scenario ($B)`),
      `Net Impact (% NPR)` = as_pct(behavioral_reduced_row$`Net Impact After Scenario (% of NPR)`),
      `Providers Below -5% NPR` = as_count(behavioral_reduced_row$`Providers Below -5% NPR`),
      `Providers Below -10% NPR` = as_count(behavioral_reduced_row$`Providers Below -10% NPR`),
      `Preferred?` = "No - moderate exposure adjustment"
    ),
    data.table::data.table(
      `Option Set` = "Behavioral institutional options",
      `Scenario` = behavioral_minimal_row$Scenario,
      `Added Support ($B)` = as_dollars_b(behavioral_minimal_row$`Added Behavioral Support ($B)`),
      `Net Impact ($B)` = as_dollars_b(behavioral_minimal_row$`Net Behavioral Impact After Scenario ($B)`),
      `Net Impact (% NPR)` = as_pct(behavioral_minimal_row$`Net Impact After Scenario (% of NPR)`),
      `Providers Below -5% NPR` = as_count(behavioral_minimal_row$`Providers Below -5% NPR`),
      `Providers Below -10% NPR` = as_count(behavioral_minimal_row$`Providers Below -10% NPR`),
      `Preferred?` = "Partial - exposure adjustment only"
    ),
    data.table::data.table(
      `Option Set` = "Behavioral institutional options",
      `Scenario` = behavioral_floor_row$Scenario,
      `Added Support ($B)` = as_dollars_b(behavioral_floor_row$`Added Behavioral Support ($B)`),
      `Net Impact ($B)` = as_dollars_b(behavioral_floor_row$`Net Behavioral Impact After Scenario ($B)`),
      `Net Impact (% NPR)` = as_pct(behavioral_floor_row$`Net Impact After Scenario (% of NPR)`),
      `Providers Below -5% NPR` = as_count(behavioral_floor_row$`Providers Below -5% NPR`),
      `Providers Below -10% NPR` = as_count(behavioral_floor_row$`Providers Below -10% NPR`),
      `Preferred?` = "No - floor without exposure correction"
    ),
    data.table::data.table(
      `Option Set` = "Behavioral institutional options",
      `Scenario` = behavioral_preferred_row$Scenario,
      `Added Support ($B)` = as_dollars_b(behavioral_preferred_row$`Added Behavioral Support ($B)`),
      `Net Impact ($B)` = as_dollars_b(behavioral_preferred_row$`Net Behavioral Impact After Scenario ($B)`),
      `Net Impact (% NPR)` = as_pct(behavioral_preferred_row$`Net Impact After Scenario (% of NPR)`),
      `Providers Below -5% NPR` = as_count(behavioral_preferred_row$`Providers Below -5% NPR`),
      `Providers Below -10% NPR` = as_count(behavioral_preferred_row$`Providers Below -10% NPR`),
      `Preferred?` = "Yes - preferred behavioral option"
    )
  ),
  fill = TRUE
)

table_7G_options_appendix <- data.table::rbindlist(
  list(
    rural_options,
    behavioral_options
  ),
  fill = TRUE
)

# ============================================================
# 10. Methodology / prose notes
# ============================================================

summary_notes <- c(
  "Table 7G Access-Protection Policy Summary Notes",
  "================================================",
  "",
  paste0("Build year: ", hcris_year_label),
  paste0("Generated: ", Sys.time()),
  "",
  "Purpose:",
  "This script creates a publication-facing summary of targeted access-protection options for UCC/HSE Table 7.",
  "It does not rebuild the provider-impact model.",
  "",
  "Core provider-impact model:",
  "Net Provider Impact = - Market Repricing Pressure + UC/Liquidity Offset + Bounded Stabilization Support.",
  "",
  "Preferred rural policy:",
  "Enhanced rural access guarantee plus implementation-period rural floor.",
  "Permanent component: 2% of NPR, capped at $5 million per rural provider.",
  "Implementation-period component: no qualifying rural / CAH / IHS provider below -1.5% of NPR.",
  paste0(
    "Model result: added rural support of $",
    rural_preferred_row$`Added Rural Support ($B)`,
    "B; rural net impact after support of $",
    rural_preferred_row$`Net Impact After Rural Support ($B)`,
    "B; rural impact of ",
    rural_preferred_row$`Net Impact After Rural Support (% of NPR)`,
    "% of NPR; rural providers below -5% NPR: ",
    rural_preferred_row$`Rural Providers Below -5% NPR`,
    "."
  ),
  "",
  "Preferred behavioral policy:",
  "Behavioral institutional repricing adjustment plus implementation-period floor.",
  "Structural modeling adjustment: qualifying psychiatric / behavioral institutions receive 25% of standard modeled repricing pressure.",
  "Implementation-period component: no qualifying psychiatric / behavioral provider below -5% of NPR.",
  paste0(
    "Model result: behavioral net impact after scenario of $",
    behavioral_preferred_row$`Net Behavioral Impact After Scenario ($B)`,
    "B; behavioral impact of ",
    behavioral_preferred_row$`Net Impact After Scenario (% of NPR)`,
    "% of NPR; providers below -10% NPR: ",
    behavioral_preferred_row$`Providers Below -10% NPR`,
    "."
  ),
  "",
  "Interpretive distinction:",
  "Rural protection is a permanent access-capacity payment because rural access vulnerability is structural.",
  "Behavioral protection is primarily a repricing-exposure adjustment because many institutional psychiatric providers are not ordinary consumer-directed routine outpatient price-shopping targets.",
  "",
  "Recommended table placement:",
  "Use Table 7G as the main access-protection policy summary.",
  "Move the full rural and behavioral sensitivity tables to appendix tables unless space allows."
)

formula_notes <- c(
  "Access-Protection Formula Notes",
  "===============================",
  "",
  "Core provider-impact equation:",
  "Net Provider Impact_i,s = - Market Repricing Pressure_i,s + UC/Liquidity Offset_i,s + Bounded Stabilization Support_i,s",
  "",
  "Preferred rural access protection:",
  "Preferred Rural Protection_i = Permanent Rural Access Guarantee_i + Rural Implementation Floor Support_i",
  "",
  "Permanent Rural Access Guarantee_i = min(0.02 x NPR_i, $5,000,000)",
  "",
  "Net Impact After Rural Guarantee_i = Net Provider Impact_i + Permanent Rural Access Guarantee_i",
  "",
  "Rural Implementation Floor Support_i = max(0, (-0.015 x NPR_i) - Net Impact After Rural Guarantee_i)",
  "",
  "Preferred Rural Adjusted Net Impact_i = Net Impact After Rural Guarantee_i + Rural Implementation Floor Support_i",
  "",
  "Preferred behavioral institutional treatment:",
  "Behavioral Adjusted Repricing Pressure_i = 0.25 x Market Repricing Pressure_i",
  "",
  "Behavioral Pre-Floor Net Impact_i = - Behavioral Adjusted Repricing Pressure_i + UC/Liquidity Offset_i + Bounded Stabilization Support_i",
  "",
  "Behavioral Floor Support_i = max(0, (-0.05 x NPR_i) - Behavioral Pre-Floor Net Impact_i)",
  "",
  "Preferred Behavioral Adjusted Net Impact_i = Behavioral Pre-Floor Net Impact_i + Behavioral Floor Support_i",
  "",
  "Policy distinction:",
  "Rural access guarantee is permanent, capped, and formula-based.",
  "Rural floor and behavioral floor are implementation-period or reviewable protections.",
  "Behavioral repricing adjustment is a structural exposure adjustment, not a general provider bailout."
)

# ============================================================
# 11. Save outputs
# ============================================================

table_7G_access_file <- file.path(
  table7_dir,
  "table_7G_access_protection_policy_options.csv"
)

table_7G_options_file <- file.path(
  table7_dir,
  "table_7G_access_protection_options_appendix.csv"
)

summary_notes_file <- file.path(
  table7_dir,
  "table_7_access_protection_summary_notes.txt"
)

formula_notes_file <- file.path(
  table7_dir,
  "table_7_access_protection_formula_notes.txt"
)

data.table::fwrite(table_7G_access, table_7G_access_file)
data.table::fwrite(table_7G_options_appendix, table_7G_options_file)
writeLines(summary_notes, summary_notes_file)
writeLines(formula_notes, formula_notes_file)

# Optional Excel workbook.
excel_file <- file.path(
  table7_dir,
  "table_7G_access_protection_policy_options.xlsx"
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
  
  add_sheet(wb, "Table 7G Summary", table_7G_access)
  add_sheet(wb, "Options Appendix", table_7G_options_appendix)
  
  openxlsx::addWorksheet(wb, "Summary Notes")
  openxlsx::writeData(
    wb,
    "Summary Notes",
    data.table::data.table(notes = summary_notes)
  )
  openxlsx::setColWidths(wb, "Summary Notes", cols = 1, widths = 120)
  
  openxlsx::addWorksheet(wb, "Formula Notes")
  openxlsx::writeData(
    wb,
    "Formula Notes",
    data.table::data.table(notes = formula_notes)
  )
  openxlsx::setColWidths(wb, "Formula Notes", cols = 1, widths = 120)
  
  openxlsx::saveWorkbook(wb, excel_file, overwrite = TRUE)
  excel_written <- TRUE
} else {
  warning(
    "Package openxlsx not installed. Excel workbook was not written. ",
    "CSV/TXT outputs were written."
  )
}

# ============================================================
# 12. Print summaries
# ============================================================

cat("\n============================================================\n")
cat("TABLE 7 ACCESS-PROTECTION SUMMARY COMPLETE\n")
cat("============================================================\n")

cat("\nTable 7G. Access-Protection Policy Options:\n")
print(table_7G_access)

cat("\nAccess-protection options appendix:\n")
print(table_7G_options_appendix)

cat("\nSaved:\n")
cat(table_7G_access_file, "\n")
cat(table_7G_options_file, "\n")
cat(summary_notes_file, "\n")
cat(formula_notes_file, "\n")

if (excel_written == TRUE) {
  cat(excel_file, "\n")
}

cat("\n============================================================\n")