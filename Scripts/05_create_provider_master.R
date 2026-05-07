# Scripts/05_create_provider_master.R
# Create HCRIS provider master table from RPT base + corrected S200001 identity fields
# Compatible with year-flexible setup from Scripts/00_setup.R
#
# Inputs:
#   Processed/hcris_YYYY_rpt_base.rds
#   Processed/hcris_YYYY_alpha.rds
#
# Outputs:
#   Processed/hcris_YYYY_provider_master.rds
#   Output/hcris_YYYY_provider_master.csv
#   Output/hcris_YYYY_provider_identity_quality.csv
#
# Confirmed FY2024 identity mapping:
#   S200001 L00100 C00100 = street address line 1
#   S200001 L00100 C00200 = street address line 2 / secondary address
#   S200001 L00200 C00100 = city
#   S200001 L00200 C00200 = state
#   S200001 L00200 C00300 = ZIP
#   S200001 L00200 C00400 = county
#   S200001 L00300 C00100 = provider name
#   S200001 L00300 C00200 = provider number

source("Scripts/00_setup.R")

cat("\n============================================================\n")
cat("CREATE HCRIS PROVIDER MASTER\n")
cat("============================================================\n")
cat("Build year:", hcris_year_label, "\n\n")

# ============================================================
# 1. Load inputs
# ============================================================

rpt_base_file <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_rpt_base.rds")
)

alpha_file <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_alpha.rds")
)

if (!file.exists(rpt_base_file)) {
  stop("Missing RPT base file: ", rpt_base_file)
}

if (!file.exists(alpha_file)) {
  stop("Missing ALPHA file: ", alpha_file)
}

rpt_base <- readRDS(rpt_base_file)
alpha <- readRDS(alpha_file)

cat("Loaded:\n")
cat(rpt_base_file, "\n")
cat(alpha_file, "\n")

cat("\nRPT base rows:", nrow(rpt_base), "\n")
cat("ALPHA rows:", nrow(alpha), "\n")

# ============================================================
# 2. Safety checks
# ============================================================

required_rpt_cols <- c(
  "rpt_rec_num",
  "prvdr_num_chr",
  "provider_model_class",
  "provider_backbone_include_v1"
)

required_alpha_cols <- c(
  "rpt_rec_num",
  "wksht_cd",
  "line_num_chr",
  "clmn_num_chr",
  "itm_alphnmrc_itm_txt"
)

missing_rpt <- setdiff(required_rpt_cols, names(rpt_base))
missing_alpha <- setdiff(required_alpha_cols, names(alpha))

if (length(missing_rpt) > 0) {
  stop(
    "RPT base missing required columns:\n",
    paste(missing_rpt, collapse = "\n")
  )
}

if (length(missing_alpha) > 0) {
  stop(
    "ALPHA missing required columns:\n",
    paste(missing_alpha, collapse = "\n")
  )
}

# ============================================================
# 3. Extract S200001 identity block
# ============================================================

identity_long <- alpha[
  wksht_cd == "S200001" &
    line_num_chr %in% c("00100", "00200", "00300") &
    clmn_num_chr %in% c("00100", "00200", "00300", "00400") &
    !is.na(itm_alphnmrc_itm_txt) &
    itm_alphnmrc_itm_txt != "",
  .(
    rpt_rec_num,
    line_num_chr,
    clmn_num_chr,
    value = itm_alphnmrc_itm_txt
  )
]

identity_long[
  ,
  identity_field := data.table::fcase(
    line_num_chr == "00100" & clmn_num_chr == "00100", "street_address_1",
    line_num_chr == "00100" & clmn_num_chr == "00200", "street_address_2",
    line_num_chr == "00200" & clmn_num_chr == "00100", "city",
    line_num_chr == "00200" & clmn_num_chr == "00200", "state_abbrev",
    line_num_chr == "00200" & clmn_num_chr == "00300", "zip_code",
    line_num_chr == "00200" & clmn_num_chr == "00400", "county",
    line_num_chr == "00300" & clmn_num_chr == "00100", "provider_name",
    line_num_chr == "00300" & clmn_num_chr == "00200", "provider_number_alpha",
    default = NA_character_
  )
]

identity_long <- identity_long[!is.na(identity_field)]

# If duplicate report-field rows exist, keep first nonmissing value.
identity_long_dedup <- identity_long[
  ,
  .(
    value = value[which(!is.na(value) & value != "")[1]]
  ),
  by = .(rpt_rec_num, identity_field)
]

provider_identity <- data.table::dcast(
  identity_long_dedup,
  rpt_rec_num ~ identity_field,
  value.var = "value"
)

# Add combined address field.
provider_identity[
  ,
  street_address := data.table::fifelse(
    !is.na(street_address_2) & street_address_2 != "",
    paste(street_address_1, street_address_2),
    street_address_1
  )
]

# Normalize ZIP.
provider_identity[
  ,
  zip_code := stringr::str_trim(as.character(zip_code))
]

provider_identity[
  ,
  zip_code := data.table::fifelse(
    zip_code %in% c("-", "--", "00000", "NA"),
    NA_character_,
    zip_code
  )
]

# Normalize state.
provider_identity[
  ,
  state_abbrev := stringr::str_to_upper(stringr::str_trim(as.character(state_abbrev)))
]

# ============================================================
# 4. Merge with RPT base
# ============================================================

provider_master <- merge(
  rpt_base,
  provider_identity[
    ,
    .(
      rpt_rec_num,
      provider_name,
      street_address,
      street_address_1,
      street_address_2,
      city,
      state_abbrev,
      zip_code,
      county,
      provider_number_alpha
    )
  ],
  by = "rpt_rec_num",
  all.x = TRUE
)

# ============================================================
# 5. Add validation / quality flags
# ============================================================

provider_master[
  ,
  provider_name_missing_flag :=
    is.na(provider_name) | provider_name == ""
]

provider_master[
  ,
  address_missing_flag :=
    is.na(street_address_1) | street_address_1 == ""
]

provider_master[
  ,
  city_missing_flag :=
    is.na(city) | city == ""
]

provider_master[
  ,
  state_missing_flag :=
    is.na(state_abbrev) | state_abbrev == ""
]

provider_master[
  ,
  zip_missing_flag :=
    is.na(zip_code) | zip_code == ""
]

provider_master[
  ,
  alpha_provider_number_matches_rpt :=
    !is.na(provider_number_alpha) &
    provider_number_alpha == prvdr_num_chr
]

provider_master[
  ,
  identity_complete_flag :=
    provider_name_missing_flag == FALSE &
    address_missing_flag == FALSE &
    city_missing_flag == FALSE &
    state_missing_flag == FALSE &
    zip_missing_flag == FALSE
]

# ============================================================
# 6. Keep useful columns first
# ============================================================

front_cols <- c(
  "rpt_rec_num",
  "prvdr_num_chr",
  "provider_number_alpha",
  "alpha_provider_number_matches_rpt",
  "provider_name",
  "street_address",
  "street_address_1",
  "street_address_2",
  "city",
  "state_abbrev",
  "zip_code",
  "county",
  "prvdr_state_code",
  "state_code_numeric",
  "npi",
  "prvdr_ctrl_type_cd",
  "facility_type",
  "provider_model_class",
  "rpt_stus_cd",
  "rpt_status_label",
  "fy_bgn_dt",
  "fy_end_dt",
  "fy_bgn_dt_parsed",
  "fy_end_dt_parsed",
  "report_days",
  "full_year_report_flag",
  "provider_model_candidate",
  "acute_or_rural_include_v1",
  "provider_backbone_include_v1",
  "identity_complete_flag",
  "provider_name_missing_flag",
  "address_missing_flag",
  "city_missing_flag",
  "state_missing_flag",
  "zip_missing_flag"
)

front_cols <- intersect(front_cols, names(provider_master))
other_cols <- setdiff(names(provider_master), front_cols)

data.table::setcolorder(provider_master, c(front_cols, other_cols))

# ============================================================
# 7. Save outputs
# ============================================================

provider_master_rds <- file.path(
  path_processed,
  paste0("hcris_", hcris_year_label, "_provider_master.rds")
)

provider_master_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_provider_master.csv")
)

saveRDS(provider_master, provider_master_rds)
data.table::fwrite(provider_master, provider_master_csv)

provider_identity_quality <- provider_master[
  ,
  .(
    reports = .N,
    provider_name_missing = sum(provider_name_missing_flag, na.rm = TRUE),
    address_missing = sum(address_missing_flag, na.rm = TRUE),
    city_missing = sum(city_missing_flag, na.rm = TRUE),
    state_missing = sum(state_missing_flag, na.rm = TRUE),
    zip_missing = sum(zip_missing_flag, na.rm = TRUE),
    identity_complete = sum(identity_complete_flag, na.rm = TRUE),
    alpha_provider_number_matches = sum(alpha_provider_number_matches_rpt, na.rm = TRUE)
  ),
  by = .(provider_backbone_include_v1, provider_model_class)
][order(provider_backbone_include_v1, provider_model_class)]

quality_csv <- file.path(
  path_output,
  paste0("hcris_", hcris_year_label, "_provider_identity_quality.csv")
)

data.table::fwrite(provider_identity_quality, quality_csv)

# ============================================================
# 8. Print summaries
# ============================================================

cat("\n============================================================\n")
cat("PROVIDER MASTER CREATED\n")
cat("============================================================\n")

cat("\nRows:", nrow(provider_master), "\n")
cat("Unique rpt_rec_num:", data.table::uniqueN(provider_master$rpt_rec_num), "\n")
cat("Unique provider numbers:", data.table::uniqueN(provider_master$prvdr_num_chr), "\n")

cat("\nIdentity field missingness, all reports:\n")
print(provider_master[
  ,
  .(
    n = .N,
    provider_name_missing = sum(provider_name_missing_flag, na.rm = TRUE),
    address_missing = sum(address_missing_flag, na.rm = TRUE),
    city_missing = sum(city_missing_flag, na.rm = TRUE),
    state_missing = sum(state_missing_flag, na.rm = TRUE),
    zip_missing = sum(zip_missing_flag, na.rm = TRUE),
    identity_complete = sum(identity_complete_flag, na.rm = TRUE),
    alpha_provider_number_matches = sum(alpha_provider_number_matches_rpt, na.rm = TRUE)
  )
])

cat("\nIdentity field missingness, backbone-included reports:\n")
print(provider_master[
  provider_backbone_include_v1 == TRUE,
  .(
    n = .N,
    provider_name_missing = sum(provider_name_missing_flag, na.rm = TRUE),
    address_missing = sum(address_missing_flag, na.rm = TRUE),
    city_missing = sum(city_missing_flag, na.rm = TRUE),
    state_missing = sum(state_missing_flag, na.rm = TRUE),
    zip_missing = sum(zip_missing_flag, na.rm = TRUE),
    identity_complete = sum(identity_complete_flag, na.rm = TRUE),
    alpha_provider_number_matches = sum(alpha_provider_number_matches_rpt, na.rm = TRUE)
  )
])

cat("\nBackbone-included provider classes:\n")
print(provider_master[
  provider_backbone_include_v1 == TRUE,
  .N,
  by = provider_model_class
][order(-N)])

cat("\nSample backbone-included providers:\n")
print(provider_master[
  provider_backbone_include_v1 == TRUE,
  .(
    rpt_rec_num,
    prvdr_num_chr,
    provider_number_alpha,
    alpha_provider_number_matches_rpt,
    provider_name,
    street_address,
    city,
    state_abbrev,
    zip_code,
    county,
    provider_model_class,
    report_days,
    rpt_status_label
  )
][1:30])

cat("\nProvider identity quality by class:\n")
print(provider_identity_quality)

cat("\nSaved:\n")
cat(provider_master_rds, "\n")
cat(provider_master_csv, "\n")
cat(quality_csv, "\n")

cat("\n============================================================\n")