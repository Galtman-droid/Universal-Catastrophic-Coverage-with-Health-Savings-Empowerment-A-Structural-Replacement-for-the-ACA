# Scripts/06A_inspect_S3_capacity_columns.R
# Focused inspection of S-3 Part I capacity/utilization columns.
#
# Goal:
#   Confirm exact columns for:
#     beds
#     bed-days available
#     inpatient days
#     discharges
#
# We already suspect:
#   S300001 L00100 C00200 = beds
#   S300001 L00100 C00300 = bed-days available

source("Scripts/00_setup.R")

cat("\n============================================================\n")
cat("INSPECT S-3 CAPACITY COLUMNS\n")
cat("============================================================\n")
cat("Build year:", hcris_year_label, "\n\n")

provider_master <- readRDS(
  file.path(path_processed, paste0("hcris_", hcris_year_label, "_provider_master.rds"))
)

nmrc <- readRDS(
  file.path(path_processed, paste0("hcris_", hcris_year_label, "_nmrc.rds"))
)

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

# Use first 30 included providers for readable long-form inspection.
sample_reports <- included[1:30]

s3_sample <- merge(
  nmrc[
    rpt_rec_num %in% sample_reports$rpt_rec_num &
      wksht_cd == "S300001" &
      line_num_chr >= "00100" &
      line_num_chr <= "01500" &
      !is.na(itm_val_num),
    .(
      rpt_rec_num,
      wksht_cd,
      line_num_chr,
      clmn_num_chr,
      value = itm_val_num
    )
  ],
  sample_reports,
  by = "rpt_rec_num",
  all.x = TRUE
)

s3_sample <- s3_sample[
  order(rpt_rec_num, line_num_chr, clmn_num_chr)
]

cat("\nS300001 sample long view, first 500 rows:\n")
print(s3_sample[1:500])

# Full profile for backbone providers.
s3_profile <- nmrc[
  rpt_rec_num %in% included$rpt_rec_num &
    wksht_cd == "S300001" &
    line_num_chr >= "00100" &
    line_num_chr <= "01500" &
    !is.na(itm_val_num),
  .(
    n_rows = .N,
    n_reports = uniqueN(rpt_rec_num),
    min_value = suppressWarnings(min(itm_val_num, na.rm = TRUE)),
    p25_value = suppressWarnings(quantile(itm_val_num, 0.25, na.rm = TRUE)),
    median_value = suppressWarnings(median(itm_val_num, na.rm = TRUE)),
    mean_value = suppressWarnings(mean(itm_val_num, na.rm = TRUE)),
    p75_value = suppressWarnings(quantile(itm_val_num, 0.75, na.rm = TRUE)),
    max_value = suppressWarnings(max(itm_val_num, na.rm = TRUE))
  ),
  by = .(wksht_cd, line_num_chr, clmn_num_chr)
][order(line_num_chr, clmn_num_chr)]

cat("\nS300001 profile for lines 00100-01500, all backbone providers:\n")
print(s3_profile)

# Wide view for first 30 providers, easier to visually inspect.
s3_sample[
  ,
  field_key := paste0("L", line_num_chr, "_C", clmn_num_chr)
]

s3_sample_wide <- data.table::dcast(
  s3_sample,
  rpt_rec_num + prvdr_num_chr + provider_name + city + state_abbrev + provider_model_class ~ field_key,
  value.var = "value"
)

cat("\nS300001 sample wide view:\n")
print(s3_sample_wide)

# Save outputs.
sample_long_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_S300001_capacity_sample_long.csv")
)

sample_wide_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_S300001_capacity_sample_wide.csv")
)

profile_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_S300001_capacity_profile_lines_001_015.csv")
)

data.table::fwrite(s3_sample, sample_long_csv)
data.table::fwrite(s3_sample_wide, sample_wide_csv)
data.table::fwrite(s3_profile, profile_csv)

cat("\nSaved:\n")
cat(sample_long_csv, "\n")
cat(sample_wide_csv, "\n")
cat(profile_csv, "\n")

cat("\n============================================================\n")
cat("S-3 capacity inspection complete.\n")
cat("============================================================\n")