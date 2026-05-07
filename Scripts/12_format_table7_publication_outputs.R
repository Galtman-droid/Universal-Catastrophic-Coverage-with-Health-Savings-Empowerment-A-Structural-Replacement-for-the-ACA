# Scripts/12_format_table7_publication_outputs.R
# Format corrected UCC/HSE provider-impact model outputs into publication-ready Table 7 files.
#
# Purpose:
#   This script does NOT rebuild the model.
#   It reads the already-corrected Script 11 / 11A outputs and exports clean,
#   publication-oriented Table 7 files.
#
# Required current model state:
#   - HCRIS FY2024 backbone providers: 912
#   - Modeled providers: corrected model should be approximately 886 / 912
#   - No model-used net-to-gross outliers > 1.50
#   - Corrected fallback method names should include:
#       nonstandard_g200000_l04300_fallback
#       nonstandard_fallback_failed_plausibility
#
# Inputs:
#   Output/hcris_YYYY_table_7A_provider_impact_3x3_matrix.csv
#   Output/hcris_YYYY_table_7B_provider_impact_by_clean_group_basebase.csv
#   Output/hcris_YYYY_table_7C_provider_impact_by_clean_class_basebase.csv
#   Output/hcris_YYYY_table_7D_provider_level_effect_distribution_basebase.csv
#   Output/hcris_YYYY_11A_model_inclusion_by_group_class.csv
#   Output/hcris_YYYY_11A_exposure_anomaly_audit.csv
#   Output/hcris_YYYY_provider_impact_basebase_provider_level.csv
#   Output/hcris_YYYY_provider_master_with_financials.csv
#
# Outputs:
#   Output/Table7_Publication/table_7A_publication.csv
#   Output/Table7_Publication/table_7B_publication.csv
#   Output/Table7_Publication/table_7C_publication.csv
#   Output/Table7_Publication/table_7D_publication.csv
#   Output/Table7_Publication/table_7E_model_coverage_audit.csv
#   Output/Table7_Publication/table_7F_exposure_anomaly_sensitivity.csv
#   Output/Table7_Publication/table_7_methodology_notes.txt
#   Output/Table7_Publication/table_7_data_state_freeze_summary.txt
#   Output/Table7_Publication/table_7_all_publication_tables.xlsx
#
# Optional Excel export:
#   Requires openxlsx. If missing, CSV/TXT outputs are still written.

source("Scripts/00_setup.R")

cat("\n============================================================\n")
cat("FORMAT TABLE 7 PUBLICATION OUTPUTS\n")
cat("============================================================\n")
cat("Build year:", hcris_year_label, "\n\n")

# ============================================================
# 0. Output folder
# ============================================================

table7_dir <- file.path(path_output, "Table7_Publication")

if (!dir.exists(table7_dir)) {
  dir.create(table7_dir, recursive = TRUE)
}

cat("Publication output folder:\n")
cat(table7_dir, "\n\n")

# ============================================================
# 1. Input file paths
# ============================================================

table_7A_file <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_table_7A_provider_impact_3x3_matrix.csv")
)

table_7B_file <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_table_7B_provider_impact_by_clean_group_basebase.csv")
)

table_7C_file <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_table_7C_provider_impact_by_clean_class_basebase.csv")
)

table_7D_file <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_table_7D_provider_level_effect_distribution_basebase.csv")
)

inclusion_file <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_11A_model_inclusion_by_group_class.csv")
)

exposure_anomaly_file <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_11A_exposure_anomaly_audit.csv")
)

basebase_provider_file <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_provider_impact_basebase_provider_level.csv")
)

provider_financials_file <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_provider_master_with_financials.csv")
)

required_files <- c(
  table_7A_file,
  table_7B_file,
  table_7C_file,
  table_7D_file,
  inclusion_file,
  exposure_anomaly_file,
  basebase_provider_file,
  provider_financials_file
)

missing_files <- required_files[!file.exists(required_files)]

if (length(missing_files) > 0) {
  stop(
    "Missing required input files. Rerun Scripts 08, 09, 10, 11, and 11A first:\n",
    paste(missing_files, collapse = "\n")
  )
}

# ============================================================
# 2. Read inputs
# ============================================================

table_7A_raw <- data.table::fread(table_7A_file)
table_7B_raw <- data.table::fread(table_7B_file)
table_7C_raw <- data.table::fread(table_7C_file)
table_7D_raw <- data.table::fread(table_7D_file)
inclusion_raw <- data.table::fread(inclusion_file)
exposure_anomaly_raw <- data.table::fread(exposure_anomaly_file)
basebase_provider_raw <- data.table::fread(basebase_provider_file)
provider_financials_raw <- data.table::fread(provider_financials_file)

cat("Loaded input rows:\n")
cat("Table 7A:", nrow(table_7A_raw), "\n")
cat("Table 7B:", nrow(table_7B_raw), "\n")
cat("Table 7C:", nrow(table_7C_raw), "\n")
cat("Table 7D:", nrow(table_7D_raw), "\n")
cat("Inclusion audit:", nrow(inclusion_raw), "\n")
cat("Exposure anomaly audit:", nrow(exposure_anomaly_raw), "\n")
cat("Base/base provider-level:", nrow(basebase_provider_raw), "\n")
cat("Provider financials:", nrow(provider_financials_raw), "\n\n")

# ============================================================
# 3. Helper functions
# ============================================================

billion <- function(x) {
  round(as.numeric(x) / 1e9, 2)
}

million <- function(x) {
  round(as.numeric(x) / 1e6, 1)
}

pct1 <- function(x) {
  round(as.numeric(x) * 100, 1)
}

pct2 <- function(x) {
  round(as.numeric(x) * 100, 2)
}

num0 <- function(x) {
  as.integer(round(as.numeric(x), 0))
}

num1 <- function(x) {
  round(as.numeric(x), 1)
}

num2 <- function(x) {
  round(as.numeric(x), 2)
}

safe_sum <- function(x) {
  sum(as.numeric(x), na.rm = TRUE)
}

safe_div <- function(num, den) {
  ifelse(!is.na(den) & den != 0, num / den, NA_real_)
}

# ============================================================
# 4. Safety checks on corrected model state
# ============================================================

if (!"revenue_source_method" %in% names(provider_financials_raw)) {
  stop("provider_financials_raw missing revenue_source_method")
}

if (!"revenue_use_for_model_flag" %in% names(provider_financials_raw)) {
  stop("provider_financials_raw missing revenue_use_for_model_flag")
}

if (!"provider_backbone_include_v1" %in% names(provider_financials_raw)) {
  stop("provider_financials_raw missing provider_backbone_include_v1")
}

provider_financials_raw[
  ,
  revenue_use_for_model_flag := as.logical(revenue_use_for_model_flag)
]

provider_financials_raw[
  ,
  provider_backbone_include_v1 := as.logical(provider_backbone_include_v1)
]

# Confirm corrected fallback naming exists.
source_methods <- sort(unique(provider_financials_raw$revenue_source_method))

old_specialty_method_present <- "specialty_g200000_l04300_fallback" %in% source_methods
corrected_nonstandard_method_present <- "nonstandard_g200000_l04300_fallback" %in% source_methods
failed_plausibility_method_present <- "nonstandard_fallback_failed_plausibility" %in% source_methods

if (old_specialty_method_present) {
  warning(
    "Old fallback name 'specialty_g200000_l04300_fallback' is present. ",
    "This suggests the old Script 8 may have been used. Confirm before publication."
  )
}

if (!corrected_nonstandard_method_present) {
  warning(
    "Corrected fallback name 'nonstandard_g200000_l04300_fallback' was not found. ",
    "Confirm that corrected Script 8 was run."
  )
}

# Model-used net-to-gross outlier check.
model_used_net_to_gross_outliers <- provider_financials_raw[
  provider_backbone_include_v1 == TRUE &
    revenue_use_for_model_flag == TRUE &
    !is.na(net_to_gross_ratio) &
    (net_to_gross_ratio <= 0 | net_to_gross_ratio > 1.50)
]

if (nrow(model_used_net_to_gross_outliers) > 0) {
  warning(
    "There are model-used net-to-gross outliers <=0 or >1.50. ",
    "Do not treat Table 7 as final until these are resolved."
  )
}

# ============================================================
# 5. Table 7A publication formatting
# ============================================================

required_7A_cols <- c(
  "repricing_scenario",
  "stabilization_scenario",
  "providers_in_model",
  "total_outpatient_exposure_used",
  "total_outpatient_repricing_pressure",
  "total_uncompensated_care_offset",
  "total_stabilization_support",
  "total_net_provider_impact",
  "net_impact_pct_of_total_npr",
  "providers_negative_net_impact",
  "providers_large_negative_net_impact",
  "median_provider_impact_pct_of_npr"
)

missing_7A <- setdiff(required_7A_cols, names(table_7A_raw))
if (length(missing_7A) > 0) {
  stop("Table 7A raw file missing columns:\n", paste(missing_7A, collapse = "\n"))
}

table_7A_pub <- table_7A_raw[
  ,
  .(
    `Repricing Scenario` = repricing_scenario,
    `Stabilization Scenario` = stabilization_scenario,
    `Modeled Providers` = num0(providers_in_model),
    `Outpatient/Routine Exposure ($B)` = billion(total_outpatient_exposure_used),
    `Repricing Pressure ($B)` = billion(total_outpatient_repricing_pressure),
    `UC / Liquidity Offset ($B)` = billion(total_uncompensated_care_offset),
    `Stabilization Support ($B)` = billion(total_stabilization_support),
    `Net Provider Impact ($B)` = billion(total_net_provider_impact),
    `Net Impact (% of NPR)` = pct1(net_impact_pct_of_total_npr),
    `Negative-Impact Providers` = num0(providers_negative_net_impact),
    `Large Negative-Impact Providers` = num0(providers_large_negative_net_impact),
    `Median Provider Impact (% of NPR)` = pct1(median_provider_impact_pct_of_npr)
  )
]

# ============================================================
# 6. Table 7B publication formatting
# ============================================================

required_7B_cols <- c(
  "clean_provider_group",
  "providers",
  "providers_in_model",
  "total_net_patient_revenue",
  "total_outpatient_exposure_used",
  "total_outpatient_repricing_pressure",
  "total_uncompensated_care_offset",
  "total_stabilization_support",
  "total_net_provider_impact",
  "net_impact_pct_of_total_npr",
  "providers_negative_net_impact",
  "providers_large_negative_net_impact",
  "stabilization_eligible"
)

missing_7B <- setdiff(required_7B_cols, names(table_7B_raw))
if (length(missing_7B) > 0) {
  stop("Table 7B raw file missing columns:\n", paste(missing_7B, collapse = "\n"))
}

table_7B_pub <- table_7B_raw[
  ,
  .(
    `Provider Group` = clean_provider_group,
    `Providers` = num0(providers),
    `Modeled Providers` = num0(providers_in_model),
    `Net Patient Revenue ($B)` = billion(total_net_patient_revenue),
    `Outpatient/Routine Exposure ($B)` = billion(total_outpatient_exposure_used),
    `Repricing Pressure ($B)` = billion(total_outpatient_repricing_pressure),
    `UC / Liquidity Offset ($B)` = billion(total_uncompensated_care_offset),
    `Stabilization Support ($B)` = billion(total_stabilization_support),
    `Net Provider Impact ($B)` = billion(total_net_provider_impact),
    `Net Impact (% of NPR)` = pct1(net_impact_pct_of_total_npr),
    `Negative-Impact Providers` = num0(providers_negative_net_impact),
    `Large Negative-Impact Providers` = num0(providers_large_negative_net_impact),
    `Stabilization-Eligible Providers` = num0(stabilization_eligible)
  )
][order(`Provider Group`)]

# ============================================================
# 7. Table 7C publication formatting
# ============================================================

required_7C_cols <- c(
  "clean_provider_group",
  "clean_provider_model_class",
  "providers",
  "providers_in_model",
  "total_net_patient_revenue",
  "total_outpatient_exposure_used",
  "total_outpatient_repricing_pressure",
  "total_uncompensated_care_offset",
  "total_stabilization_support",
  "total_net_provider_impact",
  "net_impact_pct_of_total_npr",
  "providers_negative_net_impact",
  "providers_large_negative_net_impact",
  "stabilization_eligible"
)

missing_7C <- setdiff(required_7C_cols, names(table_7C_raw))
if (length(missing_7C) > 0) {
  stop("Table 7C raw file missing columns:\n", paste(missing_7C, collapse = "\n"))
}

table_7C_pub <- table_7C_raw[
  ,
  .(
    `Provider Group` = clean_provider_group,
    `Provider Class` = clean_provider_model_class,
    `Providers` = num0(providers),
    `Modeled Providers` = num0(providers_in_model),
    `Net Patient Revenue ($B)` = billion(total_net_patient_revenue),
    `Outpatient/Routine Exposure ($B)` = billion(total_outpatient_exposure_used),
    `Repricing Pressure ($B)` = billion(total_outpatient_repricing_pressure),
    `UC / Liquidity Offset ($B)` = billion(total_uncompensated_care_offset),
    `Stabilization Support ($B)` = billion(total_stabilization_support),
    `Net Provider Impact ($B)` = billion(total_net_provider_impact),
    `Net Impact (% of NPR)` = pct1(net_impact_pct_of_total_npr),
    `Negative-Impact Providers` = num0(providers_negative_net_impact),
    `Large Negative-Impact Providers` = num0(providers_large_negative_net_impact),
    `Stabilization-Eligible Providers` = num0(stabilization_eligible)
  )
][order(`Provider Group`, `Provider Class`)]

# ============================================================
# 8. Table 7D publication formatting
# ============================================================

required_7D_cols <- c(
  "clean_provider_group",
  "provider_impact_pct_bucket",
  "providers",
  "total_net_patient_revenue",
  "total_net_provider_impact",
  "median_provider_impact_pct_of_npr"
)

missing_7D <- setdiff(required_7D_cols, names(table_7D_raw))
if (length(missing_7D) > 0) {
  stop("Table 7D raw file missing columns:\n", paste(missing_7D, collapse = "\n"))
}

table_7D_pub <- table_7D_raw[
  ,
  .(
    `Provider Group` = clean_provider_group,
    `Provider Impact Bucket (% of NPR)` = as.character(provider_impact_pct_bucket),
    `Providers` = num0(providers),
    `Net Patient Revenue ($B)` = billion(total_net_patient_revenue),
    `Net Provider Impact ($B)` = billion(total_net_provider_impact),
    `Median Provider Impact (% of NPR)` = pct1(median_provider_impact_pct_of_npr)
  )
][order(`Provider Group`, `Provider Impact Bucket (% of NPR)`)]

# ============================================================
# 9. Table 7E — Model coverage and data quality audit
# ============================================================

provider_fin_backbone <- provider_financials_raw[provider_backbone_include_v1 == TRUE]

backbone_providers <- nrow(provider_fin_backbone)
modeled_providers <- provider_fin_backbone[revenue_use_for_model_flag == TRUE, .N]
excluded_providers <- provider_fin_backbone[revenue_use_for_model_flag == FALSE, .N]
modeled_share <- safe_div(modeled_providers, backbone_providers)

source_method_counts <- provider_fin_backbone[
  ,
  .(providers = .N),
  by = revenue_source_method
]

get_method_count <- function(method_name) {
  val <- source_method_counts[revenue_source_method == method_name, providers]
  if (length(val) == 0) return(0L)
  as.integer(val[1])
}

standard_g2_split_records <- get_method_count("standard_g2_l028_split")
rural_fallback_records <- get_method_count("rural_g200000_l04300_fallback")
children_fallback_records <- get_method_count("children_total_only_fallback")
nonstandard_fallback_records <- get_method_count("nonstandard_g200000_l04300_fallback")
failed_plausibility_records <- get_method_count("nonstandard_fallback_failed_plausibility")
g2_total_only_records <- get_method_count("g2_total_only_no_outpatient_split")
missing_unusable_records <- get_method_count("missing_or_unusable")
old_specialty_fallback_records <- get_method_count("specialty_g200000_l04300_fallback")

model_used_net_to_gross_outlier_count <- nrow(model_used_net_to_gross_outliers)

exposure_anomaly_count <- nrow(exposure_anomaly_raw)

# If the anomaly file includes revenue/model flags, create a more specific count.
if (all(c("revenue_use_for_model_flag", "exposure_anomaly_flag") %in% names(exposure_anomaly_raw))) {
  exposure_anomaly_modeled_count <- exposure_anomaly_raw[
    as.logical(revenue_use_for_model_flag) == TRUE,
    .N
  ]
} else {
  exposure_anomaly_modeled_count <- exposure_anomaly_count
}

# Inclusion by clean group directly from base/base provider file.
if (!all(c("clean_provider_group", "provider_impact_model_include_flag") %in% names(basebase_provider_raw))) {
  stop("Base/base provider-level file missing clean_provider_group or provider_impact_model_include_flag")
}

basebase_provider_raw[
  ,
  provider_impact_model_include_flag := as.logical(provider_impact_model_include_flag)
]

coverage_by_group <- basebase_provider_raw[
  ,
  .(
    backbone_providers = .N,
    modeled_providers = sum(provider_impact_model_include_flag, na.rm = TRUE),
    excluded_providers = sum(!provider_impact_model_include_flag, na.rm = TRUE)
  ),
  by = clean_provider_group
][
  ,
  modeled_share := safe_div(modeled_providers, backbone_providers)
][order(clean_provider_group)]

table_7E_overall <- data.table::data.table(
  `Audit Item` = c(
    "Backbone providers",
    "Modeled providers",
    "Excluded providers",
    "Modeled share",
    "Standard G-2 split records",
    "Rural fallback records",
    "Children's fallback records",
    "Nonstandard fallback records",
    "Nonstandard fallback failed plausibility records",
    "G-2 total-only / no outpatient split records",
    "Missing or unusable records",
    "Old specialty fallback records present",
    "Model-used net-to-gross outliers <=0 or >1.50",
    "Exposure anomaly records",
    "Modeled exposure anomaly records"
  ),
  `Value` = c(
    as.character(backbone_providers),
    as.character(modeled_providers),
    as.character(excluded_providers),
    paste0(pct1(modeled_share), "%"),
    as.character(standard_g2_split_records),
    as.character(rural_fallback_records),
    as.character(children_fallback_records),
    as.character(nonstandard_fallback_records),
    as.character(failed_plausibility_records),
    as.character(g2_total_only_records),
    as.character(missing_unusable_records),
    as.character(old_specialty_fallback_records),
    as.character(model_used_net_to_gross_outlier_count),
    as.character(exposure_anomaly_count),
    as.character(exposure_anomaly_modeled_count)
  )
)

table_7E_group <- coverage_by_group[
  ,
  .(
    `Provider Group` = clean_provider_group,
    `Backbone Providers` = num0(backbone_providers),
    `Modeled Providers` = num0(modeled_providers),
    `Excluded Providers` = num0(excluded_providers),
    `Modeled Share (%)` = pct1(modeled_share)
  )
]

# A long combined audit table for CSV readability.
table_7E_pub <- data.table::rbindlist(
  list(
    data.table::data.table(
      `Section` = "Overall data-state audit",
      `Metric` = table_7E_overall$`Audit Item`,
      `Value` = table_7E_overall$Value
    ),
    data.table::data.table(
      `Section` = "Coverage by clean provider group",
      `Metric` = table_7E_group$`Provider Group`,
      `Value` = paste0(
        table_7E_group$`Modeled Providers`,
        " / ",
        table_7E_group$`Backbone Providers`,
        " modeled (",
        table_7E_group$`Modeled Share (%)`,
        "%)"
      )
    )
  ),
  fill = TRUE
)

# ============================================================
# 10. Table 7F — exposure anomaly sensitivity
# ============================================================

# This is not the main table. It is a sensitivity / appendix export showing
# whether flagged OP exposure anomalies materially change the Base/Base totals.

basebase <- copy(basebase_provider_raw)

needed_sensitivity_cols <- c(
  "provider_impact_model_include_flag",
  "rpt_rec_num",
  "net_patient_revenue_model",
  "outpatient_exposure_used",
  "outpatient_repricing_pressure",
  "uncompensated_care_offset",
  "stabilization_support",
  "net_provider_impact",
  "net_provider_impact_pct_of_npr"
)

missing_sens <- setdiff(needed_sensitivity_cols, names(basebase))
if (length(missing_sens) > 0) {
  stop("Base/base file missing sensitivity columns:\n", paste(missing_sens, collapse = "\n"))
}

# Identify anomaly report IDs from 11A.
if ("rpt_rec_num" %in% names(exposure_anomaly_raw)) {
  anomaly_ids <- unique(exposure_anomaly_raw$rpt_rec_num)
} else {
  anomaly_ids <- integer(0)
}

basebase[
  ,
  exposure_anomaly_from_11A_flag := rpt_rec_num %in% anomaly_ids
]

make_sensitivity_row <- function(dt, label) {
  dt_model <- dt[provider_impact_model_include_flag == TRUE]
  data.table::data.table(
    `Sensitivity Case` = label,
    `Modeled Providers` = nrow(dt_model),
    `Net Patient Revenue ($B)` = billion(safe_sum(dt_model$net_patient_revenue_model)),
    `Outpatient/Routine Exposure ($B)` = billion(safe_sum(dt_model$outpatient_exposure_used)),
    `Repricing Pressure ($B)` = billion(safe_sum(dt_model$outpatient_repricing_pressure)),
    `UC / Liquidity Offset ($B)` = billion(safe_sum(dt_model$uncompensated_care_offset)),
    `Stabilization Support ($B)` = billion(safe_sum(dt_model$stabilization_support)),
    `Net Provider Impact ($B)` = billion(safe_sum(dt_model$net_provider_impact)),
    `Net Impact (% of NPR)` = pct1(
      safe_div(
        safe_sum(dt_model$net_provider_impact),
        safe_sum(dt_model$net_patient_revenue_model)
      )
    ),
    `Median Provider Impact (% of NPR)` = pct1(median(dt_model$net_provider_impact_pct_of_npr, na.rm = TRUE))
  )
}

table_7F_pub <- data.table::rbindlist(
  list(
    make_sensitivity_row(basebase, "Base/Base - all modeled providers"),
    make_sensitivity_row(basebase[exposure_anomaly_from_11A_flag == FALSE], "Base/Base - excluding 11A exposure anomalies")
  ),
  fill = TRUE
)

# ============================================================
# 11. Methodology notes
# ============================================================

methodology_notes <- c(
  "Table 7 methodology notes",
  "========================",
  "",
  paste0("Build year: ", hcris_year_label),
  paste0("Generated: ", Sys.time()),
  "",
  "Provider impact was estimated using FY2024 HCRIS hospital cost-report data.",
  "The model uses Worksheet G-2 and G-3 revenue fields to identify net patient revenue and outpatient/routine-care exposure.",
  "Standard acute hospitals were modeled using direct inpatient/outpatient revenue splits where available.",
  "For rural primary care, pediatric, and nonstandard specialty/behavioral/rehab-like records without validated outpatient splits, the model applies bounded fallback exposure assumptions.",
  "Providers were reclassified into cleaned analytical groups before scoring to avoid treating raw CAH-labeled records as true critical access hospitals when internal size, revenue, or name-based screens indicated academic, psychiatric, specialty, or other non-CAH status.",
  "Stabilization support is modeled as temporary, bounded transition protection based on cleaned provider class and uncompensated-care burden.",
  "Provisional operating-margin fields are retained for diagnostics but are not used to assign stabilization tiers.",
  "",
  "Core formula:",
  "Net Provider Impact = - Outpatient Repricing Pressure + UC/Liquidity Offset + Bounded Stabilization Support",
  "",
  "Definitions:",
  "Outpatient Repricing Pressure = outpatient/routine exposure x repricing scenario rate.",
  "UC/Liquidity Offset = S-10 uncompensated-care cost x scenario offset rate.",
  "Bounded Stabilization Support = bounded stabilization cap x stabilization scenario multiplier.",
  "",
  "Fallback exposure assumptions used by upstream Script 08:",
  "Rural fallback outpatient exposure share: low 20%, base 30%, high 40%.",
  "Children's fallback outpatient exposure share: low 30%, base 45%, high 60%.",
  "Nonstandard fallback outpatient exposure share: low 5%, base 10%, high 15%.",
  "",
  "Data-state checks from this export:",
  paste0("Backbone providers: ", backbone_providers),
  paste0("Modeled providers: ", modeled_providers),
  paste0("Excluded providers: ", excluded_providers),
  paste0("Modeled share: ", pct1(modeled_share), "%"),
  paste0("Standard G-2 split records: ", standard_g2_split_records),
  paste0("Rural fallback records: ", rural_fallback_records),
  paste0("Children's fallback records: ", children_fallback_records),
  paste0("Nonstandard fallback records: ", nonstandard_fallback_records),
  paste0("Nonstandard fallback failed plausibility records: ", failed_plausibility_records),
  paste0("Model-used net-to-gross outliers <=0 or >1.50: ", model_used_net_to_gross_outlier_count),
  paste0("Exposure anomaly records from 11A: ", exposure_anomaly_count),
  "",
  "Publication note:",
  "Table 7A-7C should use all modeled providers. Table 7F provides a sensitivity excluding exposure-anomaly records identified in the 11A audit."
)

freeze_summary <- c(
  "Table 7 data-state freeze summary",
  "=================================",
  "",
  paste0("Build year: ", hcris_year_label),
  paste0("Generated: ", Sys.time()),
  "",
  paste0("Backbone providers: ", backbone_providers),
  paste0("Modeled providers: ", modeled_providers),
  paste0("Excluded providers: ", excluded_providers),
  paste0("Modeled share: ", pct1(modeled_share), "%"),
  "",
  "Coverage by clean provider group:",
  paste0(
    table_7E_group$`Provider Group`,
    ": ",
    table_7E_group$`Modeled Providers`,
    " / ",
    table_7E_group$`Backbone Providers`,
    " modeled (",
    table_7E_group$`Modeled Share (%)`,
    "%)"
  ),
  "",
  "Revenue source method counts:",
  paste0(source_method_counts$revenue_source_method, ": ", source_method_counts$providers),
  "",
  paste0("Old specialty fallback method present: ", old_specialty_method_present),
  paste0("Corrected nonstandard fallback method present: ", corrected_nonstandard_method_present),
  paste0("Failed-plausibility method present: ", failed_plausibility_method_present),
  paste0("Model-used net-to-gross outliers <=0 or >1.50: ", model_used_net_to_gross_outlier_count),
  paste0("Exposure anomaly records from 11A: ", exposure_anomaly_count)
)

# ============================================================
# 12. Save publication outputs
# ============================================================

table_7A_pub_file <- file.path(table7_dir, "table_7A_publication.csv")
table_7B_pub_file <- file.path(table7_dir, "table_7B_publication.csv")
table_7C_pub_file <- file.path(table7_dir, "table_7C_publication.csv")
table_7D_pub_file <- file.path(table7_dir, "table_7D_publication.csv")
table_7E_pub_file <- file.path(table7_dir, "table_7E_model_coverage_audit.csv")
table_7E_group_file <- file.path(table7_dir, "table_7E_coverage_by_provider_group.csv")
table_7F_pub_file <- file.path(table7_dir, "table_7F_exposure_anomaly_sensitivity.csv")
methodology_file <- file.path(table7_dir, "table_7_methodology_notes.txt")
freeze_file <- file.path(table7_dir, "table_7_data_state_freeze_summary.txt")

# Add table-title rows in separate title metadata file for clarity.
table_titles <- data.table::data.table(
  table_id = c("Table 7A", "Table 7B", "Table 7C", "Table 7D", "Table 7E", "Table 7F"),
  title = c(
    "Provider Impact 3x3 Scenario Matrix",
    "Provider Impact by Provider Group under Base/Base Scenario",
    "Provider Impact by Provider Class under Base/Base Scenario",
    "Distribution of Provider-Level Effects under Base/Base Scenario",
    "Provider-Impact Model Coverage and Data Quality Audit",
    "Exposure-Anomaly Sensitivity under Base/Base Scenario"
  )
)

table_titles_file <- file.path(table7_dir, "table_7_titles.csv")

data.table::fwrite(table_7A_pub, table_7A_pub_file)
data.table::fwrite(table_7B_pub, table_7B_pub_file)
data.table::fwrite(table_7C_pub, table_7C_pub_file)
data.table::fwrite(table_7D_pub, table_7D_pub_file)
data.table::fwrite(table_7E_pub, table_7E_pub_file)
data.table::fwrite(table_7E_group, table_7E_group_file)
data.table::fwrite(table_7F_pub, table_7F_pub_file)
data.table::fwrite(table_titles, table_titles_file)
writeLines(methodology_notes, methodology_file)
writeLines(freeze_summary, freeze_file)

# ============================================================
# 13. Optional combined Excel workbook
# ============================================================

excel_file <- file.path(table7_dir, "table_7_all_publication_tables.xlsx")

if (requireNamespace("openxlsx", quietly = TRUE)) {
  wb <- openxlsx::createWorkbook()
  
  add_sheet <- function(wb, sheet_name, dt) {
    openxlsx::addWorksheet(wb, sheet_name)
    openxlsx::writeData(wb, sheet_name, dt)
    openxlsx::freezePane(wb, sheet_name, firstRow = TRUE)
    openxlsx::setColWidths(wb, sheet_name, cols = 1:ncol(dt), widths = "auto")
  }
  
  add_sheet(wb, "Table 7A", table_7A_pub)
  add_sheet(wb, "Table 7B", table_7B_pub)
  add_sheet(wb, "Table 7C", table_7C_pub)
  add_sheet(wb, "Table 7D", table_7D_pub)
  add_sheet(wb, "Table 7E Audit", table_7E_pub)
  add_sheet(wb, "Table 7E Coverage", table_7E_group)
  add_sheet(wb, "Table 7F Sensitivity", table_7F_pub)
  add_sheet(wb, "Titles", table_titles)
  
  openxlsx::addWorksheet(wb, "Methodology Notes")
  openxlsx::writeData(wb, "Methodology Notes", data.table::data.table(notes = methodology_notes))
  openxlsx::setColWidths(wb, "Methodology Notes", cols = 1, widths = 120)
  
  openxlsx::addWorksheet(wb, "Freeze Summary")
  openxlsx::writeData(wb, "Freeze Summary", data.table::data.table(summary = freeze_summary))
  openxlsx::setColWidths(wb, "Freeze Summary", cols = 1, widths = 120)
  
  openxlsx::saveWorkbook(wb, excel_file, overwrite = TRUE)
  excel_written <- TRUE
} else {
  warning("Package openxlsx not installed. Excel workbook was not written. CSV/TXT outputs were written.")
  excel_written <- FALSE
}

# ============================================================
# 14. Print summaries
# ============================================================

cat("\n============================================================\n")
cat("TABLE 7 PUBLICATION OUTPUTS COMPLETE\n")
cat("============================================================\n")

cat("\nCorrected model-state checks:\n")
cat("Backbone providers:", backbone_providers, "\n")
cat("Modeled providers:", modeled_providers, "\n")
cat("Excluded providers:", excluded_providers, "\n")
cat("Modeled share:", pct1(modeled_share), "%\n")
cat("Old specialty fallback records:", old_specialty_fallback_records, "\n")
cat("Corrected nonstandard fallback records:", nonstandard_fallback_records, "\n")
cat("Nonstandard fallback failed plausibility records:", failed_plausibility_records, "\n")
cat("Model-used net-to-gross outliers <=0 or >1.50:", model_used_net_to_gross_outlier_count, "\n")
cat("Exposure anomaly records from 11A:", exposure_anomaly_count, "\n")

cat("\nCoverage by clean provider group:\n")
print(table_7E_group)

cat("\nTable 7A publication preview:\n")
print(table_7A_pub)

cat("\nTable 7B publication preview:\n")
print(table_7B_pub)

cat("\nTable 7E audit preview:\n")
print(table_7E_pub)

cat("\nTable 7F exposure-anomaly sensitivity preview:\n")
print(table_7F_pub)

cat("\nSaved:\n")
cat(table_7A_pub_file, "\n")
cat(table_7B_pub_file, "\n")
cat(table_7C_pub_file, "\n")
cat(table_7D_pub_file, "\n")
cat(table_7E_pub_file, "\n")
cat(table_7E_group_file, "\n")
cat(table_7F_pub_file, "\n")
cat(table_titles_file, "\n")
cat(methodology_file, "\n")
cat(freeze_file, "\n")

if (excel_written == TRUE) {
  cat(excel_file, "\n")
}

cat("\n============================================================\n")
