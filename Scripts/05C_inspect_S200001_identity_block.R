# Scripts/05C_inspect_S200001_identity_block.R
# Focused inspection of S200001 identity block.
#
# Goal:
#   Confirm exact mapping for provider name, street address, city, state, ZIP.

source("Scripts/00_setup.R")

cat("\n============================================================\n")
cat("INSPECT S200001 IDENTITY BLOCK\n")
cat("============================================================\n")
cat("Build year:", hcris_year_label, "\n\n")

rpt_base <- readRDS(
  file.path(path_processed, paste0("hcris_", hcris_year_label, "_rpt_base.rds"))
)

alpha <- readRDS(
  file.path(path_processed, paste0("hcris_", hcris_year_label, "_alpha.rds"))
)

sample_reports <- rpt_base[
  provider_backbone_include_v1 == TRUE,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_model_class,
    facility_type,
    rpt_status_label
  )
][1:30]

s200_identity_block <- merge(
  alpha[
    rpt_rec_num %in% sample_reports$rpt_rec_num &
      wksht_cd == "S200001" &
      line_num_chr >= "00100" &
      line_num_chr <= "00800" &
      !is.na(itm_alphnmrc_itm_txt) &
      itm_alphnmrc_itm_txt != "",
    .(
      rpt_rec_num,
      line_num_chr,
      clmn_num_chr,
      value = itm_alphnmrc_itm_txt
    )
  ],
  sample_reports,
  by = "rpt_rec_num",
  all.x = TRUE
)

s200_identity_block <- s200_identity_block[
  order(rpt_rec_num, line_num_chr, clmn_num_chr)
]

cat("\nS200001 identity block for sample reports:\n")
print(s200_identity_block)

# Compact field profile for all backbone-included reports.
included_reports <- rpt_base[
  provider_backbone_include_v1 == TRUE,
  .(rpt_rec_num)
]

s200_profile <- alpha[
  rpt_rec_num %in% included_reports$rpt_rec_num &
    wksht_cd == "S200001" &
    line_num_chr >= "00100" &
    line_num_chr <= "00800" &
    !is.na(itm_alphnmrc_itm_txt) &
    itm_alphnmrc_itm_txt != "",
  .(
    n_rows = .N,
    n_reports = uniqueN(rpt_rec_num),
    n_distinct_values = uniqueN(itm_alphnmrc_itm_txt),
    sample_1 = itm_alphnmrc_itm_txt[1],
    sample_2 = itm_alphnmrc_itm_txt[pmin(.N, 2)],
    sample_3 = itm_alphnmrc_itm_txt[pmin(.N, 3)],
    sample_4 = itm_alphnmrc_itm_txt[pmin(.N, 4)],
    sample_5 = itm_alphnmrc_itm_txt[pmin(.N, 5)],
    sample_6 = itm_alphnmrc_itm_txt[pmin(.N, 6)],
    sample_7 = itm_alphnmrc_itm_txt[pmin(.N, 7)],
    sample_8 = itm_alphnmrc_itm_txt[pmin(.N, 8)],
    sample_9 = itm_alphnmrc_itm_txt[pmin(.N, 9)],
    sample_10 = itm_alphnmrc_itm_txt[pmin(.N, 10)]
  ),
  by = .(wksht_cd, line_num_chr, clmn_num_chr)
][order(line_num_chr, clmn_num_chr)]

cat("\nS200001 identity block profile, all backbone reports:\n")
print(s200_profile)

s200_identity_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_S200001_identity_block_sample.csv")
)

s200_profile_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_S200001_identity_block_profile.csv")
)

data.table::fwrite(s200_identity_block, s200_identity_csv)
data.table::fwrite(s200_profile, s200_profile_csv)

cat("\nSaved:\n")
cat(s200_identity_csv, "\n")
cat(s200_profile_csv, "\n")

cat("\n============================================================\n")
cat("S200001 identity block inspection complete.\n")
cat("============================================================\n")