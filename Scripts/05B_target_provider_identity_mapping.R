# Scripts/05B_target_provider_identity_mapping.R
# Targeted inspection of likely provider identity fields for FY2024 HCRIS.
#
# Goal:
#   Identify exact ALPHA worksheet/line/column locations for:
#     provider name
#     street address
#     city
#     state
#     ZIP
#
# This script does NOT create the provider master.
# It only prints a focused view so we can map Script 5 correctly.

source("Scripts/00_setup.R")

cat("\n============================================================\n")
cat("TARGET PROVIDER IDENTITY MAPPING INSPECTION\n")
cat("============================================================\n")
cat("Build year:", hcris_year_label, "\n\n")

rpt_base <- readRDS(
  file.path(path_processed, paste0("hcris_", hcris_year_label, "_rpt_base.rds"))
)

alpha <- readRDS(
  file.path(path_processed, paste0("hcris_", hcris_year_label, "_alpha.rds"))
)

# Use a small set of backbone-included providers from different classes.
sample_reports <- rpt_base[
  provider_backbone_include_v1 == TRUE,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_model_class,
    facility_type,
    rpt_status_label
  )
][1:20]

cat("\nSample reports selected:\n")
print(sample_reports)

# Pull only S-family worksheets, because identity fields should be in S worksheets.
sample_s_alpha <- merge(
  alpha[
    rpt_rec_num %in% sample_reports$rpt_rec_num &
      stringr::str_detect(wksht_cd, "^S") &
      !is.na(itm_alphnmrc_itm_txt) &
      itm_alphnmrc_itm_txt != "",
    .(
      rpt_rec_num,
      wksht_cd,
      line_num_chr,
      clmn_num_chr,
      value = itm_alphnmrc_itm_txt
    )
  ],
  sample_reports,
  by = "rpt_rec_num",
  all.x = TRUE
)

sample_s_alpha <- sample_s_alpha[
  order(rpt_rec_num, wksht_cd, line_num_chr, clmn_num_chr)
]

# Save full targeted long view.
sample_s_alpha_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_target_sample_S_alpha_long.csv")
)

data.table::fwrite(sample_s_alpha, sample_s_alpha_csv)

cat("\nTargeted S-family ALPHA long view, first 500 rows:\n")
print(sample_s_alpha[1:500])

# Now produce a compact profile only for S000001, S200001, S200002.
# These are the most likely places for core cost-report/provider metadata.
target_profile <- alpha[
  stringr::str_detect(wksht_cd, "^S(000001|200001|200002)$") &
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
][order(wksht_cd, line_num_chr, clmn_num_chr)]

target_profile_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_target_S000001_S200001_S200002_profile.csv")
)

data.table::fwrite(target_profile, target_profile_csv)

cat("\nTarget profile for S000001 / S200001 / S200002:\n")
print(target_profile)

# Look for known identity-like values based on the bad sample output.
# These should help locate which line/column actually holds hospital name/city/state.
known_terms <- c(
  "MARY S HARPER",
  "TUSCALOOSA",
  "OSF SAINT ANTHONYS",
  "ALTON",
  "MT EDGECUMBE",
  "JUNEAU",
  "USA HEALTH",
  "MOBILE",
  "ADVENTHEALTH OCALA",
  "OCALA"
)

known_hits <- alpha[
  !is.na(itm_alphnmrc_itm_txt) &
    stringr::str_detect(
      stringr::str_to_upper(itm_alphnmrc_itm_txt),
      paste(known_terms, collapse = "|")
    ),
  .(
    rpt_rec_num,
    wksht_cd,
    line_num_chr,
    clmn_num_chr,
    value = itm_alphnmrc_itm_txt
  )
]

known_hits <- merge(
  known_hits,
  rpt_base[
    ,
    .(
      rpt_rec_num,
      prvdr_num_chr,
      provider_model_class,
      facility_type,
      provider_backbone_include_v1
    )
  ],
  by = "rpt_rec_num",
  all.x = TRUE
)

known_hits <- known_hits[
  order(rpt_rec_num, wksht_cd, line_num_chr, clmn_num_chr)
]

known_hits_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_known_identity_term_hits.csv")
)

data.table::fwrite(known_hits, known_hits_csv)

cat("\nKnown identity term hits:\n")
print(known_hits[1:300])

cat("\nSaved:\n")
cat(sample_s_alpha_csv, "\n")
cat(target_profile_csv, "\n")
cat(known_hits_csv, "\n")

cat("\n============================================================\n")
cat("Target identity inspection complete.\n")
cat("============================================================\n")