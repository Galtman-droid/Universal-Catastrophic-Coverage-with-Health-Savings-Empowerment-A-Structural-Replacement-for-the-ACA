# Universal Catastrophic Coverage with Health Savings Empowerment

## Reproducibility Repository for the UCC/HSE White Paper

This repository contains the analytical code, public reproducibility files, scoring workbooks, and publication outputs supporting the white paper **Universal Catastrophic Coverage with Health Savings Empowerment: A Structural Replacement for the ACA**.

Universal Catastrophic Coverage with Health Savings Empowerment (UCC/HSE) is a proposed health-financing framework that separates catastrophic medical risk from routine-care financing. Under the model, catastrophic and high-acuity care remains insured, while routine, preventive, pediatric, behavioral-health, and chronic-care needs are financed through portable Health Savings Empowerment accounts.

This repository supports two major analytical components of the paper: the FY2024 HCRIS-based provider-impact model and the CBO-style federal outlay, savings, and consumer-impact model. The materials are provided to support transparency, replication, stress testing, and technical review.

## Important Disclaimer

The estimates in this repository are internal CBO-style model estimates, not official Congressional Budget Office scores, actuarial certifications, hospital-closure forecasts, or government agency estimates.

The provider-impact model is a policy-scenario model based on FY2024 CMS HCRIS cost-report data. It estimates provider-level exposure to routine/outpatient repricing, uncompensated-care relief, bad-debt relief, stabilization tiers, rural access protection, and behavioral-health institutional adjustments.

The federal scoring workbook is an internal policy model designed to approximate federal outlays, savings, and long-run budget effects under the UCC/HSE framework. It is intended for review and refinement, not as an official federal score.

## Repository Structure

The repository is organized into the following major folders and files:

`Scripts/` contains the R workflow used to build the FY2024 HCRIS provider-impact model.

`Processed_Public/` contains curated processed `.rds` files that allow reviewers to reproduce Table 7 provider-impact outputs without rerunning the full raw HCRIS extraction pipeline.

`Output/Table7_Publication/` contains the publication-ready Table 7 output package, including CSV tables, Excel workbooks, image tables, compact figures, manifests, and methodology notes.

`Output/Model_Building/` contains intermediate model-building and audit outputs used to validate provider classification, revenue extraction, exposure calculations, stabilization tiers, and diagnostic provider-impact results.

`HCRIS ModelingDocumentation/` contains CMS HCRIS reference materials used to interpret hospital cost-report worksheet codes, facility numbering, state codes, crosswalks, and related HCRIS structure.

`White paper and H251 outlays/` contains the federal scoring workbooks and MEPS HC-251-related materials used in the white paper.

`Universal Catastrophic Coverage with Health Savings Empowerment White Paper copy.pdf` is the public PDF version of the white paper.

## 1. Scripts

The `Scripts/` folder contains the R workflow used to construct the FY2024 HCRIS provider-impact model.

The script sequence performs the following functions: installs and loads required R packages; loads FY2024 CMS HCRIS raw files; creates the report/provider backbone; extracts provider identity fields; extracts beds and capacity variables; extracts S-10 uncompensated-care data; extracts G-2/G-3 revenue and expense variables; validates provider classification; constructs stabilization eligibility; runs provider-impact scenarios; audits coverage and exposure anomalies; generates Table 7 publication outputs; runs rural and behavioral-health sensitivity analyses; and creates combined script documentation.

Core scripts include:

`00_install_required_packages.R`
`00_setup.R`
`02_load_full_hcris.R`
`04_create_rpt_base.R`
`05_create_provider_master.R`
`06_extract_beds_capacity.R`
`07_extract_s10_uncompensated_care.R`
`08_extract_g2_g3_revenue_expense.R`
`09_validate_provider_classification.R`
`10_create_stabilization_eligibility.R`
`11_create_provider_impact_scenarios.R`
`11A_audit_provider_impact_coverage_and_exposure.R`
`12_format_table7_publication_outputs.R`
`13_provider_transition_protection_sensitivity.R`
`13B_enhanced_rural_access_sensitivity.R`
`13C_behavioral_psychiatric_sensitivity.R`
`14_create_table7_access_protection_summary.R`
`15_make_table7_publication_grade_tables.R`
`combine_all_scripts_into_one_document.R`

Diagnostic scripts are also included where they were used to validate HCRIS worksheet mappings, provider identity fields, capacity fields, revenue extraction, provider classification, and data-quality issues.

## 2. Processed Public Files

The `Processed_Public/` folder contains curated `.rds` files that allow reviewers to reproduce the Table 7 provider-impact outputs without rerunning the full raw HCRIS extraction pipeline.

Raw CMS HCRIS files are not included in this repository because of size and distribution considerations. Reviewers who want to rebuild the full pipeline from raw CMS files can obtain FY2024 HCRIS data from CMS and run the scripts in `Scripts/`.

Included public processed files:

`hcris_2024_provider_master.rds`
`hcris_2024_provider_master_classified.rds`
`hcris_2024_provider_master_with_financials.rds`
`hcris_2024_provider_master_with_stabilization.rds`
`hcris_2024_provider_impact_scenarios.rds`

These files support direct reproduction and inspection of the modeled provider-impact universe, stabilization variables, financial inputs, and scenario outputs.

## 3. Table 7 Publication Outputs

The `Output/Table7_Publication/` folder contains the publication-ready Table 7 output package used in the white paper.

This folder includes main Table 7 output tables; appendix tables 7A–7P; access-protection policy options; enhanced rural access sensitivity outputs; behavioral and psychiatric provider sensitivity outputs; provider-level review files; publication-grade table images; compact figure outputs; table manifests; and methodology notes.

Key files include:

`Table_7_All_Main_and_Appendix_Tables.xlsx`
`Table_7A_Provider_Impact_3x3_Scenario_Matrix.csv`
`Table_7B_Provider_Impact_by_Group.csv`
`Table_7C_Provider_Impact_by_Class.csv`
`Table_7D_Provider_Level_Distribution.csv`
`Table_7E_Model_Coverage_Data_Quality_Audit.csv`
`Table_7F_Exposure_Anomaly_Sensitivity.csv`
`Table_7G_Access_Protection_Policy_Options.csv`
`Appendix_Table_7J_Provider_Level_Transition_Rural_Access.csv`
`Appendix_Table_7K_Enhanced_Rural_Access_Sensitivity.csv`
`Appendix_Table_7L_Rural_Provider_Level_Enhanced_Access.csv`
`Appendix_Table_7M_Behavioral_Psychiatric_Sensitivity.csv`
`Appendix_Table_7N_Behavioral_Psychiatric_Provider_Level.csv`
`Appendix_Table_7O_Behavioral_Remaining_Severe_Effects.csv`
`Appendix_Table_7P_Behavioral_Review_Universe.csv`

The Table 7 model is designed to distinguish between a diagnostic baseline provider-impact scenario and the preferred stabilized provider-impact framework. The stabilized framework applies targeted access protections, including rural access-capacity support and behavioral-health institutional treatment, without eliminating the model’s routine-care price-discipline mechanism.

## 4. Model-Building Outputs

The `Output/Model_Building/` folder contains intermediate model-building and audit outputs used to validate the provider-impact pipeline.

These files include provider classification summaries; revenue and exposure audits; anomaly review lists; Critical Access Hospital validation outputs; stabilization-tier review files; diagnostic provider-impact outputs; and base scenario outputs used to build the final Table 7 package.

These files are included for transparency. The polished publication outputs are located in `Output/Table7_Publication/`.

## 5. HCRIS Modeling Documentation

The `HCRIS ModelingDocumentation/` folder contains CMS HCRIS documentation and supporting reference files used to interpret hospital cost-report worksheet codes, facility numbering, state codes, crosswalks, and related HCRIS structure.

This documentation supports the FY2024 HCRIS extraction and validation pipeline.

## 6. Federal Scoring and HC-251 Workbooks

The `White paper and H251 outlays/` folder contains the federal scoring workbooks and MEPS HC-251-related materials used in the white paper.

These workbooks support modeling of federal catastrophic credits; federal HSA deposits; federal reinsurance; household catastrophic premium payments; routine-care spending before and after HSE assumptions; ACA subsidy replacement; Medicaid transition savings; consumer savings; provider-facing uncompensated-care effects; bad-debt reduction; and longer-term federal budget projections.

The scoring model distinguishes federal fiscal effects from provider-sector distributional effects. Provider repricing pressure is not automatically treated as a federal budget saving unless tied to a federal outlay, offset, stabilization payment, or other budget-relevant mechanism.

## 7. White Paper

The root directory includes the public PDF version of the white paper:

`Universal Catastrophic Coverage with Health Savings Empowerment White Paper copy.pdf`

The paper presents UCC/HSE as a replacement architecture combining universal catastrophic protection; federally supported HSE/HSA deposits; federal reinsurance; chronic-condition safeguards; pediatric routine-care support; Medicaid LTSS/ABD preservation; Medicare noninterference; employer-market recomposition; provider-sector recomposition; rural access stabilization; behavioral-health institutional protection; supplemental-coverage guardrails; and statutory fiscal controls.

## Reproducing the Provider-Impact Model

A reviewer can use either the full raw-data pipeline or the processed public files.

### Option A: Reproduce from processed public files

Use the curated `.rds` files in `Processed_Public/` to inspect and reproduce provider-impact outputs without downloading raw HCRIS files.

### Option B: Rebuild from raw CMS HCRIS files

To rebuild the full pipeline from raw CMS HCRIS data, download the FY2024 CMS HCRIS hospital cost-report files, place the raw files in the local HCRIS raw-data folder expected by `Scripts/00_setup.R`, edit the project path in `Scripts/00_setup.R` if needed, and run the scripts sequentially from `00_install_required_packages.R` through the Table 7 output scripts.

The full workflow was developed in R/RStudio.

## R Package Dependencies

The model uses standard R packages, including:

`data.table`
`readr`
`readxl`
`openxlsx`
`writexl`
`dplyr`
`tidyr`
`stringr`
`lubridate`
`janitor`
`here`
`tools`

The package installation script is:

`Scripts/00_install_required_packages.R`

## Git LFS

Large files are tracked using Git LFS, including selected `.rds`, `.xlsx`, `.pdf`, and image files.

Reviewers cloning the repository should install Git LFS before pulling large files:

`git lfs install`
`git clone <repository-url>`

## Data Availability

Raw CMS HCRIS files are not included. They are publicly available from CMS.

Processed public provider-level model files are included in `Processed_Public/`.

The white paper PDF, scoring workbooks, publication tables, figures, manifests, and methodology notes are included in the repository.

## Suggested Citation

Alphson, Bennett K. **Universal Catastrophic Coverage with Health Savings Empowerment: A Structural Replacement for the ACA.** Working paper, 2026.

If citing the repository, cite the GitHub repository URL and commit hash used for replication.

## Author

**Bennett K. Alphson, MSc**
Independent Policy Designer and Health Systems Analyst
Author and Principal Developer of the UCC/HSE Model

## License and Use

© 2026 Bennett K. Alphson. All rights reserved.

This repository is provided for public review, replication, and policy analysis. No part of the repository should be interpreted as an official CBO score, CMS analysis, actuarial certification, or government agency determination.
