# Scripts/06B_validate_S3_utilization_mapping.R
# Validate HCRIS Worksheet S-3 Part I utilization mapping.
#
# Purpose:
#   We already validated that:
#     S300001 L01400 C00200 = total beds
#     S300001 L01400 C00300 = total bed-days available
#
#   But the prior mapping for:
#     inpatient days
#     discharges
#     occupancy rate
#     average length of stay
#   produced implausible values.
#
# This script systematically inspects S300001 columns and identifies which columns
# produce plausible utilization metrics when paired with validated beds and
# bed-days available.
#
# Inputs:
#   Processed/hcris_YYYY_provider_master.rds
#   Processed/hcris_YYYY_nmrc.rds
#
# Outputs:
#   Output/hcris_YYYY_S3_utilization_candidate_metrics.csv
#   Output/hcris_YYYY_S3_utilization_candidate_summary.csv
#   Output/hcris_YYYY_S3_utilization_candidate_sample.csv

source("Scripts/00_setup.R")

cat("\n============================================================\n")
cat("VALIDATE S-3 UTILIZATION MAPPING\n")
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

included <- provider_master[
  provider_backbone_include_v1 == TRUE,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    city,
    state_abbrev,
    provider_model_class
  )
]

cat("Backbone-included providers:", nrow(included), "\n")
print(included[, .N, by = provider_model_class][order(-N)])

# ============================================================
# 2. Create wide S300001 table for included providers
# ============================================================

s3_long <- nmrc[
  rpt_rec_num %in% included$rpt_rec_num &
    wksht_cd == "S300001" &
    line_num_chr >= "00100" &
    line_num_chr <= "02000" &
    !is.na(itm_val_num),
  .(
    rpt_rec_num,
    line_num_chr,
    clmn_num_chr,
    value = itm_val_num
  )
]

s3_long[
  ,
  field_key := paste0("L", line_num_chr, "_C", clmn_num_chr)
]

s3_wide <- data.table::dcast(
  s3_long,
  rpt_rec_num ~ field_key,
  value.var = "value",
  fun.aggregate = sum,
  fill = NA_real_
)

s3_wide <- merge(
  included,
  s3_wide,
  by = "rpt_rec_num",
  all.x = TRUE
)

# ============================================================
# 3. Validated beds / bed-days base
# ============================================================

get_num <- function(dt, colname) {
  if (colname %in% names(dt)) {
    return(as.numeric(dt[[colname]]))
  }
  rep(NA_real_, nrow(dt))
}

coalesce_num <- function(a, b) {
  data.table::fifelse(is.na(a) | a == 0, b, a)
}

# Preferred total line is L01400. Fallback is L00100.
s3_wide[
  ,
  validated_beds :=
    coalesce_num(
      get_num(s3_wide, "L01400_C00200"),
      get_num(s3_wide, "L00100_C00200")
    )
]

s3_wide[
  ,
  validated_bed_days_available :=
    coalesce_num(
      get_num(s3_wide, "L01400_C00300"),
      get_num(s3_wide, "L00100_C00300")
    )
]

s3_wide[
  ,
  bed_base_valid :=
    !is.na(validated_beds) &
    validated_beds > 0 &
    !is.na(validated_bed_days_available) &
    validated_bed_days_available > 0 &
    validated_bed_days_available >= validated_beds * 300 &
    validated_bed_days_available <= validated_beds * 370
]

cat("\nValidated bed base:\n")
print(s3_wide[, .N, by = bed_base_valid][order(bed_base_valid)])

# ============================================================
# 4. Build candidate utilization columns
# ============================================================

# Candidate utilization fields from lines that appear to contain total or subtotal
# utilization fields.
candidate_fields <- grep(
  "^L(00100|00700|01400|01500)_C[0-9]{5}$",
  names(s3_wide),
  value = TRUE
)

# Exclude known non-utilization / structural fields.
candidate_fields <- setdiff(
  candidate_fields,
  c(
    "L00100_C00100",
    "L00100_C00200",
    "L00100_C00300",
    "L00700_C00100",
    "L00700_C00200",
    "L00700_C00300",
    "L01400_C00100",
    "L01400_C00200",
    "L01400_C00300",
    "L01500_C00100",
    "L01500_C00200",
    "L01500_C00300"
  )
)

cat("\nCandidate utilization fields:\n")
print(candidate_fields)

# ============================================================
# 5. Evaluate each candidate as inpatient-days field
# ============================================================

candidate_metrics_list <- list()

for (field in candidate_fields) {
  tmp <- copy(s3_wide)
  
  tmp[
    ,
    candidate_field := field
  ]
  
  tmp[
    ,
    candidate_value := get_num(tmp, field)
  ]
  
  tmp[
    ,
    implied_occupancy :=
      candidate_value / validated_bed_days_available
  ]
  
  tmp[
    ,
    plausible_inpatient_days :=
      bed_base_valid == TRUE &
      !is.na(candidate_value) &
      candidate_value >= 0 &
      candidate_value <= validated_bed_days_available * 1.05 &
      implied_occupancy >= 0 &
      implied_occupancy <= 1.05
  ]
  
  candidate_summary <- tmp[
    bed_base_valid == TRUE,
    .(
      providers_with_value = sum(!is.na(candidate_value)),
      providers_plausible = sum(plausible_inpatient_days, na.rm = TRUE),
      pct_plausible_among_with_value =
        sum(plausible_inpatient_days, na.rm = TRUE) /
        sum(!is.na(candidate_value)),
      
      total_candidate_value = sum(candidate_value, na.rm = TRUE),
      total_bed_days_available = sum(validated_bed_days_available, na.rm = TRUE),
      implied_weighted_occupancy =
        sum(candidate_value, na.rm = TRUE) /
        sum(validated_bed_days_available, na.rm = TRUE),
      
      median_candidate_value = median(candidate_value, na.rm = TRUE),
      median_implied_occupancy = median(implied_occupancy, na.rm = TRUE),
      p25_implied_occupancy =
        as.numeric(quantile(implied_occupancy, 0.25, na.rm = TRUE)),
      p75_implied_occupancy =
        as.numeric(quantile(implied_occupancy, 0.75, na.rm = TRUE)),
      min_implied_occupancy = min(implied_occupancy, na.rm = TRUE),
      max_implied_occupancy = max(implied_occupancy, na.rm = TRUE)
    )
  ]
  
  candidate_summary[
    ,
    candidate_field := field
  ]
  
  candidate_metrics_list[[field]] <- candidate_summary
}

candidate_summary_all <- data.table::rbindlist(
  candidate_metrics_list,
  fill = TRUE
)

# Clean Inf values.
for (cc in names(candidate_summary_all)) {
  if (is.numeric(candidate_summary_all[[cc]])) {
    candidate_summary_all[
      is.infinite(get(cc)),
      (cc) := NA_real_
    ]
  }
}

data.table::setcolorder(
  candidate_summary_all,
  c(
    "candidate_field",
    setdiff(names(candidate_summary_all), "candidate_field")
  )
)

candidate_summary_all <- candidate_summary_all[
  order(
    -providers_plausible,
    -pct_plausible_among_with_value,
    abs(implied_weighted_occupancy - 0.55)
  )
]

cat("\nCandidate inpatient-days field summary:\n")
print(candidate_summary_all)

# ============================================================
# 6. Evaluate likely inpatient-days and discharge pairings
# ============================================================

# We test pairings where one field is used as inpatient days and another as discharges.
# Plausible ALOS range is intentionally broad:
#   1.0 to 30 days overall, because children's, psych, CAH, swing-bed, and specialty
#   reporting can vary.
#
# We also compute by-class values so we can see whether a mapping is only plausible
# for one provider class.

pair_metrics_list <- list()
pair_id <- 0L

for (days_field in candidate_fields) {
  for (discharge_field in candidate_fields) {
    if (days_field == discharge_field) next
    
    pair_id <- pair_id + 1L
    
    tmp <- copy(s3_wide)
    
    tmp[, days_field_name := days_field]
    tmp[, discharge_field_name := discharge_field]
    
    tmp[, candidate_days := get_num(tmp, days_field)]
    tmp[, candidate_discharges := get_num(tmp, discharge_field)]
    
    tmp[, implied_occupancy := candidate_days / validated_bed_days_available]
    tmp[, implied_alos := candidate_days / candidate_discharges]
    
    tmp[
      ,
      plausible_pair :=
        bed_base_valid == TRUE &
        !is.na(candidate_days) &
        !is.na(candidate_discharges) &
        candidate_days >= 0 &
        candidate_discharges > 0 &
        candidate_days <= validated_bed_days_available * 1.05 &
        implied_occupancy >= 0 &
        implied_occupancy <= 1.05 &
        implied_alos >= 1 &
        implied_alos <= 30
    ]
    
    pair_summary <- tmp[
      bed_base_valid == TRUE,
      .(
        providers_with_both =
          sum(!is.na(candidate_days) & !is.na(candidate_discharges)),
        providers_plausible_pair = sum(plausible_pair, na.rm = TRUE),
        pct_plausible_pair =
          sum(plausible_pair, na.rm = TRUE) /
          sum(!is.na(candidate_days) & !is.na(candidate_discharges)),
        
        total_candidate_days = sum(candidate_days, na.rm = TRUE),
        total_candidate_discharges = sum(candidate_discharges, na.rm = TRUE),
        weighted_occupancy =
          sum(candidate_days, na.rm = TRUE) /
          sum(validated_bed_days_available, na.rm = TRUE),
        weighted_alos =
          sum(candidate_days, na.rm = TRUE) /
          sum(candidate_discharges, na.rm = TRUE),
        
        median_occupancy = median(implied_occupancy, na.rm = TRUE),
        median_alos = median(implied_alos, na.rm = TRUE),
        p25_alos = as.numeric(quantile(implied_alos, 0.25, na.rm = TRUE)),
        p75_alos = as.numeric(quantile(implied_alos, 0.75, na.rm = TRUE))
      )
    ]
    
    pair_summary[, days_field := days_field]
    pair_summary[, discharge_field := discharge_field]
    
    pair_metrics_list[[pair_id]] <- pair_summary
  }
}

pair_summary_all <- data.table::rbindlist(pair_metrics_list, fill = TRUE)

for (cc in names(pair_summary_all)) {
  if (is.numeric(pair_summary_all[[cc]])) {
    pair_summary_all[
      is.infinite(get(cc)),
      (cc) := NA_real_
    ]
  }
}

data.table::setcolorder(
  pair_summary_all,
  c(
    "days_field",
    "discharge_field",
    setdiff(names(pair_summary_all), c("days_field", "discharge_field"))
  )
)

pair_summary_all <- pair_summary_all[
  order(
    -providers_plausible_pair,
    -pct_plausible_pair,
    abs(weighted_occupancy - 0.55),
    abs(weighted_alos - 5)
  )
]

cat("\nTop candidate inpatient-days/discharge pairings:\n")
print(pair_summary_all[1:50])

# ============================================================
# 7. By-class view for top candidate pairings
# ============================================================

top_pairs <- pair_summary_all[1:min(.N, 10)]

by_class_list <- list()

for (i in seq_len(nrow(top_pairs))) {
  days_field <- top_pairs$days_field[i]
  discharge_field <- top_pairs$discharge_field[i]
  
  tmp <- copy(s3_wide)
  
  tmp[, days_field := days_field]
  tmp[, discharge_field := discharge_field]
  tmp[, candidate_days := get_num(tmp, days_field)]
  tmp[, candidate_discharges := get_num(tmp, discharge_field)]
  tmp[, implied_occupancy := candidate_days / validated_bed_days_available]
  tmp[, implied_alos := candidate_days / candidate_discharges]
  
  by_class <- tmp[
    bed_base_valid == TRUE,
    .(
      providers = .N,
      providers_with_both =
        sum(!is.na(candidate_days) & !is.na(candidate_discharges)),
      total_beds = sum(validated_beds, na.rm = TRUE),
      total_bed_days_available = sum(validated_bed_days_available, na.rm = TRUE),
      total_candidate_days = sum(candidate_days, na.rm = TRUE),
      total_candidate_discharges = sum(candidate_discharges, na.rm = TRUE),
      weighted_occupancy =
        sum(candidate_days, na.rm = TRUE) /
        sum(validated_bed_days_available, na.rm = TRUE),
      weighted_alos =
        sum(candidate_days, na.rm = TRUE) /
        sum(candidate_discharges, na.rm = TRUE),
      median_occupancy = median(implied_occupancy, na.rm = TRUE),
      median_alos = median(implied_alos, na.rm = TRUE)
    ),
    by = provider_model_class
  ]
  
  by_class[, days_field := days_field]
  by_class[, discharge_field := discharge_field]
  
  by_class_list[[i]] <- by_class
}

top_pairs_by_class <- data.table::rbindlist(by_class_list, fill = TRUE)

data.table::setcolorder(
  top_pairs_by_class,
  c(
    "days_field",
    "discharge_field",
    "provider_model_class",
    setdiff(
      names(top_pairs_by_class),
      c("days_field", "discharge_field", "provider_model_class")
    )
  )
)

cat("\nTop candidate pairings by provider class:\n")
print(top_pairs_by_class)

# ============================================================
# 8. Sample provider values for top pair
# ============================================================

best_days_field <- pair_summary_all$days_field[1]
best_discharge_field <- pair_summary_all$discharge_field[1]

sample_best <- copy(s3_wide)

sample_best[, best_days_field := best_days_field]
sample_best[, best_discharge_field := best_discharge_field]
sample_best[, candidate_days := get_num(sample_best, best_days_field)]
sample_best[, candidate_discharges := get_num(sample_best, best_discharge_field)]
sample_best[, implied_occupancy := candidate_days / validated_bed_days_available]
sample_best[, implied_alos := candidate_days / candidate_discharges]

sample_best_view <- sample_best[
  ,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_name,
    city,
    state_abbrev,
    provider_model_class,
    validated_beds,
    validated_bed_days_available,
    best_days_field,
    candidate_days,
    best_discharge_field,
    candidate_discharges,
    implied_occupancy,
    implied_alos
  )
][1:100]

cat("\nSample values using top candidate pair:\n")
print(sample_best_view)

# ============================================================
# 9. Save outputs
# ============================================================

candidate_metrics_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_S3_utilization_candidate_metrics.csv")
)

pair_summary_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_S3_utilization_candidate_pair_summary.csv")
)

top_pairs_by_class_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_S3_utilization_top_pairs_by_class.csv")
)

sample_best_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_S3_utilization_top_pair_sample.csv")
)

data.table::fwrite(candidate_summary_all, candidate_metrics_csv)
data.table::fwrite(pair_summary_all, pair_summary_csv)
data.table::fwrite(top_pairs_by_class, top_pairs_by_class_csv)
data.table::fwrite(sample_best_view, sample_best_csv)

cat("\nSaved:\n")
cat(candidate_metrics_csv, "\n")
cat(pair_summary_csv, "\n")
cat(top_pairs_by_class_csv, "\n")
cat(sample_best_csv, "\n")

cat("\n============================================================\n")
cat("S-3 utilization validation complete.\n")
cat("============================================================\n")