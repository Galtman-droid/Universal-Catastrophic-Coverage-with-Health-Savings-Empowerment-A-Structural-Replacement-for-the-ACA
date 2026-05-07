# Scripts/07_extract_s10_uncompensated_care.R
# Extract HCRIS Worksheet S-10 charity care, bad debt, and uncompensated-care fields
# and merge onto the FY2024 provider master with beds.
#
# Compatible with year-flexible setup from Scripts/00_setup.R
#
# Inputs:
#   Processed/hcris_YYYY_provider_master_with_beds.rds
#   Processed/hcris_YYYY_nmrc.rds
#
# Outputs:
#   Processed/hcris_YYYY_s10_uncompensated_care.rds
#   Processed/hcris_YYYY_provider_master_with_s10.rds
#   Output/hcris_YYYY_s10_uncompensated_care.csv
#   Output/hcris_YYYY_provider_master_with_s10.csv
#   Output/hcris_YYYY_s10_profile.csv
#
# Target fields:
#   S-10 line 23, column 3 = charity care cost, expected
#   S-10 line 29          = bad debt cost, expected
#   S-10 line 30          = uncompensated care cost, expected
#   S-10 line 31          = total unreimbursed + uncompensated care, expected
#
# We extract broadly from S100001 and S100002 first, then validate candidate columns.
# If the exact column differs, the profile output will make that visible.

source("Scripts/00_setup.R")

cat("\n============================================================\n")
cat("EXTRACT HCRIS S-10 UNCOMPENSATED CARE VARIABLES\n")
cat("============================================================\n")
cat("Build year:", hcris_year_label, "\n\n")

# ============================================================
# 1. Load inputs
# ============================================================

provider_base_file <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_provider_master_with_beds.rds")
)

nmrc_file <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_nmrc.rds")
)

if (!file.exists(provider_base_file)) {
  stop("Missing provider master with beds file: ", provider_base_file)
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
  stop(
    "Provider base missing required columns:\n",
    paste(missing_provider, collapse = "\n")
  )
}

if (length(missing_nmrc) > 0) {
  stop(
    "NMRC missing required columns:\n",
    paste(missing_nmrc, collapse = "\n")
  )
}

# ============================================================
# 3. Included provider universe
# ============================================================

included_providers <- provider_base[
  provider_backbone_include_v1 == TRUE,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    city,
    state_abbrev,
    provider_model_class,
    facility_type
  )
]

cat("\nBackbone-included providers:", nrow(included_providers), "\n")
print(included_providers[, .N, by = provider_model_class][order(-N)])

# ============================================================
# 4. Extract S-10 candidate numeric fields
# ============================================================

s10_long <- nmrc[
  rpt_rec_num %in% included_providers$rpt_rec_num &
    wksht_cd %in% c("S100001", "S100002") &
    line_num_chr >= "00100" &
    line_num_chr <= "04000" &
    !is.na(itm_val_num),
  .(
    rpt_rec_num,
    wksht_cd,
    line_num_chr,
    clmn_num_chr,
    itm_val_num
  )
]

s10_long <- merge(
  s10_long,
  included_providers,
  by = "rpt_rec_num",
  all.x = TRUE
)

cat("\nS-10 candidate rows:", nrow(s10_long), "\n")
cat("S-10 candidate reports:", data.table::uniqueN(s10_long$rpt_rec_num), "\n")

# ============================================================
# 5. Profile S-10 fields
# ============================================================

s10_profile <- s10_long[
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
  by = .(wksht_cd, line_num_chr, clmn_num_chr)
][order(wksht_cd, line_num_chr, clmn_num_chr)]

for (cc in c("min_value", "p25_value", "median_value", "mean_value", "p75_value", "max_value")) {
  s10_profile[
    is.infinite(get(cc)),
    (cc) := NA_real_
  ]
}

s10_profile_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_s10_profile.csv")
)

data.table::fwrite(s10_profile, s10_profile_csv)

cat("\nS-10 profile around target lines 02300, 02900, 03000, 03100:\n")
print(s10_profile[
  line_num_chr %in% c("02300", "02900", "03000", "03100")
][order(wksht_cd, line_num_chr, clmn_num_chr)])

cat("\nS-10 profile first 150 rows:\n")
print(s10_profile[1:150])

# ============================================================
# 6. Create wide S-10 table
# ============================================================

s10_long[
  ,
  field_key := paste0(wksht_cd, "_L", line_num_chr, "_C", clmn_num_chr)
]

s10_wide_long <- s10_long[
  ,
  .(
    value = suppressWarnings(sum(itm_val_num, na.rm = TRUE))
  ),
  by = .(rpt_rec_num, field_key)
]

s10_wide <- data.table::dcast(
  s10_wide_long,
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
      out <- data.table::fifelse(
        is.na(out),
        v,
        out
      )
    }
  }
  
  out
}

# ============================================================
# 8. Extract expected S-10 fields
# ============================================================

s10 <- copy(s10_wide)

# Charity care cost:
# expected S-10 line 23, column 3.
s10[
  ,
  charity_care_cost :=
    coalesce_numeric(
      get_existing_numeric(s10, "S100001_L02300_C00300"),
      get_existing_numeric(s10, "S100002_L02300_C00300")
    )
]

# Bad debt cost:
# expected line 29; column may vary, so retain multiple candidates.
s10[
  ,
  bad_debt_cost :=
    coalesce_numeric(
      get_existing_numeric(s10, "S100001_L02900_C00100"),
      get_existing_numeric(s10, "S100001_L02900_C00200"),
      get_existing_numeric(s10, "S100001_L02900_C00300"),
      get_existing_numeric(s10, "S100002_L02900_C00100"),
      get_existing_numeric(s10, "S100002_L02900_C00200"),
      get_existing_numeric(s10, "S100002_L02900_C00300")
    )
]

# Uncompensated care cost:
# expected line 30.
s10[
  ,
  uncompensated_care_cost :=
    coalesce_numeric(
      get_existing_numeric(s10, "S100001_L03000_C00100"),
      get_existing_numeric(s10, "S100001_L03000_C00200"),
      get_existing_numeric(s10, "S100001_L03000_C00300"),
      get_existing_numeric(s10, "S100002_L03000_C00100"),
      get_existing_numeric(s10, "S100002_L03000_C00200"),
      get_existing_numeric(s10, "S100002_L03000_C00300")
    )
]

# Total unreimbursed + uncompensated care:
# expected line 31.
s10[
  ,
  total_unreimbursed_and_uncompensated_cost :=
    coalesce_numeric(
      get_existing_numeric(s10, "S100001_L03100_C00100"),
      get_existing_numeric(s10, "S100001_L03100_C00200"),
      get_existing_numeric(s10, "S100001_L03100_C00300"),
      get_existing_numeric(s10, "S100002_L03100_C00100"),
      get_existing_numeric(s10, "S100002_L03100_C00200"),
      get_existing_numeric(s10, "S100002_L03100_C00300")
    )
]

# Replace true missing with NA, but keep zero as zero.
s10_core <- s10[
  ,
  .(
    rpt_rec_num,
    charity_care_cost,
    bad_debt_cost,
    uncompensated_care_cost,
    total_unreimbursed_and_uncompensated_cost
  )
]

# ============================================================
# 9. Validation equations / diagnostic checks
# ============================================================

# Expected identity in many S-10 structures:
# uncompensated care cost should be charity care cost + bad debt cost,
# or close to it, depending on worksheet definitions and additional adjustments.
s10_core[
  ,
  charity_plus_bad_debt :=
    fifelse(is.na(charity_care_cost), 0, charity_care_cost) +
    fifelse(is.na(bad_debt_cost), 0, bad_debt_cost)
]

s10_core[
  ,
  uc_minus_charity_bad_debt :=
    uncompensated_care_cost - charity_plus_bad_debt
]

s10_core[
  ,
  s10_any_data_flag :=
    !is.na(charity_care_cost) |
    !is.na(bad_debt_cost) |
    !is.na(uncompensated_care_cost) |
    !is.na(total_unreimbursed_and_uncompensated_cost)
]

s10_core[
  ,
  s10_core_complete_flag :=
    !is.na(uncompensated_care_cost) &
    !is.na(bad_debt_cost)
]

s10_core[
  ,
  uc_nonnegative_flag :=
    !is.na(uncompensated_care_cost) &
    uncompensated_care_cost >= 0
]

s10_core[
  ,
  bad_debt_nonnegative_flag :=
    !is.na(bad_debt_cost) &
    bad_debt_cost >= 0
]

s10_core[
  ,
  charity_nonnegative_flag :=
    !is.na(charity_care_cost) &
    charity_care_cost >= 0
]

s10_core[
  ,
  s10_use_for_model_flag :=
    s10_any_data_flag == TRUE &
    uc_nonnegative_flag == TRUE
]

# ============================================================
# 10. Merge with provider base
# ============================================================

provider_master_with_s10 <- merge(
  provider_base,
  s10_core,
  by = "rpt_rec_num",
  all.x = TRUE
)

flag_cols <- c(
  "s10_any_data_flag",
  "s10_core_complete_flag",
  "uc_nonnegative_flag",
  "bad_debt_nonnegative_flag",
  "charity_nonnegative_flag",
  "s10_use_for_model_flag"
)

for (fc in flag_cols) {
  provider_master_with_s10[
    is.na(get(fc)),
    (fc) := FALSE
  ]
}

# For model arithmetic later, keep raw and zero-filled versions separately.
provider_master_with_s10[
  ,
  charity_care_cost_model :=
    fifelse(is.na(charity_care_cost), 0, charity_care_cost)
]

provider_master_with_s10[
  ,
  bad_debt_cost_model :=
    fifelse(is.na(bad_debt_cost), 0, bad_debt_cost)
]

provider_master_with_s10[
  ,
  uncompensated_care_cost_model :=
    fifelse(is.na(uncompensated_care_cost), 0, uncompensated_care_cost)
]

provider_master_with_s10[
  ,
  total_unreimbursed_and_uncompensated_cost_model :=
    fifelse(
      is.na(total_unreimbursed_and_uncompensated_cost),
      0,
      total_unreimbursed_and_uncompensated_cost
    )
]

# ============================================================
# 11. Save outputs
# ============================================================

s10_rds <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_s10_uncompensated_care.rds")
)

provider_s10_rds <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_provider_master_with_s10.rds")
)

s10_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_s10_uncompensated_care.csv")
)

provider_s10_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_provider_master_with_s10.csv")
)

saveRDS(s10_core, s10_rds)
saveRDS(provider_master_with_s10, provider_s10_rds)

data.table::fwrite(s10_core, s10_csv)
data.table::fwrite(provider_master_with_s10, provider_s10_csv)

# ============================================================
# 12. Print summaries
# ============================================================

cat("\n============================================================\n")
cat("S-10 EXTRACTION COMPLETE\n")
cat("============================================================\n")

cat("\nRows in S-10 core table:", nrow(s10_core), "\n")
cat("Rows in provider master with S-10:", nrow(provider_master_with_s10), "\n")

cat("\nS-10 data availability, all reports:\n")
print(provider_master_with_s10[
  ,
  .N,
  by = s10_any_data_flag
][order(s10_any_data_flag)])

cat("\nS-10 data availability, backbone-included reports:\n")
print(provider_master_with_s10[
  provider_backbone_include_v1 == TRUE,
  .N,
  by = s10_any_data_flag
][order(s10_any_data_flag)])

cat("\nS-10 completeness / model usability, backbone-included reports:\n")
print(provider_master_with_s10[
  provider_backbone_include_v1 == TRUE,
  .(
    providers = .N,
    s10_any_data = sum(s10_any_data_flag, na.rm = TRUE),
    s10_core_complete = sum(s10_core_complete_flag, na.rm = TRUE),
    uc_nonnegative = sum(uc_nonnegative_flag, na.rm = TRUE),
    bad_debt_nonnegative = sum(bad_debt_nonnegative_flag, na.rm = TRUE),
    charity_nonnegative = sum(charity_nonnegative_flag, na.rm = TRUE),
    s10_use_for_model = sum(s10_use_for_model_flag, na.rm = TRUE)
  )
])

cat("\nS-10 totals by provider class, backbone-included:\n")
print(provider_master_with_s10[
  provider_backbone_include_v1 == TRUE,
  .(
    providers = .N,
    s10_any_data = sum(s10_any_data_flag, na.rm = TRUE),
    s10_use_for_model = sum(s10_use_for_model_flag, na.rm = TRUE),
    
    total_charity_care_cost =
      sum(charity_care_cost_model, na.rm = TRUE),
    
    total_bad_debt_cost =
      sum(bad_debt_cost_model, na.rm = TRUE),
    
    total_uncompensated_care_cost =
      sum(uncompensated_care_cost_model, na.rm = TRUE),
    
    total_unreimbursed_and_uncompensated_cost =
      sum(total_unreimbursed_and_uncompensated_cost_model, na.rm = TRUE),
    
    median_uncompensated_care_cost =
      median(uncompensated_care_cost, na.rm = TRUE),
    
    mean_uncompensated_care_cost =
      mean(uncompensated_care_cost, na.rm = TRUE)
  ),
  by = provider_model_class
][order(-providers)])

cat("\nDistribution of uncompensated care cost, backbone-included with S-10 model data:\n")
print(summary(provider_master_with_s10[
  provider_backbone_include_v1 == TRUE &
    s10_use_for_model_flag == TRUE,
  uncompensated_care_cost
]))

cat("\nLargest uncompensated-care cost providers, backbone-included:\n")
print(provider_master_with_s10[
  provider_backbone_include_v1 == TRUE &
    s10_use_for_model_flag == TRUE,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    city,
    state_abbrev,
    provider_model_class,
    charity_care_cost,
    bad_debt_cost,
    uncompensated_care_cost,
    total_unreimbursed_and_uncompensated_cost,
    uc_minus_charity_bad_debt
  )
][order(-uncompensated_care_cost)][1:30])

cat("\nS-10 validation: UC minus charity+bad debt, backbone-included:\n")
print(summary(provider_master_with_s10[
  provider_backbone_include_v1 == TRUE &
    s10_use_for_model_flag == TRUE,
  uc_minus_charity_bad_debt
]))

cat("\nPotential S-10 negative-value checks, backbone-included:\n")

negative_s10 <- provider_master_with_s10[
  provider_backbone_include_v1 == TRUE &
    (
      (!is.na(charity_care_cost) & charity_care_cost < 0) |
        (!is.na(bad_debt_cost) & bad_debt_cost < 0) |
        (!is.na(uncompensated_care_cost) & uncompensated_care_cost < 0)
    ),
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    provider_model_class,
    charity_care_cost,
    bad_debt_cost,
    uncompensated_care_cost
  )
]

if (nrow(negative_s10) == 0) {
  cat("None\n")
} else {
  print(negative_s10[1:50])
}

cat("\nSample backbone-included providers with S-10:\n")
print(provider_master_with_s10[
  provider_backbone_include_v1 == TRUE,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    city,
    state_abbrev,
    provider_model_class,
    charity_care_cost,
    bad_debt_cost,
    uncompensated_care_cost,
    total_unreimbursed_and_uncompensated_cost,
    s10_any_data_flag,
    s10_use_for_model_flag
  )
][1:30])

cat("\nSaved:\n")
cat(s10_rds, "\n")
cat(provider_s10_rds, "\n")
cat(s10_csv, "\n")
cat(provider_s10_csv, "\n")
cat(s10_profile_csv, "\n")

cat("\n============================================================\n")