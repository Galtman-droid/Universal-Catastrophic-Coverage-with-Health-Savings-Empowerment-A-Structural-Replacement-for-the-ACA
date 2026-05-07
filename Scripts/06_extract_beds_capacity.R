# Scripts/06_extract_beds_capacity.R
# Extract hospital beds / bed-days / validated utilization capacity fields from HCRIS NMRC
# and merge onto the FY2024 provider master.
#
# Compatible with year-flexible setup from Scripts/00_setup.R
#
# Inputs:
#   Processed/hcris_YYYY_provider_master.rds
#   Processed/hcris_YYYY_nmrc.rds
#
# Outputs:
#   Processed/hcris_YYYY_beds_capacity.rds
#   Processed/hcris_YYYY_provider_master_with_beds.rds
#   Output/hcris_YYYY_beds_capacity.csv
#   Output/hcris_YYYY_provider_master_with_beds.csv
#   Output/hcris_YYYY_beds_capacity_profile.csv
#
# Confirmed FY2024 S-3 Part I capacity mapping:
#   S300001 L00100 C00200 = adult/peds beds
#   S300001 L00100 C00300 = adult/peds bed-days available
#   S300001 L00100 C00800 = adult/peds inpatient/patient days candidate
#   S300001 L00100 C00600 = adult/peds discharges candidate
#   S300001 L00100 C00700 = adult/peds utilization context field
#
#   S300001 L01400 C00200 = total hospital beds
#   S300001 L01400 C00300 = total hospital bed-days available
#   S300001 L01400 C00800 = validated total hospital inpatient/patient days
#   S300001 L01400 C00600 = validated total hospital discharges
#   S300001 L01400 C00700 = utilization context field
#   S300001 L01400 C01000 = reported utilization/ALOS-related metric
#
# Validation note:
#   Script 06B identified L01400_C00800 paired with L01400_C00600 as the most
#   credible total utilization mapping. The pair produced realistic aggregate
#   occupancy and ALOS values:
#     weighted occupancy ~0.708
#     weighted ALOS ~5.42
#     median occupancy ~0.618
#     median ALOS ~4.24
#
# We use line 01400 as the preferred total hospital line when present,
# and fall back to line 00100 when line 01400 is missing.

source("Scripts/00_setup.R")

cat("\n============================================================\n")
cat("EXTRACT HCRIS BEDS / CAPACITY VARIABLES\n")
cat("============================================================\n")
cat("Build year:", hcris_year_label, "\n\n")

# ============================================================
# 1. Load inputs
# ============================================================

provider_master_file <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_provider_master.rds")
)

nmrc_file <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_nmrc.rds")
)

if (!file.exists(provider_master_file)) {
  stop("Missing provider master file: ", provider_master_file)
}

if (!file.exists(nmrc_file)) {
  stop("Missing NMRC file: ", nmrc_file)
}

provider_master <- readRDS(provider_master_file)
nmrc <- readRDS(nmrc_file)

cat("Loaded:\n")
cat(provider_master_file, "\n")
cat(nmrc_file, "\n")

cat("\nProvider master rows:", nrow(provider_master), "\n")
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

missing_provider <- setdiff(required_provider_cols, names(provider_master))
missing_nmrc <- setdiff(required_nmrc_cols, names(nmrc))

if (length(missing_provider) > 0) {
  stop(
    "Provider master missing required columns:\n",
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

included_providers <- provider_master[
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
# 4. Extract S-3 Part I capacity block
# ============================================================

s3_capacity_long <- nmrc[
  rpt_rec_num %in% included_providers$rpt_rec_num &
    wksht_cd == "S300001" &
    line_num_chr >= "00100" &
    line_num_chr <= "02000" &
    !is.na(itm_val_num)
]

s3_capacity_long <- merge(
  s3_capacity_long,
  included_providers,
  by = "rpt_rec_num",
  all.x = TRUE
)

# ============================================================
# 5. Profile S-3 block
# ============================================================

s3_profile <- s3_capacity_long[
  ,
  .(
    n_rows = .N,
    n_reports = data.table::uniqueN(rpt_rec_num),
    nonmissing_values = sum(!is.na(itm_val_num)),
    min_value = suppressWarnings(min(itm_val_num, na.rm = TRUE)),
    median_value = suppressWarnings(median(itm_val_num, na.rm = TRUE)),
    mean_value = suppressWarnings(mean(itm_val_num, na.rm = TRUE)),
    max_value = suppressWarnings(max(itm_val_num, na.rm = TRUE))
  ),
  by = .(wksht_cd, line_num_chr, clmn_num_chr)
][order(line_num_chr, clmn_num_chr)]

for (cc in c("min_value", "median_value", "mean_value", "max_value")) {
  s3_profile[
    is.infinite(get(cc)),
    (cc) := NA_real_
  ]
}

profile_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_beds_capacity_profile.csv")
)

data.table::fwrite(s3_profile, profile_csv)

cat("\nS-3 capacity profile, first 150 rows:\n")
print(s3_profile[1:150])

# ============================================================
# 6. Create wide S-3 table
# ============================================================

s3_capacity_long[
  ,
  field_key := paste0("S300001_L", line_num_chr, "_C", clmn_num_chr)
]

s3_wide_long <- s3_capacity_long[
  ,
  .(
    value = suppressWarnings(sum(itm_val_num, na.rm = TRUE))
  ),
  by = .(rpt_rec_num, field_key)
]

s3_capacity_wide <- data.table::dcast(
  s3_wide_long,
  rpt_rec_num ~ field_key,
  value.var = "value"
)

# ============================================================
# 7. Helper functions
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
        is.na(out) | out == 0,
        v,
        out
      )
    }
  }
  
  out
}

# ============================================================
# 8. Extract corrected capacity and utilization fields
# ============================================================

beds_capacity <- copy(s3_capacity_wide)

# -----------------------------
# Adult/peds line: S300001 L00100
# -----------------------------

beds_capacity[
  ,
  adult_peds_beds :=
    get_existing_numeric(beds_capacity, "S300001_L00100_C00200")
]

beds_capacity[
  ,
  adult_peds_bed_days_available :=
    get_existing_numeric(beds_capacity, "S300001_L00100_C00300")
]

beds_capacity[
  ,
  adult_peds_inpatient_days :=
    get_existing_numeric(beds_capacity, "S300001_L00100_C00800")
]

beds_capacity[
  ,
  adult_peds_discharges :=
    get_existing_numeric(beds_capacity, "S300001_L00100_C00600")
]

beds_capacity[
  ,
  adult_peds_utilization_context_c007 :=
    get_existing_numeric(beds_capacity, "S300001_L00100_C00700")
]

beds_capacity[
  ,
  adult_peds_utilization_context_c015 :=
    get_existing_numeric(beds_capacity, "S300001_L00100_C01500")
]

# -----------------------------
# Total hospital line: S300001 L01400
# -----------------------------

beds_capacity[
  ,
  total_line_beds :=
    get_existing_numeric(beds_capacity, "S300001_L01400_C00200")
]

beds_capacity[
  ,
  total_line_bed_days_available :=
    get_existing_numeric(beds_capacity, "S300001_L01400_C00300")
]

beds_capacity[
  ,
  total_line_inpatient_days :=
    get_existing_numeric(beds_capacity, "S300001_L01400_C00800")
]

beds_capacity[
  ,
  total_line_discharges :=
    get_existing_numeric(beds_capacity, "S300001_L01400_C00600")
]

beds_capacity[
  ,
  total_line_utilization_context_c007 :=
    get_existing_numeric(beds_capacity, "S300001_L01400_C00700")
]

beds_capacity[
  ,
  total_line_utilization_context_c015 :=
    get_existing_numeric(beds_capacity, "S300001_L01400_C01500")
]

beds_capacity[
  ,
  total_line_reported_alos_metric :=
    get_existing_numeric(beds_capacity, "S300001_L01400_C01000")
]

# -----------------------------
# Preferred hospital fields:
# use total line if present; otherwise adult/peds fallback.
# -----------------------------

beds_capacity[
  ,
  hospital_beds :=
    coalesce_numeric(total_line_beds, adult_peds_beds)
]

beds_capacity[
  ,
  hospital_bed_days_available :=
    coalesce_numeric(total_line_bed_days_available, adult_peds_bed_days_available)
]

beds_capacity[
  ,
  hospital_inpatient_days :=
    coalesce_numeric(total_line_inpatient_days, adult_peds_inpatient_days)
]

beds_capacity[
  ,
  hospital_discharges :=
    coalesce_numeric(total_line_discharges, adult_peds_discharges)
]

beds_capacity[
  ,
  hospital_utilization_context_c007 :=
    coalesce_numeric(
      total_line_utilization_context_c007,
      adult_peds_utilization_context_c007
    )
]

beds_capacity[
  ,
  hospital_utilization_context_c015 :=
    coalesce_numeric(
      total_line_utilization_context_c015,
      adult_peds_utilization_context_c015
    )
]

# -----------------------------
# Derived metrics
# -----------------------------

beds_capacity[
  ,
  occupancy_rate :=
    hospital_inpatient_days / hospital_bed_days_available
]

beds_capacity[
  ,
  average_length_of_stay :=
    hospital_inpatient_days / hospital_discharges
]

# -----------------------------
# Validation flags
# -----------------------------

beds_capacity[
  ,
  beds_capacity_complete_flag :=
    !is.na(hospital_beds) &
    hospital_beds > 0 &
    !is.na(hospital_bed_days_available) &
    hospital_bed_days_available > 0
]

beds_capacity[
  ,
  utilization_complete_flag :=
    beds_capacity_complete_flag == TRUE &
    !is.na(hospital_inpatient_days) &
    hospital_inpatient_days >= 0 &
    !is.na(hospital_discharges) &
    hospital_discharges > 0
]

beds_capacity[
  ,
  occupancy_rate_plausible_flag :=
    utilization_complete_flag == TRUE &
    !is.na(occupancy_rate) &
    occupancy_rate >= 0 &
    occupancy_rate <= 1.05
]

beds_capacity[
  ,
  average_length_of_stay_plausible_flag :=
    utilization_complete_flag == TRUE &
    !is.na(average_length_of_stay) &
    average_length_of_stay >= 1 &
    average_length_of_stay <= 30
]

beds_capacity[
  ,
  utilization_plausible_flag :=
    utilization_complete_flag == TRUE &
    occupancy_rate_plausible_flag == TRUE &
    average_length_of_stay_plausible_flag == TRUE
]

beds_capacity[
  ,
  bed_days_consistent_with_beds_flag :=
    !is.na(hospital_beds) &
    !is.na(hospital_bed_days_available) &
    hospital_beds > 0 &
    hospital_bed_days_available > 0 &
    hospital_bed_days_available >= hospital_beds * 300 &
    hospital_bed_days_available <= hospital_beds * 370
]

# ============================================================
# 9. Merge with provider master
# ============================================================

capacity_core <- beds_capacity[
  ,
  .(
    rpt_rec_num,
    
    adult_peds_beds,
    adult_peds_bed_days_available,
    adult_peds_inpatient_days,
    adult_peds_discharges,
    adult_peds_utilization_context_c007,
    adult_peds_utilization_context_c015,
    
    total_line_beds,
    total_line_bed_days_available,
    total_line_inpatient_days,
    total_line_discharges,
    total_line_utilization_context_c007,
    total_line_utilization_context_c015,
    total_line_reported_alos_metric,
    
    hospital_beds,
    hospital_bed_days_available,
    hospital_inpatient_days,
    hospital_discharges,
    hospital_utilization_context_c007,
    hospital_utilization_context_c015,
    
    occupancy_rate,
    average_length_of_stay,
    
    beds_capacity_complete_flag,
    utilization_complete_flag,
    occupancy_rate_plausible_flag,
    average_length_of_stay_plausible_flag,
    utilization_plausible_flag,
    bed_days_consistent_with_beds_flag
  )
]

provider_master_with_beds <- merge(
  provider_master,
  capacity_core,
  by = "rpt_rec_num",
  all.x = TRUE
)

flag_cols <- c(
  "beds_capacity_complete_flag",
  "utilization_complete_flag",
  "occupancy_rate_plausible_flag",
  "average_length_of_stay_plausible_flag",
  "utilization_plausible_flag",
  "bed_days_consistent_with_beds_flag"
)

for (fc in flag_cols) {
  provider_master_with_beds[
    is.na(get(fc)),
    (fc) := FALSE
  ]
}

# ============================================================
# 10. Save outputs
# ============================================================

beds_capacity_rds <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_beds_capacity.rds")
)

provider_master_with_beds_rds <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_provider_master_with_beds.rds")
)

beds_capacity_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_beds_capacity.csv")
)

provider_master_with_beds_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_provider_master_with_beds.csv")
)

saveRDS(beds_capacity, beds_capacity_rds)
saveRDS(provider_master_with_beds, provider_master_with_beds_rds)

data.table::fwrite(beds_capacity, beds_capacity_csv)
data.table::fwrite(provider_master_with_beds, provider_master_with_beds_csv)

# ============================================================
# 11. Print summaries
# ============================================================

cat("\n============================================================\n")
cat("BEDS / CAPACITY EXTRACTION COMPLETE\n")
cat("============================================================\n")

cat("\nRows in beds capacity table:", nrow(beds_capacity), "\n")
cat("Rows in provider master with beds:", nrow(provider_master_with_beds), "\n")

cat("\nBeds/capacity completion, all reports:\n")
print(provider_master_with_beds[
  ,
  .N,
  by = beds_capacity_complete_flag
][order(beds_capacity_complete_flag)])

cat("\nBeds/capacity completion, backbone-included reports:\n")
print(provider_master_with_beds[
  provider_backbone_include_v1 == TRUE,
  .N,
  by = beds_capacity_complete_flag
][order(beds_capacity_complete_flag)])

cat("\nUtilization completion/plausibility, backbone-included reports:\n")
print(provider_master_with_beds[
  provider_backbone_include_v1 == TRUE,
  .(
    providers = .N,
    beds_complete = sum(beds_capacity_complete_flag, na.rm = TRUE),
    utilization_complete = sum(utilization_complete_flag, na.rm = TRUE),
    occupancy_plausible = sum(occupancy_rate_plausible_flag, na.rm = TRUE),
    alos_plausible = sum(average_length_of_stay_plausible_flag, na.rm = TRUE),
    utilization_plausible = sum(utilization_plausible_flag, na.rm = TRUE),
    bed_days_consistent = sum(bed_days_consistent_with_beds_flag, na.rm = TRUE)
  )
])

cat("\nBeds/capacity and utilization by provider class, backbone-included:\n")
print(provider_master_with_beds[
  provider_backbone_include_v1 == TRUE,
  .(
    providers = .N,
    complete_beds_capacity = sum(beds_capacity_complete_flag, na.rm = TRUE),
    missing_beds_capacity = sum(!beds_capacity_complete_flag, na.rm = TRUE),
    utilization_complete = sum(utilization_complete_flag, na.rm = TRUE),
    utilization_plausible = sum(utilization_plausible_flag, na.rm = TRUE),
    
    total_beds = sum(hospital_beds, na.rm = TRUE),
    median_beds = median(hospital_beds, na.rm = TRUE),
    
    total_bed_days_available = sum(hospital_bed_days_available, na.rm = TRUE),
    total_inpatient_days = sum(hospital_inpatient_days, na.rm = TRUE),
    total_discharges = sum(hospital_discharges, na.rm = TRUE),
    
    weighted_occupancy_rate =
      sum(hospital_inpatient_days, na.rm = TRUE) /
      sum(hospital_bed_days_available, na.rm = TRUE),
    
    weighted_average_length_of_stay =
      sum(hospital_inpatient_days, na.rm = TRUE) /
      sum(hospital_discharges, na.rm = TRUE),
    
    median_occupancy_rate = median(occupancy_rate, na.rm = TRUE),
    median_average_length_of_stay = median(average_length_of_stay, na.rm = TRUE)
  ),
  by = provider_model_class
][order(-providers)])

cat("\nDistribution of hospital beds, backbone-included with capacity complete:\n")
print(summary(provider_master_with_beds[
  provider_backbone_include_v1 == TRUE &
    beds_capacity_complete_flag == TRUE,
  hospital_beds
]))

cat("\nDistribution of occupancy rate, backbone-included with utilization complete:\n")
print(summary(provider_master_with_beds[
  provider_backbone_include_v1 == TRUE &
    utilization_complete_flag == TRUE,
  occupancy_rate
]))

cat("\nDistribution of average length of stay, backbone-included with utilization complete:\n")
print(summary(provider_master_with_beds[
  provider_backbone_include_v1 == TRUE &
    utilization_complete_flag == TRUE,
  average_length_of_stay
]))

cat("\nSample backbone-included providers with beds/utilization:\n")
print(provider_master_with_beds[
  provider_backbone_include_v1 == TRUE,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    city,
    state_abbrev,
    provider_model_class,
    hospital_beds,
    hospital_bed_days_available,
    hospital_inpatient_days,
    hospital_discharges,
    occupancy_rate,
    average_length_of_stay,
    total_line_reported_alos_metric,
    beds_capacity_complete_flag,
    utilization_complete_flag,
    utilization_plausible_flag
  )
][1:30])

cat("\nPotential mapping checks / outliers:\n")

cat("\nProviders with occupancy_rate > 1.05 among backbone-included:\n")
occ_outliers <- provider_master_with_beds[
  provider_backbone_include_v1 == TRUE &
    utilization_complete_flag == TRUE &
    occupancy_rate > 1.05,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    provider_model_class,
    hospital_beds,
    hospital_bed_days_available,
    hospital_inpatient_days,
    hospital_discharges,
    occupancy_rate,
    average_length_of_stay
  )
]

if (nrow(occ_outliers) == 0) {
  cat("None\n")
} else {
  print(occ_outliers[1:50])
}

cat("\nProviders with average_length_of_stay < 1 or > 30 among backbone-included:\n")
alos_outliers <- provider_master_with_beds[
  provider_backbone_include_v1 == TRUE &
    utilization_complete_flag == TRUE &
    (average_length_of_stay < 1 | average_length_of_stay > 30),
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    provider_model_class,
    hospital_beds,
    hospital_bed_days_available,
    hospital_inpatient_days,
    hospital_discharges,
    occupancy_rate,
    average_length_of_stay
  )
]

if (nrow(alos_outliers) == 0) {
  cat("None\n")
} else {
  print(alos_outliers[1:50])
}

cat("\nProviders with hospital_beds > 2000 among backbone-included:\n")
bed_outliers <- provider_master_with_beds[
  provider_backbone_include_v1 == TRUE &
    beds_capacity_complete_flag == TRUE &
    hospital_beds > 2000,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    provider_model_class,
    hospital_beds,
    hospital_bed_days_available,
    hospital_inpatient_days,
    occupancy_rate
  )
]

if (nrow(bed_outliers) == 0) {
  cat("None\n")
} else {
  print(bed_outliers[1:50])
}

cat("\nSaved:\n")
cat(beds_capacity_rds, "\n")
cat(provider_master_with_beds_rds, "\n")
cat(beds_capacity_csv, "\n")
cat(provider_master_with_beds_csv, "\n")
cat(profile_csv, "\n")

cat("\n============================================================\n")