# Scripts/15_make_table7_publication_grade_tables.R
# Create publication-grade Table 7 outputs for the UCC/HSE white paper.
#
# Purpose:
#   This script does NOT rebuild the provider-impact model.
#   It reads already-generated Table 7 CSV outputs and produces:
#
#     1. publication-grade main-paper tables,
#     2. publication-grade appendix tables,
#     3. a formatted Excel workbook containing all tables,
#     4. table notes,
#     5. methodology notes,
#     6. a final manifest.
#
# Required prior scripts:
#   08_extract_g2_g3_revenue_expense.R
#   09_validate_provider_classification.R
#   10_create_stabilization_eligibility.R
#   11_create_provider_impact_scenarios.R
#   11A_audit_provider_impact_coverage_and_exposure.R
#   12_format_table7_publication_outputs.R
#   13_provider_transition_protection_sensitivity.R
#   13B_enhanced_rural_access_sensitivity.R
#   13C_behavioral_psychiatric_sensitivity.R
#   14_create_table7_access_protection_summary.R
#
# Main paper tables:
#   Table 7A. Provider Impact 3x3 Scenario Matrix
#   Table 7B. Provider Impact by Provider Group
#   Table 7C. Provider Impact by Provider Class
#   Table 7D. Provider-Level Distribution
#   Table 7E. Model Coverage and Data Quality Audit
#   Table 7F. Exposure-Anomaly Sensitivity
#   Table 7G. Access-Protection Policy Options
#
# Appendix tables:
#   Appendix Table 7G. Access-Protection Options Menu
#   Appendix Table 7J. Provider-Level Transition and Rural Access Sensitivity
#   Appendix Table 7K. Enhanced Rural Access Sensitivity
#   Appendix Table 7L. Rural Provider-Level Enhanced Access
#   Appendix Table 7M. Psychiatric / Behavioral Provider Sensitivity
#   Appendix Table 7N. Psychiatric / Behavioral Provider-Level Review
#   Appendix Table 7O. Behavioral Remaining Severe Effects
#   Appendix Table 7P. Behavioral Review Universe
#
# Output folder:
#   Output/Table7_Publication/Final_Publication_Grade/

source("Scripts/00_setup.R")

cat("\n============================================================\n")
cat("MAKE TABLE 7 PUBLICATION-GRADE MAIN AND APPENDIX TABLES\n")
cat("============================================================\n")
cat("Build year:", hcris_year_label, "\n\n")

# ============================================================
# 0. Folders
# ============================================================

table7_dir <- file.path(path_output, "Table7_Publication")
pub_dir <- file.path(table7_dir, "Final_Publication_Grade")

if (!dir.exists(table7_dir)) {
  stop("Missing Table7_Publication folder. Run Scripts 12-14 first.")
}

if (!dir.exists(pub_dir)) {
  dir.create(pub_dir, recursive = TRUE)
}

cat("Input folder:\n")
cat(table7_dir, "\n\n")

cat("Final publication output folder:\n")
cat(pub_dir, "\n\n")

# ============================================================
# 1. Input files
# ============================================================

files <- list(
  # Main-paper source tables
  table_7A = file.path(table7_dir, "table_7A_publication.csv"),
  table_7B = file.path(table7_dir, "table_7B_publication.csv"),
  table_7C = file.path(table7_dir, "table_7C_publication.csv"),
  table_7D = file.path(table7_dir, "table_7D_publication.csv"),
  table_7E = file.path(table7_dir, "table_7E_model_coverage_audit.csv"),
  table_7F = file.path(table7_dir, "table_7F_exposure_anomaly_sensitivity.csv"),
  table_7G = file.path(table7_dir, "table_7G_access_protection_policy_options.csv"),
  
  # Appendix / options source tables
  table_7G_options = file.path(table7_dir, "table_7G_access_protection_options_appendix.csv"),
  
  # General transition / rural access package from Script 13
  table_7J = file.path(table7_dir, "table_7J_provider_level_transition_and_rural_access.csv"),
  
  # Enhanced rural access package from Script 13B
  table_7K = file.path(table7_dir, "table_7K_enhanced_rural_access_sensitivity.csv"),
  table_7L = file.path(table7_dir, "table_7L_rural_provider_level_enhanced_access.csv"),
  
  # Behavioral package from Script 13C
  table_7M = file.path(table7_dir, "table_7M_behavioral_psychiatric_sensitivity.csv"),
  table_7N = file.path(table7_dir, "table_7N_behavioral_psychiatric_provider_level.csv"),
  table_7O = file.path(table7_dir, "table_7O_behavioral_remaining_severe_effects.csv"),
  table_7P = file.path(table7_dir, "table_7P_behavioral_review_universe.csv")
)

missing_files <- unlist(files)[!file.exists(unlist(files))]

if (length(missing_files) > 0) {
  stop(
    "Missing required Table 7 files. Rerun Scripts 12, 13, 13B, 13C, and 14 first:\n",
    paste(missing_files, collapse = "\n")
  )
}

# ============================================================
# 2. Read inputs
# ============================================================

t7A <- data.table::fread(files$table_7A)
t7B <- data.table::fread(files$table_7B)
t7C <- data.table::fread(files$table_7C)
t7D <- data.table::fread(files$table_7D)
t7E <- data.table::fread(files$table_7E)
t7F <- data.table::fread(files$table_7F)
t7G <- data.table::fread(files$table_7G)

t7G_options <- data.table::fread(files$table_7G_options)

t7J <- data.table::fread(files$table_7J)

t7K <- data.table::fread(files$table_7K)
t7L <- data.table::fread(files$table_7L)

t7M <- data.table::fread(files$table_7M)
t7N <- data.table::fread(files$table_7N)
t7O <- data.table::fread(files$table_7O)
t7P <- data.table::fread(files$table_7P)

cat("Loaded all Table 7 inputs.\n\n")

# ============================================================
# 3. Formatting helpers
# ============================================================

fmt_money_b <- function(x, digits = 2) {
  x <- suppressWarnings(as.numeric(x))
  ifelse(
    is.na(x),
    "",
    paste0(
      ifelse(x < 0, "-", ""),
      "$",
      formatC(abs(x), format = "f", digits = digits, big.mark = ",")
    )
  )
}

fmt_money_raw <- function(x, digits = 0) {
  x <- suppressWarnings(as.numeric(x))
  ifelse(
    is.na(x),
    "",
    paste0(
      ifelse(x < 0, "-", ""),
      "$",
      formatC(abs(x), format = "f", digits = digits, big.mark = ",")
    )
  )
}

fmt_num <- function(x, digits = 1) {
  x <- suppressWarnings(as.numeric(x))
  ifelse(
    is.na(x),
    "",
    formatC(x, format = "f", digits = digits, big.mark = ",")
  )
}

fmt_pct <- function(x, digits = 1) {
  x <- suppressWarnings(as.numeric(x))
  ifelse(
    is.na(x),
    "",
    paste0(formatC(x, format = "f", digits = digits, big.mark = ","), "%")
  )
}

fmt_pct_decimal <- function(x, digits = 1) {
  x <- suppressWarnings(as.numeric(x))
  ifelse(
    is.na(x),
    "",
    paste0(formatC(100 * x, format = "f", digits = digits, big.mark = ","), "%")
  )
}

fmt_int <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  ifelse(
    is.na(x),
    "",
    formatC(round(x, 0), format = "f", digits = 0, big.mark = ",")
  )
}

clean_names_for_excel <- function(dt) {
  out <- copy(dt)
  names(out) <- gsub("_", " ", names(out))
  names(out) <- tools::toTitleCase(names(out))
  out
}

format_by_name <- function(dt, provider_level = FALSE) {
  out <- copy(dt)
  
  for (cc in names(out)) {
    cc_lower <- tolower(cc)
    
    if (grepl("\\(\\$b\\)|\\$b|\\(\\$ b\\)", cc_lower)) {
      out[, (cc) := fmt_money_b(get(cc), digits = 2)]
    } else if (grepl("npr|net_patient_revenue|outpatient_exposure|repricing_pressure|uncompensated|stabilization|support|impact", cc_lower) &&
               provider_level == TRUE &&
               !grepl("pct|percent|ratio|flag|tier|basis|method|scenario|group|class|name|city|state|provider|rpt|prvdr", cc_lower)) {
      out[, (cc) := fmt_money_raw(get(cc), digits = 0)]
    } else if (grepl("pct_of_npr|pct_npr|impact_pct|ratio", cc_lower) &&
               provider_level == TRUE) {
      out[, (cc) := fmt_pct_decimal(get(cc), digits = 1)]
    } else if (grepl("\\(% of npr\\)|% npr|\\(%\\)|percent|share", cc_lower)) {
      out[, (cc) := fmt_pct(get(cc), digits = 1)]
    } else if (grepl("providers|count|number", cc_lower) &&
               !grepl("group|class|status|design|provider name|provider_group|provider_class", cc_lower)) {
      out[, (cc) := fmt_int(get(cc))]
    }
  }
  
  out
}

select_existing <- function(dt, cols) {
  dt[, intersect(cols, names(dt)), with = FALSE]
}

# ============================================================
# 4. Main paper tables
# ============================================================

# ----------------------------
# Table 7A
# ----------------------------

t7A_order <- c(
  "Repricing Scenario",
  "Stabilization Scenario",
  "Modeled Providers",
  "Outpatient/Routine Exposure ($B)",
  "Repricing Pressure ($B)",
  "UC / Liquidity Offset ($B)",
  "Stabilization Support ($B)",
  "Net Provider Impact ($B)",
  "Net Impact (% of NPR)",
  "Negative-Impact Providers",
  "Large Negative-Impact Providers",
  "Median Provider Impact (% of NPR)"
)

t7A_pub <- select_existing(t7A, t7A_order)

# ----------------------------
# Table 7B
# ----------------------------

t7B_order <- c(
  "Provider Group",
  "Providers",
  "Modeled Providers",
  "Net Patient Revenue ($B)",
  "Outpatient/Routine Exposure ($B)",
  "Repricing Pressure ($B)",
  "UC / Liquidity Offset ($B)",
  "Stabilization Support ($B)",
  "Net Provider Impact ($B)",
  "Net Impact (% of NPR)",
  "Negative-Impact Providers",
  "Large Negative-Impact Providers",
  "Stabilization-Eligible Providers"
)

t7B_pub <- select_existing(t7B, t7B_order)

# ----------------------------
# Table 7C
# ----------------------------

t7C_order <- c(
  "Provider Group",
  "Provider Class",
  "Providers",
  "Modeled Providers",
  "Net Patient Revenue ($B)",
  "Outpatient/Routine Exposure ($B)",
  "Repricing Pressure ($B)",
  "UC / Liquidity Offset ($B)",
  "Stabilization Support ($B)",
  "Net Provider Impact ($B)",
  "Net Impact (% of NPR)",
  "Negative-Impact Providers",
  "Large Negative-Impact Providers",
  "Stabilization-Eligible Providers"
)

t7C_pub <- select_existing(t7C, t7C_order)

# ----------------------------
# Table 7D
# ----------------------------

t7D_order <- c(
  "Provider Group",
  "Provider Impact Bucket (% of NPR)",
  "Providers",
  "Net Patient Revenue ($B)",
  "Net Provider Impact ($B)",
  "Median Provider Impact (% of NPR)"
)

t7D_pub <- select_existing(t7D, t7D_order)

# ----------------------------
# Table 7E
# ----------------------------

t7E_pub <- copy(t7E)

# ----------------------------
# Table 7F
# ----------------------------

t7F_order <- c(
  "Sensitivity Case",
  "Modeled Providers",
  "Net Patient Revenue ($B)",
  "Outpatient/Routine Exposure ($B)",
  "Repricing Pressure ($B)",
  "UC / Liquidity Offset ($B)",
  "Stabilization Support ($B)",
  "Net Provider Impact ($B)",
  "Net Impact (% of NPR)",
  "Median Provider Impact (% of NPR)"
)

t7F_pub <- select_existing(t7F, t7F_order)

# ----------------------------
# Table 7G
# ----------------------------

t7G_order <- c(
  "Policy Layer",
  "Provider Group",
  "Protection Design",
  "Permanent Component",
  "Temporary / Implementation Component",
  "Added Support ($B)",
  "Net Impact After Protection ($B)",
  "Net Impact After Protection (% NPR)",
  "Providers Below -5% NPR",
  "Providers Below -10% NPR",
  "Temporary or Permanent?",
  "Preferred Policy Status",
  "Interpretation"
)

t7G_pub <- select_existing(t7G, t7G_order)

# ============================================================
# 5. Appendix table slimming / ordering
# ============================================================

# ----------------------------
# Appendix Table 7G Options
# ----------------------------

app7G_options_pub <- copy(t7G_options)

# ----------------------------
# Appendix Table 7J
# Provider-level transition and rural access output can be huge.
# Keep only publication-relevant columns.
# ----------------------------

app7J_order <- c(
  "rpt_rec_num",
  "prvdr_num_chr",
  "provider_name",
  "city",
  "state_abbrev",
  "clean_provider_group",
  "clean_provider_model_class",
  "revenue_source_method",
  "net_patient_revenue_model",
  "outpatient_exposure_used",
  "outpatient_repricing_pressure",
  "uncompensated_care_offset",
  "stabilization_support",
  "net_provider_impact",
  "net_provider_impact_pct_of_npr",
  "stabilization_tier",
  "stabilization_basis",
  "large_negative_impact_flag",
  "severe_negative_impact_flag",
  "permanent_rural_access_eligible_flag",
  "pediatric_transition_eligible_flag",
  "case_F_temporary_support",
  "case_F_permanent_rural_access_support",
  "case_F_total_added_support",
  "case_F_net_impact",
  "case_F_net_impact_pct_npr"
)

app7J_pub <- select_existing(t7J, app7J_order)
app7J_pub <- clean_names_for_excel(app7J_pub)

# ----------------------------
# Appendix Table 7K
# Enhanced Rural Access Sensitivity
# ----------------------------

app7K_pub <- copy(t7K)

# ----------------------------
# Appendix Table 7L
# Rural Provider-Level Enhanced Access
# ----------------------------

app7L_order <- c(
  "rpt_rec_num",
  "prvdr_num_chr",
  "provider_name",
  "city",
  "state_abbrev",
  "clean_provider_model_class",
  "revenue_source_method",
  "stabilization_tier",
  "stabilization_basis",
  "net_patient_revenue_model",
  "outpatient_exposure_used",
  "outpatient_repricing_pressure",
  "uncompensated_care_offset",
  "stabilization_support",
  "base_net_impact",
  "base_net_impact_pct_npr",
  "current_access_support",
  "current_access_net_impact_pct_npr",
  "enhanced_access_support",
  "enhanced_access_net_impact_pct_npr",
  "enhanced_plus_floor_1_5pct_support",
  "enhanced_plus_floor_1_5pct_net_impact_pct_npr",
  "high_plus_floor_1pct_support",
  "high_plus_floor_1pct_net_impact_pct_npr"
)

app7L_pub <- select_existing(t7L, app7L_order)
app7L_pub <- clean_names_for_excel(app7L_pub)

# ----------------------------
# Appendix Table 7M
# Behavioral / Psychiatric Sensitivity
# ----------------------------

app7M_pub <- copy(t7M)

# ----------------------------
# Appendix Table 7N
# Behavioral Provider-Level Review
# ----------------------------

app7N_order <- c(
  "rpt_rec_num",
  "prvdr_num_chr",
  "provider_name",
  "city",
  "state_abbrev",
  "clean_provider_group",
  "clean_provider_model_class",
  "revenue_source_method",
  "stabilization_tier",
  "stabilization_basis",
  "net_patient_revenue_model",
  "outpatient_exposure_used",
  "outpatient_repricing_pressure",
  "uncompensated_care_offset",
  "stabilization_support",
  "base_net_impact",
  "base_net_impact_pct_npr",
  "scenario_B_50pct_repricing_net_impact",
  "scenario_B_50pct_repricing_net_impact_pct_npr",
  "scenario_C_25pct_repricing_net_impact",
  "scenario_C_25pct_repricing_net_impact_pct_npr",
  "scenario_D_floor_7_5pct_added_support",
  "scenario_D_floor_7_5pct_net_impact_pct_npr",
  "scenario_F_25pct_repricing_floor_5pct_added_support",
  "scenario_F_25pct_repricing_floor_5pct_net_impact_pct_npr"
)

app7N_pub <- select_existing(t7N, app7N_order)
app7N_pub <- clean_names_for_excel(app7N_pub)

# ----------------------------
# Appendix Table 7O
# Behavioral Remaining Severe Effects
# ----------------------------

app7O_pub <- copy(t7O)

# ----------------------------
# Appendix Table 7P
# Behavioral Review Universe
# ----------------------------

app7P_order <- c(
  "rpt_rec_num",
  "prvdr_num_chr",
  "provider_name",
  "city",
  "state_abbrev",
  "raw_provider_model_class",
  "clean_provider_group",
  "clean_provider_model_class",
  "behavioral_primary_flag",
  "behavioral_name_review_flag",
  "revenue_source_method",
  "net_patient_revenue_model",
  "outpatient_exposure_used",
  "outpatient_repricing_pressure",
  "uncompensated_care_offset",
  "stabilization_support",
  "net_provider_impact",
  "net_provider_impact_pct_of_npr",
  "stabilization_tier",
  "stabilization_basis"
)

app7P_pub <- select_existing(t7P, app7P_order)
app7P_pub <- clean_names_for_excel(app7P_pub)

# ============================================================
# 6. Human-readable formatted versions
# ============================================================

t7A_final <- format_by_name(t7A_pub)
t7B_final <- format_by_name(t7B_pub)
t7C_final <- format_by_name(t7C_pub)
t7D_final <- format_by_name(t7D_pub)
t7E_final <- copy(t7E_pub)
t7F_final <- format_by_name(t7F_pub)
t7G_final <- format_by_name(t7G_pub)

app7G_options_final <- format_by_name(app7G_options_pub)
app7J_final <- format_by_name(app7J_pub, provider_level = TRUE)
app7K_final <- format_by_name(app7K_pub)
app7L_final <- format_by_name(app7L_pub, provider_level = TRUE)
app7M_final <- format_by_name(app7M_pub)
app7N_final <- format_by_name(app7N_pub, provider_level = TRUE)
app7O_final <- format_by_name(app7O_pub)
app7P_final <- format_by_name(app7P_pub, provider_level = TRUE)

# ============================================================
# 7. Table notes
# ============================================================

table_notes <- data.table::data.table(
  Table = c(
    "Table 7A",
    "Table 7B",
    "Table 7C",
    "Table 7D",
    "Table 7E",
    "Table 7F",
    "Table 7G",
    "Appendix Table 7G",
    "Appendix Table 7J",
    "Appendix Table 7K",
    "Appendix Table 7L",
    "Appendix Table 7M",
    "Appendix Table 7N",
    "Appendix Table 7O",
    "Appendix Table 7P"
  ),
  Title = c(
    "Provider Impact 3x3 Scenario Matrix",
    "Provider Impact by Provider Group under Base/Base Scenario",
    "Provider Impact by Provider Class under Base/Base Scenario",
    "Distribution of Provider-Level Effects under Base/Base Scenario",
    "Provider-Impact Model Coverage and Data Quality Audit",
    "Exposure-Anomaly Sensitivity under Base/Base Scenario",
    "Access-Protection Policy Options",
    "Access-Protection Options Menu",
    "Provider-Level Transition and Rural Access Sensitivity",
    "Enhanced Rural Access Sensitivity",
    "Rural Provider-Level Enhanced Access",
    "Psychiatric / Behavioral Provider Sensitivity",
    "Psychiatric / Behavioral Provider-Level Review",
    "Remaining Severe Psychiatric / Behavioral Effects",
    "Behavioral Review Universe"
  ),
  Placement = c(
    rep("Main paper", 7),
    rep("Appendix", 8)
  ),
  Note = c(
    "Shows modeled provider impact across low/base/high repricing and stabilization scenarios.",
    "Aggregates Base/Base provider impact by cleaned provider group.",
    "Disaggregates Base/Base provider impact by cleaned provider class.",
    "Shows the distribution of provider-level net impacts as a percentage of net patient revenue.",
    "Reports model coverage, source-method counts, fallback use, and data-quality checks.",
    "Tests whether exposure-anomaly records materially change Base/Base results.",
    "Summarizes preferred targeted access protections for rural and behavioral providers.",
    "Shows menu of rural and behavioral access-protection options.",
    "Provider-level output from the combined transition and rural access sensitivity.",
    "Shows rural access-support options, including the preferred enhanced rural guarantee plus implementation floor.",
    "Provider-level rural access sensitivity output.",
    "Shows behavioral institutional repricing options and floor options.",
    "Provider-level psychiatric / behavioral sensitivity output.",
    "Shows remaining severe behavioral impacts under each behavioral treatment scenario.",
    "Expanded behavioral review universe including name-flagged records outside the primary behavioral class."
  )
)

methodology_note <- c(
  "Table 7 publication-grade methodology note",
  "========================================",
  "",
  paste0("Build year: ", hcris_year_label),
  paste0("Generated: ", Sys.time()),
  "",
  "The Table 7 package is based on the corrected FY2024 HCRIS provider-impact model.",
  "",
  "Core formula:",
  "Net Provider Impact = - Market Repricing Pressure + UC / Liquidity Offset + Bounded Stabilization Support.",
  "",
  "Preferred access-protection package:",
  "Rural: permanent rural access guarantee equal to 2% of NPR, capped at $5M per rural provider, plus an implementation-period rural floor at -1.5% NPR.",
  "Behavioral: institutional behavioral providers are assigned 25% of standard modeled repricing pressure, plus an implementation-period floor at -5% NPR.",
  "",
  "Interpretation:",
  "The preferred package is targeted. It preserves the main provider-side price-discipline mechanism while protecting rural access and correcting behavioral institutional exposure outliers.",
  "",
  "Suggested main-paper table sequence:",
  "Table 7A, Table 7B, Table 7C, Table 7D, Table 7E, Table 7F, Table 7G.",
  "",
  "Suggested appendix sequence:",
  "Appendix Table 7G, Appendix Table 7J, Appendix Table 7K, Appendix Table 7L, Appendix Table 7M, Appendix Table 7N, Appendix Table 7O, Appendix Table 7P."
)

# ============================================================
# 8. Save CSV outputs
# ============================================================

out_files <- list(
  table_7A = file.path(pub_dir, "Table_7A_Provider_Impact_3x3_Scenario_Matrix.csv"),
  table_7B = file.path(pub_dir, "Table_7B_Provider_Impact_by_Group.csv"),
  table_7C = file.path(pub_dir, "Table_7C_Provider_Impact_by_Class.csv"),
  table_7D = file.path(pub_dir, "Table_7D_Provider_Level_Distribution.csv"),
  table_7E = file.path(pub_dir, "Table_7E_Model_Coverage_Data_Quality_Audit.csv"),
  table_7F = file.path(pub_dir, "Table_7F_Exposure_Anomaly_Sensitivity.csv"),
  table_7G = file.path(pub_dir, "Table_7G_Access_Protection_Policy_Options.csv"),
  
  appendix_7G_options = file.path(pub_dir, "Appendix_Table_7G_Access_Protection_Options_Menu.csv"),
  appendix_7J = file.path(pub_dir, "Appendix_Table_7J_Provider_Level_Transition_Rural_Access.csv"),
  appendix_7K = file.path(pub_dir, "Appendix_Table_7K_Enhanced_Rural_Access_Sensitivity.csv"),
  appendix_7L = file.path(pub_dir, "Appendix_Table_7L_Rural_Provider_Level_Enhanced_Access.csv"),
  appendix_7M = file.path(pub_dir, "Appendix_Table_7M_Behavioral_Psychiatric_Sensitivity.csv"),
  appendix_7N = file.path(pub_dir, "Appendix_Table_7N_Behavioral_Psychiatric_Provider_Level.csv"),
  appendix_7O = file.path(pub_dir, "Appendix_Table_7O_Behavioral_Remaining_Severe_Effects.csv"),
  appendix_7P = file.path(pub_dir, "Appendix_Table_7P_Behavioral_Review_Universe.csv"),
  
  notes = file.path(pub_dir, "Table_7_Publication_Notes.csv"),
  methodology = file.path(pub_dir, "Table_7_Methodology_Note.txt")
)

data.table::fwrite(t7A_final, out_files$table_7A)
data.table::fwrite(t7B_final, out_files$table_7B)
data.table::fwrite(t7C_final, out_files$table_7C)
data.table::fwrite(t7D_final, out_files$table_7D)
data.table::fwrite(t7E_final, out_files$table_7E)
data.table::fwrite(t7F_final, out_files$table_7F)
data.table::fwrite(t7G_final, out_files$table_7G)

data.table::fwrite(app7G_options_final, out_files$appendix_7G_options)
data.table::fwrite(app7J_final, out_files$appendix_7J)
data.table::fwrite(app7K_final, out_files$appendix_7K)
data.table::fwrite(app7L_final, out_files$appendix_7L)
data.table::fwrite(app7M_final, out_files$appendix_7M)
data.table::fwrite(app7N_final, out_files$appendix_7N)
data.table::fwrite(app7O_final, out_files$appendix_7O)
data.table::fwrite(app7P_final, out_files$appendix_7P)

data.table::fwrite(table_notes, out_files$notes)
writeLines(methodology_note, out_files$methodology)

# ============================================================
# 9. Excel workbook with all tables
# ============================================================

excel_file <- file.path(pub_dir, "Table_7_All_Main_and_Appendix_Tables.xlsx")

excel_written <- FALSE

if (!requireNamespace("openxlsx", quietly = TRUE)) {
  warning("Package openxlsx is not installed. CSV outputs were written, but Excel workbook was not created.")
} else {
  wb <- openxlsx::createWorkbook()
  
  header_style <- openxlsx::createStyle(
    textDecoration = "bold",
    halign = "center",
    valign = "center",
    fgFill = "#D9EAF7",
    border = "TopBottomLeftRight",
    wrapText = TRUE
  )
  
  body_style <- openxlsx::createStyle(
    valign = "top",
    wrapText = TRUE,
    border = "TopBottomLeftRight"
  )
  
  title_style <- openxlsx::createStyle(
    textDecoration = "bold",
    fontSize = 14
  )
  
  add_pub_sheet <- function(wb, sheet_name, title, dt) {
    # Excel worksheet names max length is 31 characters.
    safe_sheet_name <- substr(sheet_name, 1, 31)
    
    openxlsx::addWorksheet(wb, safe_sheet_name)
    
    openxlsx::writeData(wb, safe_sheet_name, title, startRow = 1, startCol = 1)
    openxlsx::addStyle(wb, safe_sheet_name, title_style, rows = 1, cols = 1, gridExpand = TRUE)
    
    openxlsx::writeData(wb, safe_sheet_name, dt, startRow = 3, startCol = 1)
    
    n_cols <- ncol(dt)
    n_rows <- nrow(dt) + 3
    
    if (n_cols > 0) {
      openxlsx::addStyle(
        wb,
        safe_sheet_name,
        header_style,
        rows = 3,
        cols = 1:n_cols,
        gridExpand = TRUE
      )
      
      if (nrow(dt) > 0) {
        openxlsx::addStyle(
          wb,
          safe_sheet_name,
          body_style,
          rows = 4:n_rows,
          cols = 1:n_cols,
          gridExpand = TRUE
        )
      }
      
      openxlsx::freezePane(wb, safe_sheet_name, firstActiveRow = 4)
      openxlsx::setColWidths(wb, safe_sheet_name, cols = 1:n_cols, widths = "auto")
    }
  }
  
  # Main-paper sheets
  add_pub_sheet(wb, "Table 7A", "Table 7A. Provider Impact 3x3 Scenario Matrix", t7A_final)
  add_pub_sheet(wb, "Table 7B", "Table 7B. Provider Impact by Provider Group", t7B_final)
  add_pub_sheet(wb, "Table 7C", "Table 7C. Provider Impact by Provider Class", t7C_final)
  add_pub_sheet(wb, "Table 7D", "Table 7D. Provider-Level Distribution", t7D_final)
  add_pub_sheet(wb, "Table 7E", "Table 7E. Model Coverage and Data Quality Audit", t7E_final)
  add_pub_sheet(wb, "Table 7F", "Table 7F. Exposure-Anomaly Sensitivity", t7F_final)
  add_pub_sheet(wb, "Table 7G", "Table 7G. Access-Protection Policy Options", t7G_final)
  
  # Appendix sheets
  add_pub_sheet(wb, "App 7G Options", "Appendix Table 7G. Access-Protection Options Menu", app7G_options_final)
  add_pub_sheet(wb, "App 7J Transition Rural", "Appendix Table 7J. Provider-Level Transition and Rural Access Sensitivity", app7J_final)
  add_pub_sheet(wb, "App 7K Rural Summary", "Appendix Table 7K. Enhanced Rural Access Sensitivity", app7K_final)
  add_pub_sheet(wb, "App 7L Rural Providers", "Appendix Table 7L. Rural Provider-Level Enhanced Access", app7L_final)
  add_pub_sheet(wb, "App 7M Behavioral Summary", "Appendix Table 7M. Psychiatric / Behavioral Provider Sensitivity", app7M_final)
  add_pub_sheet(wb, "App 7N Behavioral Providers", "Appendix Table 7N. Psychiatric / Behavioral Provider-Level Review", app7N_final)
  add_pub_sheet(wb, "App 7O Behavioral Severe", "Appendix Table 7O. Remaining Severe Psychiatric / Behavioral Effects", app7O_final)
  add_pub_sheet(wb, "App 7P Behavioral Review", "Appendix Table 7P. Behavioral Review Universe", app7P_final)
  
  # Notes sheets
  add_pub_sheet(wb, "Table Notes", "Table 7 Notes", table_notes)
  add_pub_sheet(wb, "Methodology", "Table 7 Methodology Note", data.table::data.table(Note = methodology_note))
  
  openxlsx::saveWorkbook(wb, excel_file, overwrite = TRUE)
  excel_written <- TRUE
}

# ============================================================
# 10. Manifest
# ============================================================

manifest <- data.table::data.table(
  file_type = c(
    rep("main_table_csv", 7),
    rep("appendix_table_csv", 8),
    "notes_csv",
    "methodology_txt",
    "excel_workbook"
  ),
  table_or_file = c(
    "Table 7A",
    "Table 7B",
    "Table 7C",
    "Table 7D",
    "Table 7E",
    "Table 7F",
    "Table 7G",
    "Appendix Table 7G Options",
    "Appendix Table 7J",
    "Appendix Table 7K",
    "Appendix Table 7L",
    "Appendix Table 7M",
    "Appendix Table 7N",
    "Appendix Table 7O",
    "Appendix Table 7P",
    "Table Notes",
    "Methodology Note",
    "All Tables Workbook"
  ),
  path = c(
    out_files$table_7A,
    out_files$table_7B,
    out_files$table_7C,
    out_files$table_7D,
    out_files$table_7E,
    out_files$table_7F,
    out_files$table_7G,
    out_files$appendix_7G_options,
    out_files$appendix_7J,
    out_files$appendix_7K,
    out_files$appendix_7L,
    out_files$appendix_7M,
    out_files$appendix_7N,
    out_files$appendix_7O,
    out_files$appendix_7P,
    out_files$notes,
    out_files$methodology,
    excel_file
  )
)

manifest[, exists := file.exists(path)]

manifest_file <- file.path(pub_dir, "Table_7_Publication_Grade_Manifest.csv")
data.table::fwrite(manifest, manifest_file)

# ============================================================
# 11. Print summary
# ============================================================

cat("\n============================================================\n")
cat("TABLE 7 MAIN AND APPENDIX PUBLICATION EXPORT COMPLETE\n")
cat("============================================================\n\n")

cat("Final output folder:\n")
cat(pub_dir, "\n\n")

cat("Main tables created:\n")
cat("Table 7A\n")
cat("Table 7B\n")
cat("Table 7C\n")
cat("Table 7D\n")
cat("Table 7E\n")
cat("Table 7F\n")
cat("Table 7G\n\n")

cat("Appendix tables created:\n")
cat("Appendix Table 7G Options\n")
cat("Appendix Table 7J\n")
cat("Appendix Table 7K\n")
cat("Appendix Table 7L\n")
cat("Appendix Table 7M\n")
cat("Appendix Table 7N\n")
cat("Appendix Table 7O\n")
cat("Appendix Table 7P\n\n")

if (excel_written == TRUE) {
  cat("Excel workbook:\n")
  cat(excel_file, "\n\n")
}

cat("Manifest:\n")
cat(manifest_file, "\n\n")

cat("Manifest preview:\n")
print(manifest)

cat("\n============================================================\n")