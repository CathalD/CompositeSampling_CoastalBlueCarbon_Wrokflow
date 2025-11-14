# 🌊 BC Coastal Blue Carbon Workflow Guide
## Complete Step-by-Step Guide for Carbon Credit Development

**Project:** BC_Coastal_BlueCarbon_2024
**Location:** Chemainus Estuary, British Columbia, Canada
**Objective:** VM0033-compliant carbon stock assessment for carbon credit verification

---

## 📁 STARTING FILE STRUCTURE

Before you begin, your project should look like this:

```
CompositeSampling_CoastalBlueCarbon_Wrokflow/
│
├── blue_carbon_config.R           # ✅ CONFIGURED FOR BC
├── core_locations.csv             # ✅ YOUR FIELD DATA (9 cores)
├── core_samples.csv               # ✅ YOUR LAB DATA (depth profiles)
│
├── covariates/                    # ⚠️ ADD YOUR GEE EXPORTS HERE
│   ├── optical/
│   │   ├── ndvi.tif              # Required
│   │   ├── evi.tif               # Required
│   │   ├── ndwi.tif              # Required
│   │   ├── mndwi.tif             # Optional
│   │   └── savi.tif              # Optional
│   ├── sar/
│   │   ├── vv_median.tif         # Recommended
│   │   ├── vh_median.tif         # Recommended
│   │   └── vv_vh_ratio.tif       # Optional
│   ├── topography/
│   │   ├── elevation.tif         # Required
│   │   └── slope.tif             # Recommended
│   └── coastal/
│       ├── tidal_range.tif       # Optional but valuable
│       └── dist_to_water.tif     # Optional
│
├── data_raw/
│   └── (your CSVs can also go here)
│
└── data_prior/                    # Only if using Bayesian (Part 4)
    └── gee_exports/
        ├── soc_prior_mean_7_5cm.tif
        ├── soc_prior_se_7_5cm.tif
        └── (etc. for all 4 depths)
```

---

## 🚀 PART 2: CORE WORKFLOW

### MODULE 00a: Package Installation
**Run:** `source("00a_install_packages_v2.R")`

**What it does:**
Installs all required R packages for spatial analysis, statistical modeling, and reporting. Includes terra, sf, ranger (Random Forest), gstat (kriging), tidyverse, and rmarkdown.

**Expected duration:** 5-10 minutes (first time only)

**What to expect:**
You'll see package installation messages. Some packages compile from source (normal on Linux/Mac). If errors occur, they're usually missing system dependencies (gdal, proj, geos).

**Outputs:**
- Packages installed to your R library
- No files created

**What to look for:**
- Confirmation message: "All packages installed successfully ✓"
- No ERROR messages (warnings are OK)

---

### MODULE 00b: Directory Setup
**Run:** `source("00b_setup_directories.R")`

**What it does:**
Creates the complete output directory structure for all workflow modules. Organizes outputs into logical folders for diagnostics, predictions, carbon stocks, and reports.

**Expected duration:** < 5 seconds

**What to expect:**
Creates ~20 subdirectories. Safe to re-run (won't delete existing files).

**File structure CREATED:**
```
outputs/
├── predictions/
│   ├── kriging/              # Module 04 outputs
│   └── rf/                   # Module 05 outputs (Random Forest)
├── carbon_stocks/            # Module 06 outputs
├── mmrv_reports/             # Module 07 outputs (your verification package!)
└── temporal/                 # Modules 08-10 (if doing multi-year analysis)

diagnostics/
├── data_prep/                # Module 01 QC outputs
├── exploratory/              # Module 02 visualizations
├── depth_harmonization/      # Module 03 spline fits
├── kriging/                  # Module 04 diagnostics
├── rf/                       # Module 05 model performance
└── crossvalidation/          # CV results

data_processed/               # Intermediate data files (RDS format)
```

**What to look for:**
- Message: "Directory structure created successfully"
- Verify folders exist: `ls outputs/`

---

### MODULE 01: Data Preparation & QC
**Run:** `source("01_data_prep_bluecarbon.R")`

**What it does:**
Loads your field data (core_locations.csv, core_samples.csv), performs comprehensive quality control checks, validates VM0033 compliance (minimum 3 cores per stratum), and compares HR cores vs composites (if you have both). This is your data integrity checkpoint.

**Expected duration:** 10-30 seconds

**What to expect:**
Console output showing: number of cores loaded, QC flags (out-of-range values), stratum distribution, VM0033 compliance status, and HR vs Composite statistical comparison.

**File structure CREATED:**
```
diagnostics/data_prep/
├── core_locations_map.png           # Map of your sampling locations
├── stratum_distribution.png         # Bar chart: cores per stratum
├── vm0033_compliance_report.csv     # VM0033 requirements check
├── bulk_density_transparency.csv    # Measured vs estimated BD
├── qc_flagged_samples.csv          # Any problematic values
└── hr_vs_composite_comparison.csv   # Statistical tests (if applicable)

data_processed/
└── cores_prepared_bluecarbon.rds    # Clean data for next modules
```

**What to look for:**
- ✅ "VM0033 compliance: PASS" (need ≥3 cores per stratum)
- ✅ "QC flags: 0" (no out-of-range values)
- ✅ Check `core_locations_map.png` - cores well-distributed?
- ⚠️ If compliance fails: need more cores in undersampled strata
- 📊 Your data: 9 HR cores across 4 strata (Upper/Mid/Lower Marsh + Underwater Veg)

---

### MODULE 02: Exploratory Data Analysis
**Run:** `source("02_exploratory_analysis_bluecarbon.R")`

**What it does:**
Generates comprehensive visualizations and statistical summaries of your carbon data. Creates depth profiles by stratum, correlation heatmaps between SOC and bulk density, and identifies ecological patterns. This helps you understand your ecosystem before modeling.

**Expected duration:** 30-60 seconds

**What to expect:**
Plots showing carbon decreasing with depth (typical), stratum differences (Lower Marsh often highest SOC), and bulk density patterns. Statistical summaries reveal mean/median/CV for each stratum.

**File structure CREATED:**
```
diagnostics/exploratory/
├── depth_profiles_by_stratum.png    # SOC vs depth for each ecosystem type
├── soc_boxplots_by_stratum.png     # Compare SOC across strata
├── bulk_density_by_stratum.png     # BD patterns
├── soc_bd_correlation.png          # Relationship between SOC and BD
├── depth_distribution.png          # Sampling depth coverage
├── summary_statistics_by_stratum.csv  # Mean, SD, CV, n for each stratum
├── depth_summary_statistics.csv    # Stats by depth interval
└── correlation_matrix.csv          # SOC/BD correlations
```

**What to look for:**
- 🌊 **Lower Marsh** typically highest SOC (daily tidal deposition)
- 🌿 **Mid Marsh** high sequestration rates (regular flooding)
- 🏔️ **Upper Marsh** lower SOC (infrequent flooding)
- 📉 SOC decreases with depth (organic matter accumulation at surface)
- 🎯 CV < 30% is good precision for carbon credits
- ⚠️ Check outliers in boxplots - are they real or data entry errors?

---

### MODULE 03: Depth Harmonization
**Run:** `source("03_depth_harmonization_bluecarbon.R")`

**What it does:**
Standardizes all depth profiles to VM0033 standard depths (7.5, 22.5, 40, 75 cm) using equal-area spline interpolation. Bootstraps uncertainty estimation (100 iterations). Applies quality flags for unrealistic or non-monotonic profiles. This ensures all cores are comparable for spatial modeling.

**Expected duration:** 1-3 minutes (bootstrap is computationally intensive)

**What to expect:**
Progress messages for each core as splines are fitted. Most cores should pass quality checks. Bootstrap generates 95% confidence intervals for each interpolated value.

**File structure CREATED:**
```
diagnostics/depth_harmonization/
├── spline_fits_by_core/        # Individual core plots
│   ├── HR_001_spline_fit.png  # Shows measured points + fitted spline
│   ├── HR_002_spline_fit.png
│   └── (one per core)
├── harmonized_vs_measured.png  # QC comparison
├── quality_flags_summary.csv   # Cores with issues
├── bootstrap_uncertainty.png   # CI width by depth
└── harmonization_statistics.csv # Summary of spline parameters

data_processed/
└── cores_harmonized_spline_bluecarbon.rds  # Standardized profiles for Module 05
```

**What to look for:**
- ✅ Quality flags: "realistic" and "monotonic" = PASS
- 📊 Spline fits should follow measured points closely
- 🎯 Bootstrap SE increases with depth (normal - fewer data points)
- ⚠️ If many cores fail quality checks: review raw data for errors
- 💡 VM0033 depths: 7.5cm = 0-15cm layer, 22.5cm = 15-30cm, etc.

---

### MODULE 05: Random Forest Spatial Predictions
**Run:** `source("05_raster_predictions_rf_bluecarbon.R")`

**What it does:**
Trains Random Forest models to predict SOC at every pixel using GEE environmental covariates (NDVI, SAR, elevation, etc.). Performs 3-fold spatial cross-validation to assess accuracy. Calculates Area of Applicability (AOA) to identify where predictions are reliable. Generates prediction maps + uncertainty maps for all 4 VM0033 depths.

**Expected duration:** 5-15 minutes (depends on study area size)

**What to expect:**
RF trains 4 separate models (one per depth). Console shows variable importance (which covariates matter most). CV results show R² (>0.6 is good, >0.7 excellent). AOA identifies pixels similar to training data.

**File structure CREATED:**
```
outputs/predictions/rf/
├── soc_rf_7.5cm.tif              # SOC prediction map (surface layer)
├── soc_rf_22.5cm.tif             # Second layer
├── soc_rf_40cm.tif               # Third layer
├── soc_rf_75cm.tif               # Deep layer
├── soc_rf_se_7.5cm.tif          # Standard error (uncertainty) maps
├── soc_rf_se_22.5cm.tif
├── soc_rf_se_40cm.tif
├── soc_rf_se_75cm.tif
└── aoa_mask.tif                  # Area of Applicability (1 = reliable)

diagnostics/rf/
├── rf_variable_importance.png    # Which covariates matter most
├── rf_predicted_vs_observed.png  # Model accuracy scatter plots
├── rf_cv_results_by_depth.csv   # R², RMSE, MAE for each depth
├── rf_spatial_cv_folds.png      # CV spatial distribution
└── aoa_dissimilarity_map.png    # Extrapolation risk map

diagnostics/crossvalidation/
└── rf_cv_results.csv             # Overall model performance
```

**What to look for:**
- 🎯 **CV R² > 0.7** = excellent predictive performance (suitable for carbon credits)
- 🎯 **CV R² 0.5-0.7** = good (acceptable for VM0033)
- ⚠️ **CV R² < 0.5** = poor (need more cores or better covariates)
- 📊 **RMSE < 10 g/kg** = high accuracy
- 🌍 **AOA coverage > 90%** = minimal extrapolation (good)
- 💡 Top predictors usually: NDVI, NDWI (tidal flooding), elevation
- ⚠️ If AOA coverage low: predictions unreliable in un-sampled areas

**REQUIRES:** GEE covariate TIFs in `covariates/` directories!

---

### MODULE 06: Carbon Stock Calculation
**Run:** `source("06_carbon_stock_calculation_bluecarbon.R")`

**What it does:**
Integrates SOC depth profiles into total carbon stocks (Mg C/ha) for VM0033 depth layers (0-15, 15-30, 30-50, 50-100 cm). Calculates by stratum and for entire study area. Generates conservative estimates using 95% CI lower bounds (required for carbon crediting). Propagates uncertainty through all calculations.

**Expected duration:** 2-5 minutes

**What to expect:**
Raster calculations for each depth layer, then vertical integration to total stocks. Outputs mean, lower bound (conservative), and upper bound estimates. Typical coastal marsh: 100-300 Mg C/ha (0-100 cm).

**File structure CREATED:**
```
outputs/carbon_stocks/
├── carbon_stock_0_15cm_mean.tif           # Surface layer (0-15 cm)
├── carbon_stock_0_15cm_conservative.tif   # 95% CI lower bound
├── carbon_stock_15_30cm_mean.tif          # Second layer
├── carbon_stock_15_30cm_conservative.tif
├── carbon_stock_30_50cm_mean.tif          # Third layer
├── carbon_stock_30_50cm_conservative.tif
├── carbon_stock_50_100cm_mean.tif         # Deep layer
├── carbon_stock_50_100cm_conservative.tif
├── carbon_stock_total_0_100cm_mean.tif    # TOTAL STOCKS (0-100 cm)
├── carbon_stock_total_0_100cm_conservative.tif  # For carbon credits
├── carbon_stock_total_0_100cm_se.tif      # Standard error map
│
├── carbon_stocks_by_stratum_mean.csv      # Summary table
├── carbon_stocks_by_stratum_conservative.csv  # VM0033 Table 8 format
├── carbon_stocks_summary.csv              # Area-weighted means
└── carbon_stock_uncertainty_summary.csv   # Precision assessment

diagnostics/carbon_stocks/
├── carbon_stock_distribution.png          # Histogram of stock values
├── carbon_stock_by_stratum_boxplot.png   # Compare strata
└── uncertainty_by_depth_layer.png         # Precision assessment
```

**What to look for:**
- 🌊 **Lower Marsh:** Typically 150-300 Mg C/ha (highest stocks)
- 🌿 **Mid Marsh:** 100-200 Mg C/ha (moderate-high)
- 🏔️ **Upper Marsh:** 50-150 Mg C/ha (lower stocks)
- 🌱 **Underwater Vegetation:** 100-250 Mg C/ha (if seagrass present)
- 🎯 **Conservative < Mean** (always - this is your crediting baseline)
- 📊 **Surface layer (0-15 cm)** contains ~20-30% of total stocks
- ⚠️ If values seem unrealistic: check bulk density defaults (Module 01)
- 💡 **Use "conservative" values for carbon credit calculations**

---

### MODULE 07: MMRV Verification Package
**Run:** `source("07_mmrv_reporting_bluecarbon.R")`

**What it does:**
Generates your final VM0033 verification package for carbon credit registry submission (Verra, Gold Standard, etc.). Compiles all results into professional HTML report + Excel workbook with the 4 required VM0033 tables: project metadata, carbon stocks by stratum, model performance metrics, and QA/QC summary.

**Expected duration:** 1-2 minutes

**What to expect:**
HTML report opens automatically in your browser. Contains maps, tables, plots, and statistical summaries. Excel workbook has pre-formatted tables ready for registry upload.

**File structure CREATED:**
```
outputs/mmrv_reports/
├── vm0033_verification_package.html     # ⭐ MAIN DELIVERABLE
├── vm0033_verification_package.xlsx     # Excel version for submission
├── verification_tables/
│   ├── table1_project_metadata.csv      # Project info
│   ├── table2_carbon_stocks_by_stratum.csv  # VM0033 Table 8
│   ├── table3_model_performance.csv     # CV metrics
│   └── table4_qaqc_summary.csv         # Data quality checks
└── report_figures/
    ├── study_area_map.png
    ├── carbon_stock_total_map.png       # Final carbon map
    ├── carbon_stock_by_stratum_barplot.png
    └── model_performance_summary.png
```

**What to look for:**
- ✅ **VM0033 Table 8** (carbon stocks by stratum) - registry submission format
- ✅ **Model R² > 0.6** in Table 3 (demonstrates acceptable accuracy)
- ✅ **QA/QC pass rates > 95%** in Table 4 (data quality)
- 📊 **Conservative estimates** used throughout (95% CI lower bound)
- 🗺️ **Maps show spatial patterns** - higher C in frequently flooded areas
- 💰 **Total carbon stocks** - multiply by project area for total credits
- 📄 **HTML report** - professional document for stakeholders
- ⚠️ Review all tables for completeness before submission

---

## 📊 FINAL OUTPUT SUMMARY

After running Modules 00-07, your key deliverables:

### 🎯 FOR CARBON CREDIT SUBMISSION:
```
outputs/mmrv_reports/vm0033_verification_package.html  # Main report
outputs/mmrv_reports/vm0033_verification_package.xlsx  # Submission tables
outputs/carbon_stocks/carbon_stock_total_0_100cm_conservative.tif  # Carbon map
outputs/carbon_stocks/carbon_stocks_by_stratum_conservative.csv    # VM0033 Table 8
```

### 📈 FOR STAKEHOLDERS:
```
diagnostics/exploratory/depth_profiles_by_stratum.png  # Show ecosystem patterns
outputs/mmrv_reports/report_figures/carbon_stock_total_map.png  # Visual impact
outputs/carbon_stocks/carbon_stocks_summary.csv  # Area-weighted totals
```

### 🔬 FOR TECHNICAL REVIEW:
```
diagnostics/crossvalidation/rf_cv_results.csv  # Model performance
diagnostics/data_prep/vm0033_compliance_report.csv  # Methodology compliance
diagnostics/depth_harmonization/quality_flags_summary.csv  # Data quality
```

---

## ⚠️ TROUBLESHOOTING

### Issue 1: Module 05 fails - "No covariate files found"
**Problem:** Random Forest requires GEE environmental layers
**Solution:** Add TIF files to `covariates/optical/`, `covariates/sar/`, etc.
**Minimum required:** NDVI, EVI, NDWI, elevation
**Alternative:** Skip Module 05, use Module 04 (Kriging) instead - doesn't need covariates

### Issue 2: Module 01 - "VM0033 compliance FAIL"
**Problem:** < 3 cores in one or more strata
**Check:** `diagnostics/data_prep/stratum_distribution.png`
**Solution:** Collect more cores in undersampled strata, or remove empty strata from analysis

### Issue 3: Module 03 - Many cores fail quality checks
**Problem:** Non-monotonic profiles or unrealistic values
**Check:** `diagnostics/depth_harmonization/quality_flags_summary.csv`
**Solution:** Review raw data for errors, or increase spline smoothing in config

### Issue 4: Module 05 - Low R² (< 0.5)
**Problem:** Poor predictive performance
**Solutions:**
  - Add more GEE covariates (SAR, coastal metrics)
  - Collect more cores (especially in variable areas)
  - Check that covariates match study area extent

### Issue 5: Module 06 - Unrealistic carbon stocks
**Problem:** Values too high (>500 Mg C/ha) or too low (<20 Mg C/ha)
**Check:** Bulk density values in `diagnostics/data_prep/bulk_density_transparency.csv`
**Solution:** Verify BD measurements, update BD_DEFAULTS in config if needed

---

## 🎯 EXPECTED WORKFLOW TIME

**Total time for first run:** 30-60 minutes

| Module | Duration | Bottleneck |
|--------|----------|------------|
| 00a | 5-10 min | Package compilation (first time only) |
| 00b | 5 sec | - |
| 01 | 30 sec | - |
| 02 | 1 min | Plotting |
| 03 | 2-3 min | Bootstrap iterations |
| 05 | 10-15 min | RF training + CV + AOA calculation |
| 06 | 3-5 min | Raster calculations |
| 07 | 1-2 min | Report rendering |

**Subsequent runs:** Much faster (packages already installed, can skip exploratory modules)

---

## 📋 CHECKLIST FOR CARBON CREDIT SUBMISSION

Before submitting to registry (Verra, Gold Standard, etc.):

- [ ] VM0033 compliance PASS (Module 01)
- [ ] ≥3 cores per stratum sampled
- [ ] Bulk density measured (not just estimated)
- [ ] Model R² > 0.6 (Module 05 CV results)
- [ ] AOA coverage > 80% of project area
- [ ] Conservative estimates used (95% CI lower bound)
- [ ] Quality flags reviewed (Module 03)
- [ ] All 4 VM0033 tables completed (Module 07)
- [ ] Maps show realistic spatial patterns
- [ ] Total carbon stocks calculated for project area
- [ ] Uncertainty quantified (SE maps generated)
- [ ] Professional report generated (HTML + Excel)

---

## 🚀 NEXT STEPS AFTER PART 2

### Option A: Temporal Analysis (Part 3 - Modules 08-10)
If you have multiple monitoring years (e.g., baseline + project):
```r
source("08_temporal_data_harmonization.R")      # Align scenarios
source("09_additionality_temporal_analysis.R")  # Calculate PROJECT - BASELINE
source("10_vm0033_final_verification.R")        # Final crediting report
```

### Option B: Bayesian Enhancement (Part 4 - Modules 00c, 01c, 06c)
If you have prior carbon maps and want to reduce uncertainty:
```r
source("00c_bayesian_prior_setup_bluecarbon.R")        # Process GEE priors
source("01c_bayesian_sampling_design_bluecarbon.R")    # Optimal sampling
source("06c_bayesian_posterior_estimation_bluecarbon.R") # Combine prior + field data
```

### Option C: Expand Monitoring
- Collect more cores (especially if CV > 20%)
- Add temporal monitoring (annual or every 5 years per VM0033)
- Establish BASELINE scenario if not yet collected

---

## 📞 NEED HELP?

**Common questions answered in:**
- `README_BLUE_CARBON_WORKFLOW.md` - Workflow overview
- `README_DATA_STRUCTURE.md` - Data format specifications
- `TECHNICAL_CODE_REVIEW.md` - Code quality assessment
- `blue_carbon_config.R` - All customizable parameters

**Your project is configured and ready to run!**

Start with: `source("00a_install_packages_v2.R")`

Good luck with your BC coastal carbon credit project! 🌊🌿
