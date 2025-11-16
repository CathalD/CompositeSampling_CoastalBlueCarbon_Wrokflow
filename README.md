# 🌊 Blue Carbon Composite Sampling & MMRV Workflow

**A comprehensive R-based workflow for coastal blue carbon monitoring, reporting, and verification (MMRV) compliant with VM0033, ORRAA, IPCC, and Canadian standards.**

[![VM0033 Compliant](https://img.shields.io/badge/VM0033-Compliant-brightgreen)]()
[![ORRAA](https://img.shields.io/badge/ORRAA-High%20Quality-blue)]()
[![License](https://img.shields.io/badge/license-MIT-orange)]()

---

## 📋 Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
- [Prerequisites](#prerequisites)
- [Workflow Structure](#workflow-structure)
  - [Part 1: Sampling Design & Bayesian Priors (GEE)](#part-1-sampling-design--bayesian-priors-gee)
  - [Part 2: Sample Analysis](#part-2-sample-analysis)
  - [Part 3: Temporal Monitoring & Scenario Projection](#part-3-temporal-monitoring--scenario-projection)
  - [Part 4: Bayesian Analysis (Optional)](#part-4-bayesian-analysis-optional)
- [Quick Start](#quick-start)
- [Standards Compliance](#standards-compliance)
- [Output Files](#output-files)
- [Ecosystem Adaptation](#ecosystem-adaptation)
- [Citation](#citation)

---

## 🎯 Overview

This workflow provides a **complete analytical pipeline** for coastal blue carbon stock assessment in tidal wetlands, salt marshes, and seagrass ecosystems. Designed for **carbon credit development and verification** under the Verra VM0033 methodology.

**Target Ecosystems:** Salt marshes, tidal wetlands, seagrass beds, mangroves
**Geographic Focus:** Coastal British Columbia, Canada (adaptable globally)
**Carbon Pools:** Soil organic carbon (0-100 cm depth)

**Use Cases:**
- Carbon credit project development (VM0033)
- Baseline carbon stock assessment
- Restoration monitoring (temporal change detection)
- Additionality verification (PROJECT vs. BASELINE)

---

## ⭐ Key Features

✅ **VM0033 Compliant** - Conservative estimates, stratum-specific calculations, 95% confidence intervals
✅ **Multi-Method Spatial Prediction** - Random Forest (stratum-aware) and Ordinary Kriging
✅ **Bayesian Prior Integration** - SoilGrids + regional data via Google Earth Engine
✅ **Depth Harmonization** - True equal-area spline to VM0033 standard depths (0-15, 15-30, 30-50, 50-100 cm)
✅ **Comprehensive QA/QC** - Automated flagging, cross-validation, uncertainty quantification
✅ **Standards Compliance Checking** - Automated assessment against 4 major standards
✅ **Actionable Recommendations** - Data-driven guidance on additional sampling needs
✅ **Temporal Analysis** - Baseline vs. project scenario comparisons with additionality calculation
✅ **Full MMRV Reporting** - HTML verification packages, Excel tables, spatial exports

---

## 🔧 Prerequisites

### Software Requirements

- **R** (≥ 4.0.0) - Statistical computing
- **RStudio** (recommended) - IDE
- **Google Earth Engine** account - For Part 1 (Bayesian priors and covariate extraction)

### R Package Dependencies

```r
# Install all required packages
install.packages(c(
  # Core spatial
  "terra", "sf", "sp", "raster",

  # Data manipulation
  "dplyr", "tidyr", "readr",

  # Visualization
  "ggplot2", "gridExtra",

  # Spatial modeling
  "gstat", "automap", "randomForest", "caret", "CAST",

  # Depth harmonization
  "ithir", "GSIF", "mpspline2",

  # Optional (enhanced outputs)
  "openxlsx", "knitr", "rmarkdown"
))
```

---

## 🗺️ Workflow Structure

The workflow consists of **4 parts** with **17 modules** total. Parts 1, 3, and 4 are optional depending on project needs.

---

## PART 1: Sampling Design & Bayesian Priors (GEE)

**🎯 Purpose:** Design optimal sampling strategy using Bayesian priors and extract environmental covariates
**🛠️ Platform:** Google Earth Engine (JavaScript)
**⏱️ When to use:** Before field sampling, or when you want to reduce uncertainty with global priors

### Modules

#### **Module 00A: GEE Covariate Extraction**
**File:** `GEE_EXTRACT_COVARIATES.js`

**What it does:**
- Extracts environmental covariates from satellite imagery and global datasets
- Prepares spatial predictors for Random Forest modeling (Part 2)

**Covariates extracted:**
- 🛰️ **Sentinel-2:** NDVI, NDWI, spectral bands (R, G, B, NIR)
- 🗻 **Topography:** Elevation, slope, aspect, Topographic Wetness Index (TWI)
- 🌡️ **Climate:** Mean annual temperature, precipitation
- 🌊 **Tidal:** Distance to water, inundation frequency
- 🏞️ **Landscape:** Distance to edge, patch metrics

**Outputs:**
```
data_raw/gee_covariates/
├── sentinel2_ndvi.tif
├── sentinel2_ndwi.tif
├── elevation.tif
├── slope.tif
├── twi.tif
└── ...
```

**How to run:**
1. Open Google Earth Engine Code Editor
2. Load `GEE_EXTRACT_COVARIATES.js`
3. Define your study area boundary
4. Run script → exports to Google Drive
5. Download to `data_raw/gee_covariates/`

---

#### **Module 00B: GEE Bayesian Prior Export**
**File:** `GEE_EXPORT_BAYESIAN_PRIORS.js`

**What it does:**
- Exports SoilGrids 250m soil organic carbon data as Bayesian priors
- Converts SOC concentration (g/kg) to carbon stocks (kg/m²) for VM0033 depths
- Includes uncertainty estimates (standard error)

**Data source:** SoilGrids 2.0 (ISRIC)

**Depths processed:**
- 7.5 cm (midpoint of 0-15 cm layer)
- 22.5 cm (midpoint of 15-30 cm layer)
- 40 cm (midpoint of 30-50 cm layer)
- 75 cm (midpoint of 50-100 cm layer)

**Outputs:**
```
data_prior/
├── carbon_stock_prior_mean_7_5cm.tif    # Mean carbon stock (kg/m²)
├── carbon_stock_prior_se_7_5cm.tif      # Standard error (kg/m²)
├── carbon_stock_prior_mean_22_5cm.tif
├── carbon_stock_prior_se_22_5cm.tif
└── ... (8 files total)
```

**How to run:**
1. Open GEE Code Editor
2. Load `GEE_EXPORT_BAYESIAN_PRIORS.js`
3. Define study area
4. Run script → exports to Google Drive
5. Download to `data_prior/`

**Why use Bayesian priors?**
- Reduces sampling requirements (fewer cores needed)
- Improves estimates in undersampled strata
- Quantifies value of field data vs. existing knowledge
- Enables Neyman allocation (optimal sample placement)

---

#### **Module 00C: Bayesian Prior Setup**
**File:** `00c_bayesian_prior_setup_bluecarbon.R`

**What it does:**
- Loads GEE-exported priors
- Resamples to match field data resolution
- Aligns coordinate systems
- Validates prior quality

**Outputs:**
- Processed priors ready for Module 06c (Part 4)
- Prior quality report (coverage, range, validity)

**Run:**
```r
source("00c_bayesian_prior_setup_bluecarbon.R")
```

---

## PART 2: Sample Analysis

**🎯 Purpose:** Process field core data and generate spatially-explicit carbon stock estimates
**🛠️ Platform:** R
**⏱️ When to use:** Always (core workflow)

### Modules

#### **Module 01: Data Preparation**
**File:** `01_data_prep_bluecarbon.R`

**What it does:**
- Loads raw field core data (SOC, bulk density, depths)
- Validates data structure and completeness
- **Calculates carbon stocks** using correct formula:
  ```r
  carbon_stock (kg/m²) = SOC (g/kg) × BD (g/cm³) × depth (cm) / 1000
  ```
  ⚠️ **Critical:** Divides by 1000, NOT 10,000 (fixed in this version)

**Input:** `data_raw/field_cores.csv`

**Required columns:**
```csv
core_id, stratum, longitude, latitude, depth_top_cm, depth_bottom_cm, soc_g_kg, bd_g_cm3
```

**Outputs:**
- `data_processed/cores_prepared_bluecarbon.rds`
- Summary statistics by stratum
- Sample size report

**Run:**
```r
source("01_data_prep_bluecarbon.R")
```

---

#### **Module 02: Quality Control**
**File:** `02_qc_bluecarbon.R`

**What it does:**
- Automated QA/QC with flagging system
- Checks for:
  - SOC out of range (0-500 g/kg)
  - Bulk density anomalies (0.1-3.0 g/cm³)
  - Spatial duplicates
  - Statistical outliers (Tukey's fences)
  - Missing required fields

**Outputs:**
- `diagnostics/qc/qc_flags.csv` - Flagged records
- `diagnostics/qc/qc_summary.csv` - Summary by flag type
- Diagnostic plots (box plots, spatial maps)

**Run:**
```r
source("02_qc_bluecarbon.R")
```

---

#### **Module 03: Depth Harmonization**
**File:** `03_depth_harmonization_bluecarbon.R`

**What it does:**
- Harmonizes variable-depth cores to VM0033 standard depths using **equal-area spline**
- Method: ithir package (Bishop et al. 1999)
- Ensures mass-preserving interpolation

**Input depths (variable):** e.g., 0-10, 10-25, 25-50, 50-100 cm
**Output depths (standard):** 7.5, 22.5, 40, 75 cm (VM0033 midpoints)

**Why needed?**
- VM0033 requires standard depth reporting
- Field cores rarely match exact depth intervals
- Equal-area spline preserves total carbon mass

**Outputs:**
- `data_processed/cores_harmonized_bluecarbon.rds`
- Harmonization diagnostic plots
- Uncertainty estimates from spline fitting

**Run:**
```r
source("03_depth_harmonization_bluecarbon.R")
```

---

#### **Module 04: Kriging Predictions**
**File:** `04_raster_predictions_kriging_bluecarbon.R`

**What it does:**
- Ordinary Kriging spatial interpolation
- Stratum-specific variograms
- Cross-validation (3-fold spatial CV)
- Uncertainty propagation (kriging variance)

**Outputs:**
```
outputs/predictions/kriging/
├── carbon_stock_*_8cm.tif       # Predicted carbon stocks (kg/m²)
├── se_combined_*_8cm.tif        # Standard error maps
└── variogram_*_8cm.png          # Variogram plots
```

**Cross-validation results:**
```
diagnostics/crossvalidation/kriging_cv_results.csv
# Contains: depth_cm, stratum, cv_r2, cv_rmse, cv_mae
```

**Run:**
```r
source("04_raster_predictions_kriging_bluecarbon.R")
```

---

#### **Module 05: Random Forest Predictions**
**File:** `05_raster_predictions_rf_bluecarbon.R`

**What it does:**
- Random Forest regression with environmental covariates
- Stratum-aware modeling (separate models per stratum)
- Area of Applicability (AOA) analysis using CAST package
- Variable importance ranking
- Spatial cross-validation

**Covariates used:**
- Sentinel-2 indices (NDVI, NDWI)
- Topography (elevation, slope, TWI)
- Spatial coordinates (UTM X, Y)
- Climate variables (if available)

**Outputs:**
```
outputs/predictions/rf/
├── carbon_stock_rf_8cm.tif      # RF predictions (kg/m²)
├── se_combined_8cm.tif          # Uncertainty (standard error)
├── aoa_8cm.tif                  # Area of applicability (1 = reliable)
└── variable_importance_8cm.png  # Feature importance plot
```

**Cross-validation:**
```
diagnostics/crossvalidation/rf_cv_results.csv
```

**Run:**
```r
source("05_raster_predictions_rf_bluecarbon.R")
```

**RF vs. Kriging:**
| Method | Pros | Cons |
|--------|------|------|
| **RF** | Captures nonlinear relationships, uses covariates, better for complex landscapes | Requires covariate data, can extrapolate poorly (use AOA) |
| **Kriging** | No covariates needed, smooth interpolation, well-understood uncertainty | Assumes stationarity, poor at capturing sharp transitions |

**Recommendation:** Run both, compare in Module 06

---

#### **Module 06: Carbon Stock Aggregation**
**File:** `06_carbon_stock_calculation_bluecarbon.R`

**What it does:**
- Aggregates depth-specific predictions (7.5, 22.5, 40, 75 cm) to 0-100 cm total
- Mass-weighted summation accounting for layer thickness
- Calculates conservative estimates (95% CI lower bound) for VM0033
- Compares RF vs. Kriging methods (if both run)

**Formula:**
```r
Total stock (0-100 cm) =
  stock_7.5cm × 15cm +   # 0-15 cm layer
  stock_22.5cm × 15cm +  # 15-30 cm layer
  stock_40cm × 20cm +    # 30-50 cm layer
  stock_75cm × 50cm      # 50-100 cm layer
```

**Outputs:**
```
outputs/carbon_stocks/
├── carbon_stocks_by_stratum_rf.csv
├── carbon_stocks_by_stratum_kriging.csv
├── carbon_stocks_conservative_vm0033_rf.csv
├── carbon_stocks_conservative_vm0033_kriging.csv
└── carbon_stocks_method_comparison.csv
```

**Key columns:**
- `mean_stock_0_100_Mg_ha` - Mean carbon stock (Mg C/ha)
- `conservative_stock_0_100_Mg_ha` - 95% CI lower bound (VM0033 required)
- `total_stock_0_100_Mg` - Total carbon (Mg C) for stratum/project
- `uncertainty_pct` - Relative uncertainty (%)

**Run:**
```r
source("06_carbon_stock_calculation_bluecarbon.R")
```

---

#### **Module 07: VM0033 Verification Package**
**File:** `07_mmrv_reporting_bluecarbon.R`

**What it does:**
- Generates VM0033-compliant verification outputs
- Creates submit-ready documentation for third-party verifier

**Outputs:**
```
outputs/mmrv_reports/
├── vm0033_verification_package.html   # Main verification document
├── vm0033_summary_tables.xlsx         # Formatted tables
├── qaqc_flagged_areas.csv             # Quality control flags
└── spatial_exports/                   # GIS-ready shapefiles/rasters
```

**Run:**
```r
source("07_mmrv_reporting_bluecarbon.R")
```

---

#### **Module 07b: Comprehensive Standards Compliance Report** ⭐ NEW

**File:** `07b_comprehensive_standards_report.R`

**What it does:**
- **Automated compliance checking** against 4 major standards
- **Calculates exact additional samples needed** using statistical formulas
- **Generates prioritized recommendations** (HIGH/MEDIUM/LOW)
- **Produces professional HTML report** with color-coded pass/fail indicators

**Standards assessed:**

1️⃣ **VM0033 (Verra)** - 6 criteria:
   - ✓ Minimum 3 cores per stratum
   - ✓ Target precision ≤20% relative error (95% CI)
   - ✓ Standard depths: 7.5, 22.5, 40, 75 cm
   - ✓ Conservative estimates (95% CI lower bound)
   - ✓ Cross-validation performed
   - ✓ Verification frequency (5 years)

2️⃣ **ORRAA High Quality Blue Carbon** - 4 principles:
   - ✓ Site-specific field measurements
   - ✓ Stratum-specific assessments
   - ✓ Uncertainty quantification (95% CI)
   - ✓ Transparency and documentation

3️⃣ **IPCC Wetlands Supplement**:
   - ✓ Tier 3 approach (site-specific data)
   - ✓ Conservative approach for uncertainty

4️⃣ **Canadian Blue Carbon Network**:
   - ✓ Regional context integration
   - ✓ Spatial validation (R² ≥ 0.5)
   - ✓ Provincial reporting compatibility

**Example output:**

```
Standards Compliance Summary:
─────────────────────────────────
✓ VM0033: 83% (5/6 checks passed)
✓ ORRAA: 100% (4/4 checks passed)
✓ IPCC: 100% (2/2 checks passed)
✓ Canadian: 100% (3/3 checks passed)

HIGH PRIORITY RECOMMENDATIONS (1):
───────────────────────────────────
• Collect 2 additional cores in 'Upper Marsh' to meet VM0033
  minimum (currently 1/3 cores)

MEDIUM PRIORITY RECOMMENDATIONS (2):
─────────────────────────────────────
• Add ~8 cores in 'Lower Marsh' to reduce uncertainty from
  25.3% to target 20% (formula: n = (1.96 × 30 / 20)² = 9 cores)
• Improve RF model performance (R² = 0.45). Consider:
  (1) Adding environmental covariates, (2) Increasing sampling
```

**Outputs:**
```
outputs/reports/
├── comprehensive_standards_report.html      # Full report (open in browser)
├── standards_compliance_summary.csv         # Pass/fail scorecard
└── recommendations_action_plan.csv          # Prioritized actions
```

**Run:**
```r
source("07b_comprehensive_standards_report.R")
```

**💡 Pro tip:** Run Module 07b **last** to get final compliance assessment and guidance on next steps!

---

## PART 3: Temporal Monitoring & Scenario Projection

**🎯 Purpose:** Compare carbon stocks across time periods or scenarios (BASELINE vs. PROJECT)
**🛠️ Platform:** R
**⏱️ When to use:** When you have multi-year data or need additionality assessment for carbon credits

### Modules

#### **Module 08: Temporal Data Harmonization**
**File:** `08_temporal_data_harmonization.R`

**What it does:**
- Harmonizes datasets from different years/scenarios
- Ensures spatial and temporal alignment
- Handles different sampling designs across time

**Scenarios supported:**
- `BASELINE` - Pre-restoration condition
- `PROJECT` - Post-restoration condition
- `CONTROL` - No-intervention reference site
- `DEGRADED` - Degraded ecosystem (lower bound)
- `REFERENCE` - Healthy ecosystem (upper bound)
- `PROJECT_Y1`, `PROJECT_Y5`, `PROJECT_Y10` - Restoration trajectories

**Input:**
Multiple runs of Part 2 for different scenarios/years

**Outputs:**
- `data_processed/temporal_harmonized.rds`
- Temporal alignment report

**Run:**
```r
source("08_temporal_data_harmonization.R")
```

---

#### **Module 08A: Scenario Modeling** (Optional)
**File:** `08a_scenario_modeling_bluecarbon.R`

**What it does:**
- Generates synthetic scenarios when field data unavailable
- Uses reference trajectories and Canadian literature
- Models recovery curves (exponential, linear, logistic)

**Use case:**
You have BASELINE (2020) and PROJECT_Y0 (2022) data, but VM0033 requires PROJECT_Y5 (2027) estimates → model the trajectory

**Methods:**
- Exponential recovery model (fast initial, slowing)
- Space-for-time substitution (chronosequence)
- Canadian Blue Carbon Network parameter database

**Run:**
```r
source("08a_scenario_modeling_bluecarbon.R")
```

---

#### **Module 09: Temporal Change Analysis**
**File:** `09_temporal_change_analysis.R`

**What it does:**
- Detects significant changes in carbon stocks over time
- Statistical tests: paired t-tests, linear mixed models
- Spatial change mapping

**Outputs:**
- Change detection maps (Δ carbon stock)
- Temporal trend plots
- Significance testing results

**Run:**
```r
source("09_temporal_change_analysis.R")
```

---

#### **Module 10: Additionality Assessment**
**File:** `10_additionality_bluecarbon.R`

**What it does:**
- Calculates **creditable carbon gains** = PROJECT - BASELINE
- Conservative approach: 95% CI lower bound of difference
- Accounts for uncertainty in both scenarios
- Generates additionality maps

**Formula:**
```r
Additionality = (μ_PROJECT - μ_BASELINE) - 1.96 × √(σ²_PROJECT + σ²_BASELINE)
```

**Outputs:**
```
outputs/additionality/
├── creditable_carbon_stocks.csv          # Conservative creditable stocks
├── additionality_map.tif                 # Spatial distribution of gains
└── additionality_uncertainty.tif         # Uncertainty in additionality
```

**Run:**
```r
source("10_additionality_bluecarbon.R")
```

---

## PART 4: Bayesian Analysis (Optional)

**🎯 Purpose:** Reduce uncertainty by combining global priors (SoilGrids) with field data
**🛠️ Platform:** R
**⏱️ When to use:** Small sample sizes (n < 10 per stratum), high uncertainty, undersampled areas

### Module 06c: Bayesian Posterior Estimation

**File:** `06c_bayesian_posterior_estimation_bluecarbon.R`

**What it does:**
- Combines Bayesian priors (from Part 1) with field-based likelihood (from Part 2)
- Generates posterior estimates with reduced uncertainty
- Quantifies information gain from field sampling

**Theory:**

**Precision-weighted Bayesian update:**
```
Prior × Likelihood → Posterior

τ_prior = 1/σ²_prior    (prior precision)
τ_field = 1/σ²_field    (field precision)

μ_posterior = (τ_prior·μ_prior + τ_field·μ_field) / (τ_prior + τ_field)
σ²_posterior = 1 / (τ_prior + τ_field)

Uncertainty reduction = (1 - σ_posterior / σ_prior) × 100%
```

**Inputs:**
- Priors: `data_prior/carbon_stock_prior_mean_*.tif` (from Module 00B/00C)
- Likelihood: `outputs/predictions/rf/` or `kriging/` (from Module 04/05)

**Outputs:**
```
outputs/predictions/posterior/
├── carbon_stock_posterior_mean_7_5cm.tif    # Posterior estimates (kg/m²)
├── carbon_stock_posterior_se_7_5cm.tif      # Reduced uncertainty
├── ...
└── (8 files for 4 depths)

diagnostics/bayesian/
├── uncertainty_reduction.csv                # Quantified uncertainty reduction
└── prior_likelihood_posterior_comparison.png  # Visualization
```

**Enable in config:**
```r
# In blue_carbon_config.R
USE_BAYESIAN <- TRUE
```

**Run:**
```r
source("06c_bayesian_posterior_estimation_bluecarbon.R")
```

**Benefits:**
- ✅ Reduces uncertainty without additional field sampling
- ✅ Leverages global soil knowledge (SoilGrids 250m)
- ✅ Particularly effective in undersampled strata
- ✅ Quantifies value of field data (information gain)

**Example results:**
```
Uncertainty Reduction:
  7.5 cm: 35.2% (0.45 → 0.29 kg/m² SE)
  22.5 cm: 28.7% (0.38 → 0.27 kg/m² SE)
  40 cm: 22.1% (0.32 → 0.25 kg/m² SE)
  75 cm: 18.5% (0.28 → 0.23 kg/m² SE)

Overall mean reduction: 26.1%
✓ Information gain exceeds threshold (>20%)
  Prior was informative - Bayesian update successful
```

**When NOT to use:**
- Large sample sizes (n > 30 per stratum) - field data dominates, priors add little
- Priors don't cover study area (e.g., outside SoilGrids coverage)
- Strong mismatch between prior and field data (inspect diagnostics first)

---

## 🚀 Quick Start

### Minimum Workflow (No Bayesian)

**Execution order:**
```
01 → 02 → 03 → (04 or 05) → 06 → 07 → 07b
```

**Time:** ~2-4 hours for small dataset (<50 cores)

```r
# Configure
# Edit blue_carbon_config.R with your project settings

# Run Part 2
source("01_data_prep_bluecarbon.R")
source("02_qc_bluecarbon.R")
source("03_depth_harmonization_bluecarbon.R")
source("05_raster_predictions_rf_bluecarbon.R")  # or 04 for Kriging
source("06_carbon_stock_calculation_bluecarbon.R")
source("07_mmrv_reporting_bluecarbon.R")
source("07b_comprehensive_standards_report.R")

# Open HTML report
browseURL("outputs/reports/comprehensive_standards_report.html")
```

---

### Full Workflow with Bayesian

**Execution order:**
```
Part 1: 00B (GEE) → 00C
Part 2: 01 → 02 → 03 → 04 & 05 → 06c → 06 → 07 → 07b
```

```r
# Part 1: Run in Google Earth Engine
# GEE_EXPORT_BAYESIAN_PRIORS.js → download to data_prior/

# Part 1: Process priors
source("00c_bayesian_prior_setup_bluecarbon.R")

# Part 2: Standard workflow
source("01_data_prep_bluecarbon.R")
source("02_qc_bluecarbon.R")
source("03_depth_harmonization_bluecarbon.R")
source("04_raster_predictions_kriging_bluecarbon.R")
source("05_raster_predictions_rf_bluecarbon.R")

# Part 4: Bayesian posterior (before aggregation!)
source("06c_bayesian_posterior_estimation_bluecarbon.R")

# Part 2 continued: Aggregate using posterior estimates
# (Modify Module 06 to read from outputs/predictions/posterior/)
source("06_carbon_stock_calculation_bluecarbon.R")
source("07_mmrv_reporting_bluecarbon.R")
source("07b_comprehensive_standards_report.R")
```

---

### With Temporal Analysis

**Execution order:**
```
[Run Part 2 for BASELINE] → [Run Part 2 for PROJECT] → Part 3
```

```r
# Run Part 2 twice with different scenarios
# 1. BASELINE scenario (e.g., 2020 data)
PROJECT_SCENARIO <- "BASELINE"
source("01_data_prep_bluecarbon.R")
# ... through Module 07b

# 2. PROJECT scenario (e.g., 2024 data)
PROJECT_SCENARIO <- "PROJECT"
source("01_data_prep_bluecarbon.R")
# ... through Module 07b

# Part 3: Temporal analysis
source("08_temporal_data_harmonization.R")
source("09_temporal_change_analysis.R")
source("10_additionality_bluecarbon.R")
```

---

## 📊 Standards Compliance

### VM0033 (Verra) Requirements ✅

| Requirement | Threshold | Module |
|-------------|-----------|--------|
| Minimum samples per stratum | ≥3 cores | 01, 07b |
| Target precision | ≤20% relative error (95% CI) | 06, 07b |
| Standard depths | 0-15, 15-30, 30-50, 50-100 cm | 03 |
| Conservative estimates | 95% CI lower bound | 06 |
| Cross-validation | Required for spatial predictions | 04, 05 |
| Verification frequency | Every 5 years | 08, 09 |

**Check compliance:** Run Module 07b

---

## 📁 Output Files

### Key Outputs

```
project_root/
├── outputs/
│   ├── predictions/
│   │   ├── rf/                        # Random Forest predictions
│   │   │   ├── carbon_stock_rf_8cm.tif      (kg/m²)
│   │   │   ├── se_combined_8cm.tif          (standard error)
│   │   │   └── aoa_8cm.tif                  (area of applicability)
│   │   ├── kriging/                   # Kriging predictions
│   │   └── posterior/                 # Bayesian posterior (Part 4)
│   ├── carbon_stocks/
│   │   ├── carbon_stocks_conservative_vm0033_rf.csv  ⭐ Main results
│   │   └── carbon_stocks_by_stratum_rf.csv
│   ├── mmrv_reports/
│   │   └── vm0033_verification_package.html
│   └── reports/
│       ├── comprehensive_standards_report.html       ⭐ Standards compliance
│       ├── standards_compliance_summary.csv
│       └── recommendations_action_plan.csv
├── diagnostics/
│   ├── crossvalidation/
│   │   ├── rf_cv_results.csv          # Model performance
│   │   └── kriging_cv_results.csv
│   └── bayesian/
│       └── uncertainty_reduction.csv   # Bayesian diagnostics
└── data_processed/
    ├── cores_prepared_bluecarbon.rds
    └── cores_harmonized_bluecarbon.rds
```

---

## 🌍 Ecosystem Adaptation

This workflow can be adapted for other Canadian ecosystems:

### 1. **Grasslands** (Prairies, Rangelands)
- Change depths: 0-15, 15-30, 30-50 cm (shallower focus)
- Update strata: Native Prairie, Improved Pasture, Degraded Grassland
- Standards: VCS VM0026, Alberta TIER offsets
- Key variables: Grazing history, root biomass, soil texture

### 2. **Peatlands** (Bogs, Fens, Swamps)
- Change depths: 0-30, 30-100, 100-200, 200-300 cm (much deeper)
- Update strata: Ombrotrophic Bog, Minerotrophic Fen, Treed Peatland
- Standards: VCS VM0036
- Key variables: Peat depth, water table, von Post scale
- Bulk density: 0.05-0.3 g/cm³ (much lower than marine)

### 3. **Forests** (Boreal, Temperate, Coastal)
- Change depths: LFH layer (0-5 cm organic), 0-30 cm mineral soil
- Update strata: Boreal Spruce, Mixedwood, Coastal Rainforest
- Standards: VCS VM0012, VM0042
- Key variables: LFH thickness, coarse fragments, tree age

### 4. **Arctic/Subarctic Wetlands** (Permafrost)
- Change depths: Active layer (0-50 cm), permafrost (>50 cm)
- Update strata: Polygonal Tundra, Palsa, Thermokarst Fen
- Standards: Adapted VM0036 + permafrost protocols
- Key variables: Active layer depth, ground ice, thaw degree days

**See full adaptation guides in project documentation.**

---

## 📚 Citation

If you use this workflow, please cite:

```bibtex
@software{bluecarbon_mmrv_2024,
  title = {Blue Carbon Composite Sampling \& MMRV Workflow},
  author = {[Your Name]},
  year = {2024},
  url = {https://github.com/[your-repo]/CompositeSampling_CoastalBlueCarbon_Workflow},
  note = {VM0033-compliant coastal blue carbon assessment for British Columbia, Canada}
}
```

**Standards:**
- Verra (2020). VM0033 Methodology for Tidal Wetland and Seagrass Restoration v2.0
- IPCC (2013). 2013 Supplement to the 2006 IPCC Guidelines: Wetlands
- ORRAA (2021). High Quality Blue Carbon Principles and Guidance

**Methods:**
- Bishop et al. (1999). Equal-area spline depth functions. *Geoderma* 91:27-45
- Meyer & Pebesma (2021). Area of Applicability. *Methods in Ecology and Evolution* 12:1620-1633

---

## 📝 License

[Specify license - e.g., MIT, GPL-3, CC-BY-4.0]

---

## 📧 Contact

**Project Lead:** [Your Name]
**Institution:** [Your Institution]
**Email:** [email@domain.com]
**Region:** Coastal British Columbia, Canada

---

## 🙏 Acknowledgments

- **Verra** - VM0033 methodology framework
- **ISRIC** - SoilGrids global soil information
- **Google Earth Engine** - Cloud geospatial processing
- **Canadian Blue Carbon Network** - Regional guidance
- **R Community** - Open-source spatial tools (terra, sf, CAST, ithir)

---

**Last Updated:** November 2024
**Workflow Version:** 1.0
**Tested on:** R 4.3+, Ubuntu 20.04, macOS 12+, Windows 10+

---

*For technical support, see module-specific documentation in script headers. For VM0033 compliance questions, consult Verra methodology document.*
