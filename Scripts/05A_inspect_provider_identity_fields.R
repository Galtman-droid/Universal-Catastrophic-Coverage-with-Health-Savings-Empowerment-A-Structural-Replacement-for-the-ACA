# Scripts/05A_inspect_provider_identity_fields.R
# Inspect ALPHA fields to identify correct provider name/address/city/state/ZIP mappings
# for FY2024 HCRIS.

source("Scripts/00_setup.R")

cat("\n============================================================\n")
cat("INSPECT PROVIDER IDENTITY FIELDS\n")
cat("============================================================\n")
cat("Build year:", hcris_year_label, "\n\n")

rpt_base <- readRDS(
  file.path(path_processed, paste0("hcris_", hcris_year_label, "_rpt_base.rds"))
)

alpha <- readRDS(
  file.path(path_processed, paste0("hcris_", hcris_year_label, "_alpha.rds"))
)

# Use only backbone-included providers so the examples are relevant.
included_reports <- rpt_base[
  provider_backbone_include_v1 == TRUE,
  .(rpt_rec_num, prvdr_num_chr, provider_model_class)
]

alpha_included <- merge(
  alpha,
  included_reports,
  by = "rpt_rec_num",
  all.x = FALSE
)

# Keep text fields with meaningful values.
alpha_text <- alpha_included[
  !is.na(itm_alphnmrc_itm_txt) &
    itm_alphnmrc_itm_txt != ""
]

# Create profile of every ALPHA field among included providers.
field_profile <- alpha_text[
  ,
  .(
    n_rows = .N,
    n_reports = uniqueN(rpt_rec_num),
    n_distinct_values = uniqueN(itm_alphnmrc_itm_txt),
    
    sample_1 = itm_alphnmrc_itm_txt[1],
    sample_2 = itm_alphnmrc_itm_txt[pmin(.N, 2)],
    sample_3 = itm_alphnmrc_itm_txt[pmin(.N, 3)],
    sample_4 = itm_alphnmrc_itm_txt[pmin(.N, 4)],
    sample_5 = itm_alphnmrc_itm_txt[pmin(.N, 5)]
  ),
  by = .(wksht_cd, line_num_chr, clmn_num_chr)
][order(wksht_cd, line_num_chr, clmn_num_chr)]

# Add simple heuristic flags.
field_profile[
  ,
  likely_state_field :=
    n_distinct_values <= 60 &
    stringr::str_detect(sample_1, "^[A-Z]{2}$")
]

field_profile[
  ,
  likely_zip_field :=
    stringr::str_detect(sample_1, "^[0-9]{5}(-[0-9]{4})?$")
]

field_profile[
  ,
  likely_date_or_flag :=
    stringr::str_detect(sample_1, "^[0-9]{2}/[0-9]{2}/[0-9]{4}$") |
    sample_1 %in% c("Y", "N", "X", "F", "U", "A", "B", "C", "1", "2", "3", "4", "5")
]

field_profile[
  ,
  likely_name_or_address :=
    n_reports > 100 &
    n_distinct_values > 100 &
    !likely_state_field &
    !likely_zip_field &
    !likely_date_or_flag
]

profile_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_alpha_identity_full_field_profile.csv")
)

data.table::fwrite(field_profile, profile_csv)

cat("\nLikely name/address/city fields:\n")
print(field_profile[
  likely_name_or_address == TRUE,
  .(
    wksht_cd,
    line_num_chr,
    clmn_num_chr,
    n_reports,
    n_distinct_values,
    sample_1,
    sample_2,
    sample_3,
    sample_4,
    sample_5
  )
][1:200])

cat("\nLikely state fields:\n")
print(field_profile[
  likely_state_field == TRUE,
  .(
    wksht_cd,
    line_num_chr,
    clmn_num_chr,
    n_reports,
    n_distinct_values,
    sample_1,
    sample_2,
    sample_3,
    sample_4,
    sample_5
  )
][1:100])

cat("\nLikely ZIP fields:\n")
print(field_profile[
  likely_zip_field == TRUE,
  .(
    wksht_cd,
    line_num_chr,
    clmn_num_chr,
    n_reports,
    n_distinct_values,
    sample_1,
    sample_2,
    sample_3,
    sample_4,
    sample_5
  )
][1:100])

# Inspect a few known included reports in long form.
sample_reports <- included_reports[1:10, rpt_rec_num]

sample_alpha_long <- alpha_included[
  rpt_rec_num %in% sample_reports &
    !is.na(itm_alphnmrc_itm_txt) &
    itm_alphnmrc_itm_txt != "",
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_model_class,
    wksht_cd,
    line_num_chr,
    clmn_num_chr,
    value = itm_alphnmrc_itm_txt
  )
][order(rpt_rec_num, wksht_cd, line_num_chr, clmn_num_chr)]

sample_long_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_sample_provider_alpha_long.csv")
)

data.table::fwrite(sample_alpha_long, sample_long_csv)

cat("\nSample provider ALPHA long view, first 300 rows:\n")
print(sample_alpha_long[1:300])

cat("\nSaved:\n")
cat(profile_csv, "\n")
cat(sample_long_csv, "\n")

cat("\n============================================================\n")
cat("Provider identity inspection complete.\n")
cat("============================================================\n")