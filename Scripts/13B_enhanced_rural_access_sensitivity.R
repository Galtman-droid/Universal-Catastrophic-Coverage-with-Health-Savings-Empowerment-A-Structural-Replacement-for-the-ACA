# Scripts/13B_enhanced_rural_access_sensitivity.R
# Enhanced Rural Access Guarantee sensitivity for UCC/HSE Table 7.
#
# Purpose:
#   This script does NOT rebuild the baseline provider-impact model.
#   It reads the corrected Base/Base provider-level output from Script 11
#   and tests stronger rural protection options.
#
# Inputs:
#   Output/hcris_YYYY_provider_impact_basebase_provider_level.csv
#
# Outputs:
#   Output/Table7_Publication/table_7K_enhanced_rural_access_sensitivity.csv
#   Output/Table7_Publication/table_7L_rural_provider_level_enhanced_access.csv
#   Output/Table7_Publication/table_7_enhanced_rural_access_methodology_notes.txt
#
# Policy distinction:
#   General transition stabilization can sunset.
#   Rural access support should not automatically sunset because rural access is
#   a structural access-capacity problem, not only a transition problem.

source("Scripts/00_setup.R")

cat("\n============================================================\n")
cat("CREATE ENHANCED RURAL ACCESS GUARANTEE SENSITIVITY\n")
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
# 3. Rural sensitivity assumptions
# ============================================================

large_negative_threshold <- -0.05
severe_negative_threshold <- -0.10

# Current modest rural access guarantee from Script 13.
current_rural_access_rate_npr <- 0.01
current_rural_access_fixed_cap <- 3000000.0

# Enhanced rural access guarantee.
enhanced_rural_access_rate_npr <- 0.02
enhanced_rural_access_fixed_cap <- 5000000.0

# High rural access guarantee.
high_rural_access_rate_npr <- 0.03
high_rural_access_fixed_cap <- 7500000.0

# Rural impact floors.
# These are implementation / reviewable floors layered on top of permanent access payments.
rural_floor_moderate_pct_npr <- -0.02
rural_floor_strong_pct_npr <- -0.015
rural_floor_full_pct_npr <- -0.01

# ============================================================
# 4. Rural flags
# ============================================================

modeled[
  ,
  rural_access_eligible_flag :=
    clean_provider_group == "Rural / CAH / IHS"
]

rural <- copy(modeled[rural_access_eligible_flag == TRUE])

cat("\nRural / CAH / IHS modeled providers:", nrow(rural), "\n")

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

calc_access_payment <- function(npr, rate, cap) {
  pmin(
    as.numeric(npr) * as.numeric(rate),
    as.numeric(cap),
    na.rm = TRUE
  )
}

calc_floor_support <- function(current_impact, npr, floor_pct) {
  needed <- (as.numeric(npr) * as.numeric(floor_pct)) - as.numeric(current_impact)
  needed[is.na(needed)] <- 0.0
  needed[needed < 0] <- 0.0
  needed
}

make_summary <- function(dt_case, label, support_col, impact_col, pct_col) {
  data.table::data.table(
    `Scenario` = label,
    `Rural Providers` = nrow(dt_case),
    `Net Patient Revenue ($B)` =
      billion(safe_sum(dt_case$net_patient_revenue_model)),
    `Original Rural Net Impact ($B)` =
      billion(safe_sum(dt_case$net_provider_impact)),
    `Added Rural Support ($B)` =
      billion(safe_sum(dt_case[[support_col]])),
    `Net Impact After Rural Support ($B)` =
      billion(safe_sum(dt_case[[impact_col]])),
    `Net Impact After Rural Support (% of NPR)` =
      pct1(
        safe_div(
          safe_sum(dt_case[[impact_col]]),
          safe_sum(dt_case$net_patient_revenue_model)
        )
      ),
    `Median Rural Provider Impact (% of NPR)` =
      pct1(median(dt_case[[pct_col]], na.rm = TRUE)),
    `Rural Providers Below -5% NPR` =
      num0(sum(dt_case[[pct_col]] <= large_negative_threshold, na.rm = TRUE)),
    `Rural Providers Below -10% NPR` =
      num0(sum(dt_case[[pct_col]] <= severe_negative_threshold, na.rm = TRUE)),
    `Negative Rural Providers` =
      num0(sum(dt_case[[impact_col]] < 0, na.rm = TRUE)),
    `Positive Rural Providers` =
      num0(sum(dt_case[[impact_col]] > 0, na.rm = TRUE))
  )
}

# ============================================================
# 6. Build rural scenarios
# ============================================================

rural[
  ,
  scenario_A_support := 0.0
]

rural[
  ,
  scenario_A_net_impact := as.numeric(net_provider_impact)
]

rural[
  ,
  scenario_A_net_impact_pct_npr :=
    as.numeric(net_provider_impact_pct_of_npr)
]

# Current rural guarantee: 1% NPR, $3M cap.
rural[
  ,
  scenario_B_current_access_support :=
    calc_access_payment(
      net_patient_revenue_model,
      current_rural_access_rate_npr,
      current_rural_access_fixed_cap
    )
]

rural[
  ,
  scenario_B_total_support :=
    as.numeric(scenario_B_current_access_support)
]

rural[
  ,
  scenario_B_net_impact :=
    as.numeric(net_provider_impact + scenario_B_total_support)
]

rural[
  ,
  scenario_B_net_impact_pct_npr :=
    data.table::fifelse(
      net_patient_revenue_model > 0,
      as.numeric(scenario_B_net_impact / net_patient_revenue_model),
      NA_real_
    )
]

# Enhanced rural guarantee: 2% NPR, $5M cap.
rural[
  ,
  scenario_C_enhanced_access_support :=
    calc_access_payment(
      net_patient_revenue_model,
      enhanced_rural_access_rate_npr,
      enhanced_rural_access_fixed_cap
    )
]

rural[
  ,
  scenario_C_total_support :=
    as.numeric(scenario_C_enhanced_access_support)
]

rural[
  ,
  scenario_C_net_impact :=
    as.numeric(net_provider_impact + scenario_C_total_support)
]

rural[
  ,
  scenario_C_net_impact_pct_npr :=
    data.table::fifelse(
      net_patient_revenue_model > 0,
      as.numeric(scenario_C_net_impact / net_patient_revenue_model),
      NA_real_
    )
]

# High rural guarantee: 3% NPR, $7.5M cap.
rural[
  ,
  scenario_D_high_access_support :=
    calc_access_payment(
      net_patient_revenue_model,
      high_rural_access_rate_npr,
      high_rural_access_fixed_cap
    )
]

rural[
  ,
  scenario_D_total_support :=
    as.numeric(scenario_D_high_access_support)
]

rural[
  ,
  scenario_D_net_impact :=
    as.numeric(net_provider_impact + scenario_D_total_support)
]

rural[
  ,
  scenario_D_net_impact_pct_npr :=
    data.table::fifelse(
      net_patient_revenue_model > 0,
      as.numeric(scenario_D_net_impact / net_patient_revenue_model),
      NA_real_
    )
]

# Enhanced guarantee + moderate floor at -2.0% NPR.
rural[
  ,
  scenario_E_floor_support :=
    calc_floor_support(
      scenario_C_net_impact,
      net_patient_revenue_model,
      rural_floor_moderate_pct_npr
    )
]

rural[
  ,
  scenario_E_total_support :=
    as.numeric(scenario_C_enhanced_access_support + scenario_E_floor_support)
]

rural[
  ,
  scenario_E_net_impact :=
    as.numeric(net_provider_impact + scenario_E_total_support)
]

rural[
  ,
  scenario_E_net_impact_pct_npr :=
    data.table::fifelse(
      net_patient_revenue_model > 0,
      as.numeric(scenario_E_net_impact / net_patient_revenue_model),
      NA_real_
    )
]

# Enhanced guarantee + strong floor at -1.5% NPR.
rural[
  ,
  scenario_F_floor_support :=
    calc_floor_support(
      scenario_C_net_impact,
      net_patient_revenue_model,
      rural_floor_strong_pct_npr
    )
]

rural[
  ,
  scenario_F_total_support :=
    as.numeric(scenario_C_enhanced_access_support + scenario_F_floor_support)
]

rural[
  ,
  scenario_F_net_impact :=
    as.numeric(net_provider_impact + scenario_F_total_support)
]

rural[
  ,
  scenario_F_net_impact_pct_npr :=
    data.table::fifelse(
      net_patient_revenue_model > 0,
      as.numeric(scenario_F_net_impact / net_patient_revenue_model),
      NA_real_
    )
]

# High guarantee + full rural floor at -1.0% NPR.
rural[
  ,
  scenario_G_floor_support :=
    calc_floor_support(
      scenario_D_net_impact,
      net_patient_revenue_model,
      rural_floor_full_pct_npr
    )
]

rural[
  ,
  scenario_G_total_support :=
    as.numeric(scenario_D_high_access_support + scenario_G_floor_support)
]

rural[
  ,
  scenario_G_net_impact :=
    as.numeric(net_provider_impact + scenario_G_total_support)
]

rural[
  ,
  scenario_G_net_impact_pct_npr :=
    data.table::fifelse(
      net_patient_revenue_model > 0,
      as.numeric(scenario_G_net_impact / net_patient_revenue_model),
      NA_real_
    )
]

# ============================================================
# 7. Table 7K — rural scenario summary
# ============================================================

table_7K <- data.table::rbindlist(
  list(
    make_summary(
      rural,
      "A. Current Base/Base; no added rural access support",
      "scenario_A_support",
      "scenario_A_net_impact",
      "scenario_A_net_impact_pct_npr"
    ),
    make_summary(
      rural,
      "B. Current rural access guarantee: 1% NPR, $3M cap",
      "scenario_B_total_support",
      "scenario_B_net_impact",
      "scenario_B_net_impact_pct_npr"
    ),
    make_summary(
      rural,
      "C. Enhanced rural access guarantee: 2% NPR, $5M cap",
      "scenario_C_total_support",
      "scenario_C_net_impact",
      "scenario_C_net_impact_pct_npr"
    ),
    make_summary(
      rural,
      "D. High rural access guarantee: 3% NPR, $7.5M cap",
      "scenario_D_total_support",
      "scenario_D_net_impact",
      "scenario_D_net_impact_pct_npr"
    ),
    make_summary(
      rural,
      "E. Enhanced guarantee + rural floor at -2.0% NPR",
      "scenario_E_total_support",
      "scenario_E_net_impact",
      "scenario_E_net_impact_pct_npr"
    ),
    make_summary(
      rural,
      "F. Enhanced guarantee + rural floor at -1.5% NPR",
      "scenario_F_total_support",
      "scenario_F_net_impact",
      "scenario_F_net_impact_pct_npr"
    ),
    make_summary(
      rural,
      "G. High guarantee + rural floor at -1.0% NPR",
      "scenario_G_total_support",
      "scenario_G_net_impact",
      "scenario_G_net_impact_pct_npr"
    )
  ),
  fill = TRUE
)

# ============================================================
# 8. Table 7L — provider-level rural output
# ============================================================

table_7L <- rural[
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
    
    current_access_support = scenario_B_total_support,
    current_access_net_impact_pct_npr = scenario_B_net_impact_pct_npr,
    
    enhanced_access_support = scenario_C_total_support,
    enhanced_access_net_impact_pct_npr = scenario_C_net_impact_pct_npr,
    
    high_access_support = scenario_D_total_support,
    high_access_net_impact_pct_npr = scenario_D_net_impact_pct_npr,
    
    enhanced_plus_floor_2pct_support = scenario_E_total_support,
    enhanced_plus_floor_2pct_net_impact_pct_npr = scenario_E_net_impact_pct_npr,
    
    enhanced_plus_floor_1_5pct_support = scenario_F_total_support,
    enhanced_plus_floor_1_5pct_net_impact_pct_npr = scenario_F_net_impact_pct_npr,
    
    high_plus_floor_1pct_support = scenario_G_total_support,
    high_plus_floor_1pct_net_impact_pct_npr = scenario_G_net_impact_pct_npr
  )
][order(base_net_impact_pct_npr)]

# ============================================================
# 9. Methodology notes
# ============================================================

methodology_notes <- c(
  "Enhanced Rural Access Guarantee methodology notes",
  "================================================",
  "",
  paste0("Build year: ", hcris_year_label),
  paste0("Generated: ", Sys.time()),
  "",
  "This sensitivity isolates rural / CAH / IHS providers from the corrected Base/Base provider-impact file.",
  "It does not rebuild Tables 7A-7J.",
  "",
  "Policy rationale:",
  "Rural access support is treated as a permanent access-capacity payment rather than ordinary transition stabilization.",
  "Rural providers face structural constraints that do not automatically disappear after transition: low volume, fixed standby costs, broad geographic service areas, workforce constraints, and lack of nearby substitute providers.",
  "",
  "Scenario A:",
  "Current Base/Base with no added rural access support.",
  "",
  "Scenario B:",
  "Current rural access guarantee equal to 1.0% of NPR, capped at $3 million per rural provider.",
  "",
  "Scenario C:",
  "Enhanced rural access guarantee equal to 2.0% of NPR, capped at $5 million per rural provider.",
  "",
  "Scenario D:",
  "High rural access guarantee equal to 3.0% of NPR, capped at $7.5 million per rural provider.",
  "",
  "Scenario E:",
  "Enhanced rural access guarantee plus a rural impact floor of -2.0% of NPR.",
  "",
  "Scenario F:",
  "Enhanced rural access guarantee plus a rural impact floor of -1.5% of NPR.",
  "",
  "Scenario G:",
  "High rural access guarantee plus a rural impact floor of -1.0% of NPR.",
  "",
  "Interpretive rule:",
  "The preferred central policy case is likely Scenario C or Scenario F, depending on how strongly the paper wants to protect rural providers.",
  "Scenario C is a permanent access-capacity payment.",
  "Scenario F adds a stronger rural transition floor and should be described as reviewable or implementation-period protection."
)

# ============================================================
# 10. Save outputs
# ============================================================

table_7K_file <- file.path(
  table7_dir,
  "table_7K_enhanced_rural_access_sensitivity.csv"
)

table_7L_file <- file.path(
  table7_dir,
  "table_7L_rural_provider_level_enhanced_access.csv"
)

methodology_file <- file.path(
  table7_dir,
  "table_7_enhanced_rural_access_methodology_notes.txt"
)

data.table::fwrite(table_7K, table_7K_file)
data.table::fwrite(table_7L, table_7L_file)
writeLines(methodology_notes, methodology_file)

# Optional Excel export.
excel_file <- file.path(
  table7_dir,
  "table_7K_7L_enhanced_rural_access_sensitivity.xlsx"
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
  
  add_sheet(wb, "Table 7K", table_7K)
  add_sheet(wb, "Table 7L", table_7L)
  
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
# 11. Print summaries
# ============================================================

cat("\n============================================================\n")
cat("ENHANCED RURAL ACCESS GUARANTEE SENSITIVITY COMPLETE\n")
cat("============================================================\n")

cat("\nRural assumptions:\n")
cat("Current rural access guarantee: ", pct1(current_rural_access_rate_npr), "% NPR, $", format(current_rural_access_fixed_cap, big.mark = ","), " cap\n", sep = "")
cat("Enhanced rural access guarantee: ", pct1(enhanced_rural_access_rate_npr), "% NPR, $", format(enhanced_rural_access_fixed_cap, big.mark = ","), " cap\n", sep = "")
cat("High rural access guarantee: ", pct1(high_rural_access_rate_npr), "% NPR, $", format(high_rural_access_fixed_cap, big.mark = ","), " cap\n", sep = "")
cat("Moderate rural floor: ", pct1(rural_floor_moderate_pct_npr), "% NPR\n", sep = "")
cat("Strong rural floor: ", pct1(rural_floor_strong_pct_npr), "% NPR\n", sep = "")
cat("Full rural floor: ", pct1(rural_floor_full_pct_npr), "% NPR\n", sep = "")

cat("\nTable 7K. Enhanced Rural Access Sensitivity:\n")
print(table_7K)

cat("\nWorst rural providers before and after enhanced support:\n")
print(table_7L[
  ,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    state_abbrev,
    clean_provider_model_class,
    net_patient_revenue_model,
    base_net_impact_pct_npr,
    current_access_net_impact_pct_npr,
    enhanced_access_net_impact_pct_npr,
    enhanced_plus_floor_1_5pct_net_impact_pct_npr,
    high_plus_floor_1pct_net_impact_pct_npr
  )
][order(base_net_impact_pct_npr)][1:30])

cat("\nSaved:\n")
cat(table_7K_file, "\n")
cat(table_7L_file, "\n")
cat(methodology_file, "\n")

if (excel_written == TRUE) {
  cat(excel_file, "\n")
}

cat("\n============================================================\n")