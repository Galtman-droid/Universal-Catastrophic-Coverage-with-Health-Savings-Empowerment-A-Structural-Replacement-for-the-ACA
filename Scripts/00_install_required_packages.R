# Scripts/00_install_required_packages.R
# Rebuild / refresh the R package library needed for the UCC/HSE HCRIS model.
#
# Run this from the project root:
# source("Scripts/00_install_required_packages.R")

cat("\n============================================================\n")
cat("REBUILD / REFRESH REQUIRED R PACKAGES\n")
cat("============================================================\n\n")

# ============================================================
# 1. Required CRAN packages
# ============================================================

required_packages <- c(
  "data.table",
  "readr",
  "readxl",
  "openxlsx",
  "writexl",
  "dplyr",
  "tidyr",
  "stringr",
  "lubridate",
  "janitor",
  "here",
  "tools"
)

# Packages that may already exist as base/recommended packages.
# install.packages() will skip base packages automatically if unavailable on CRAN,
# but keeping tools in the list is harmless because it is usually already installed.
required_packages <- unique(required_packages)

# ============================================================
# 2. Choose CRAN mirror
# ============================================================

options(repos = c(CRAN = "https://cloud.r-project.org"))

# ============================================================
# 3. Report current library paths
# ============================================================

cat("R version:\n")
print(R.version.string)

cat("\nLibrary paths:\n")
print(.libPaths())

cat("\nRequired packages:\n")
print(required_packages)

# ============================================================
# 4. Install missing packages
# ============================================================

installed <- rownames(installed.packages())

missing_packages <- setdiff(required_packages, installed)

if (length(missing_packages) > 0) {
  cat("\nInstalling missing packages:\n")
  print(missing_packages)
  
  install.packages(
    missing_packages,
    dependencies = TRUE
  )
} else {
  cat("\nNo missing packages detected.\n")
}

# ============================================================
# 5. Optional package refresh
# ============================================================

# Set this to TRUE only if you want to reinstall all required packages even if present.
force_reinstall <- FALSE

if (force_reinstall == TRUE) {
  cat("\nForce reinstall is TRUE. Reinstalling required packages:\n")
  print(required_packages)
  
  install.packages(
    required_packages,
    dependencies = TRUE
  )
} else {
  cat("\nForce reinstall is FALSE. Existing packages were not reinstalled.\n")
}

# ============================================================
# 6. Load-test packages
# ============================================================

cat("\nLoad-testing required packages:\n")

load_results <- data.frame(
  package = character(),
  loaded = logical(),
  version = character(),
  error = character(),
  stringsAsFactors = FALSE
)

for (pkg in required_packages) {
  result <- tryCatch(
    {
      suppressPackageStartupMessages(
        library(pkg, character.only = TRUE)
      )
      
      pkg_version <- as.character(utils::packageVersion(pkg))
      
      data.frame(
        package = pkg,
        loaded = TRUE,
        version = pkg_version,
        error = "",
        stringsAsFactors = FALSE
      )
    },
    error = function(e) {
      data.frame(
        package = pkg,
        loaded = FALSE,
        version = NA_character_,
        error = conditionMessage(e),
        stringsAsFactors = FALSE
      )
    }
  )
  
  load_results <- rbind(load_results, result)
}

print(load_results)

# ============================================================
# 7. Stop if anything failed
# ============================================================

failed <- load_results[load_results$loaded == FALSE, ]

if (nrow(failed) > 0) {
  cat("\nSome packages failed to load:\n")
  print(failed)
  
  stop("Package rebuild incomplete. Fix failed packages above before rerunning the model.")
}

# ============================================================
# 8. Session info
# ============================================================

cat("\nSession info:\n")
print(sessionInfo())

cat("\n============================================================\n")
cat("R PACKAGE SETUP COMPLETE\n")
cat("============================================================\n")