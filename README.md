# Universal-Catastrophic-Coverage-with-Health-Savings-Empowerment-A-Structural-Replacement-for-the-ACA
Reproducible R and Excel modeling framework for UCC/HSE, including FY2024 HCRIS-based provider-impact scoring, stabilization-tier analysis, rural and behavioral access-protection modeling, and CBO-style federal outlay/savings projections.



UCC/HSE Provider Impact and Federal Scoring Model

This repository contains the analytical code, scoring outputs, and documentation files supporting the provider-impact and federal-budget modeling for Universal Catastrophic Coverage with Health Savings Empowerment (UCC/HSE), a proposed structural replacement for the Affordable Care Act’s comprehensive-insurance subsidy architecture.

The project includes a reproducible R-based workflow for analyzing FY2024 CMS HCRIS hospital cost-report data, deriving provider-level exposure to routine/outpatient repricing, constructing stabilization tiers, modeling rural and behavioral-health access protections, and generating publication-ready Table 7 outputs for the accompanying white paper.

The repository also includes the CBO-style scoring workbook and related documentation used to estimate federal outlays, savings, consumer savings, catastrophic-credit costs, HSA deposits, reinsurance, routine-care savings, uncompensated-care effects, bad-debt reduction, and longer-term federal budget projections. The white paper frames UCC/HSE as a system in which catastrophic and high-acuity care remains insured while routine care is financed through transparent, HSA-based purchasing. It reports UCC/HSE federal financing through catastrophic credits, HSA deposits, and federal reinsurance, replacing ACA premium tax credits, cost-sharing reductions, exchange subsidies, and the employer tax preference for comprehensive coverage.

Repository Contents
1. HCRIS Provider-Impact Model

The provider-impact model is implemented through a 27-script R pipeline. The scripts load raw FY2024 CMS HCRIS files, create a provider-level backbone, extract identity, revenue, beds/capacity, S-10 uncompensated-care data, G-2/G-3 revenue variables, validate provider classifications, construct stabilization eligibility, run provider-impact scenarios, audit coverage and exposure anomalies, and generate publication-grade tables and figures. The combined script file lists the full workflow from 00_install_required_packages.R through 15_make_table7_publication_grade_tables.R.

Core model components include:

FY2024 HCRIS hospital cost-report ingestion.
Provider master construction.
HCRIS G-2/G-3 revenue extraction.
Net outpatient exposure calculation.
S-10 uncompensated-care extraction.
Provider classification correction.
Stabilization-tier assignment.
Rural access sensitivity analysis.
Behavioral/psychiatric provider sensitivity analysis.
Pediatric provider handling and fallback logic.
Table 7 publication-output generation.
Provider-level audit and exposure-anomaly testing.
2. Provider Stabilization and Access-Protection Outputs

The model supports a stabilized provider-transition framework rather than a simple unstabilized provider-revenue-loss estimate. It evaluates provider impact before and after targeted stabilization, including:

Bounded Tier 1–4 stabilization.
Children’s/pediatric provider treatment.
Rural / CAH / IHS access protection.
Behavioral and psychiatric institutional repricing adjustment.
Tier 3 / Tier 4 severe transition-risk review.
Supplementary provider-level review tables.

The final main-body output is designed around a stabilized provider-impact model rather than the diagnostic baseline alone. The baseline HCRIS result identifies routine/outpatient revenue pressure, while the stabilized model applies targeted access protections without eliminating the central price-discipline mechanism.

3. CBO-Style Federal Scoring Workbook

The repository includes the UCC/HSE CBO-style workbook used to model:

Federal catastrophic credits.
Federal HSA deposits.
Federal reinsurance.
Household catastrophic premium payments.
Routine-care spending before and after HSE assumptions.
ACA subsidy replacement.
Medicaid transition savings.
Employer-market effects.
Consumer savings.
Provider-facing uncompensated-care and bad-debt effects.
Ten-, twenty-, and thirty-year budget projections.

The workbook and white paper distinguish federal fiscal scoring from provider-sector distributional effects. Provider repricing pressure is treated as a provider-sector impact, not automatically as a federal budget outlay or saving unless tied to federally financed stabilization or access-support payments.

4. White Paper and Supporting Documentation

The repository supports the accompanying white paper:

Universal Catastrophic Coverage with Health Savings Empowerment: A Structural Replacement for the ACA

The white paper presents UCC/HSE as a replacement architecture combining universal catastrophic protection, federally supported HSA deposits, chronic-condition safeguards, Medicaid LTSS/ABD preservation, Medicare noninterference, employer-market recomposition, provider-sector recomposition, rural stabilization, supplemental-coverage guardrails, and federal fiscal controls.

Supporting documentation includes:

White paper drafts.
CBO baseline reference materials.
Prior project chat exports.
Provider-impact methodology appendix.
Table 7 main and appendix outputs.
Combined R script documentation.
Publication-grade table and figure outputs.
Analytical Purpose

This repository is intended to provide a reproducible analytical basis for evaluating UCC/HSE’s provider-sector and federal-budget implications. It is not a final CBO score, actuarial certification, or hospital-closure forecast. It is a transparent modeling framework designed to support policy review, stress testing, replication, and further refinement by economists, health-policy analysts, congressional staff, actuaries, and institutional reviewers.


# Processed Public Master Files

This folder contains curated processed `.rds` files used to reproduce the UCC/HSE HCRIS provider-impact tables without rerunning the full raw HCRIS extraction pipeline.

Raw CMS HCRIS files are not included in this repository. The full pipeline can be rerun from raw FY2024 HCRIS files using the scripts in `/Scripts`, but these master files allow reviewers to reproduce Table 7 outputs directly from the cleaned provider-level objects.

Included files:
- `provider_master_final.rds`
- `provider_financial_master_final.rds`
- `provider_master_with_stabilization.rds`
- `provider_impact_scenarios_all.rds`
- `provider_impact_basebase.rds`
- `table7_access_protection_summary.rds`
