[README_BLUE_CARBON_WORKFLOW.md](https://github.com/user-attachments/files/23505496/README_BLUE_CARBON_WORKFLOW.md)
# 🌊 BLUE CARBON MMRV WORKFLOW
## VM0033 & ORRAA Compliant Analysis Pipeline for Canadian Coastal Ecosystems

**Version:** 1.0  
**Last Updated:** November 2025  
**Compliance:** VM0033, ORRAA High Quality Principles, IPCC Wetlands Supplement

---

## 📋 OVERVIEW

This workflow provides a complete analysis pipeline for blue carbon projects in Canadian coastal ecosystems (tidal marshes, seagrass beds, underwater vegetation). It implements VM0033 (Verra) methodology with conservative uncertainty estimation required for carbon credit verification.

### **Key Features:**
✅ **Stratum-aware analysis** - Separate processing for 5 coastal ecosystem types  
✅ **VM0033 compliant** - Conservative estimates (95% CI lower bound)  
✅ **ORRAA principles** - Transparent, science-based MRV  
✅ **Spatial modeling** - Random Forest + Kriging with AOA analysis  
✅ **Uncertainty quantification** - Full error propagation  
✅ **Verification ready** - Automated report generation  

---

## 🗂️ WORKFLOW MODULES

### **Phase 1: Setup & Data Preparation**

#### **Module 00: Setup** ✅ COMPLETE
- **File:** `00b_setup_directories_bluecarbon.R`
- **Purpose:** Install packages, create directories, configuration
- **Runtime:** 5-10 minutes
- **Outputs:** Directory structure, `blue_carbon_config.R`

#### **Module 01: Data Preparation**
- **File:** `01_data_prep_bluecarbon.R` (adapt from generic version)
- **Purpose:** Load and clean core data with stratum handling
- **Key Features:**
  - Validate 5 ecosystem strata
  - VM0033 metadata (scenario, monitoring year)
  - Stratum-specific bulk density defaults
  - Enhanced QA/QC by stratum
- **Outputs:** `cores_clean_bluecarbon.rds`

#### **Module 02: Exploratory Analysis**
- **File:** `02_exploratory_analysis_bluecarbon.R` (adapt from generic)
- **Purpose:** EDA with stratum stratification
- **Key Features:**
  - Depth profiles by stratum
  - Cross-stratum comparisons
  - Outlier detection by ecosystem type
- **Outputs:** Diagnostic plots by stratum

### **Phase 2: Depth Harmonization**

#### **Module 03: Spline Harmonization** ✅ COMPLETE
- **File:** `03_depth_harmonization_bluecarbon.R`
- **Purpose:** Standardize depth profiles to VM0033 intervals
- **Key Features:**
  - Stratum-specific spline parameters
  - Bootstrap uncertainty (optional)
  - Quality flags (realistic, monotonic)
- **Outputs:** `cores_harmonized_spline_bluecarbon.rds`

### **Phase 3: Spatial Prediction**

#### **Module 04: Kriging** ✅ COMPLETE
- **File:** `04_raster_predictions_kriging_bluecarbon.R`
- **Purpose:** Spatial interpolation with stratum-specific variograms
- **Key Features:**
  - Separate variograms per stratum
  - Anisotropic models for tidal gradients
  - Cross-validation
  - Uncertainty rasters (variance)
- **Outputs:** 
  - `outputs/predictions/kriging/soc_*cm.tif`
  - `outputs/predictions/uncertainty/variance_*cm.tif`

#### **Module 05: Random Forest** ✅ COMPLETE  
- **File:** `05_raster_predictions_rf_bluecarbon.R`
- **Purpose:** Machine learning predictions with coastal covariates
- **Key Features:**
  - Stratum-aware training (spatial CV by stratum)
  - Coastal-specific covariates (NDWI, SAR, tidal metrics)
  - Area of Applicability (AOA) analysis
  - Variable importance by stratum
- **Outputs:**
  - `outputs/predictions/rf/soc_rf_*cm.tif`
  - `outputs/predictions/rf/aoa_*cm.tif`
  - `outputs/models/rf/rf_models_all_depths.rds`

### **Phase 4: Carbon Stock Calculation & Verification**

#### **Module 06: Carbon Stock Calculation** ✅ COMPLETE
- **File:** `06_carbon_stock_calculation_bluecarbon.R`
- **Purpose:** Convert SOC predictions → Total carbon stocks
- **Key Features:**
  - VM0033 depth intervals (0-30 cm, 30-100 cm)
  - Conservative estimates (95% CI lower bound)
  - Stratum-specific calculations
  - Uncertainty propagation
- **Outputs:**
  - `outputs/carbon_stocks/carbon_stocks_by_stratum.csv`
  - `outputs/carbon_stocks/carbon_stocks_conservative_vm0033.csv`
  - `outputs/carbon_stocks/maps/*.tif`

#### **Module 07: MMRV Reporting** ✅ COMPLETE
- **File:** `07_mmrv_reporting_bluecarbon.R`
- **Purpose:** Generate VM0033 verification package
- **Key Features:**
  - HTML verification report
  - Excel summary tables (4 required tables)
  - QA/QC flagged areas
  - Spatial data exports for GIS verification
- **Outputs:**
  - `outputs/mmrv_reports/vm0033_verification_package.html`
  - `outputs/mmrv_reports/vm0033_summary_tables.xlsx`
  - `outputs/mmrv_reports/spatial_exports/` (GeoTIFFs)

---

## 📊 REQUIRED INPUT DATA

### **1. Field Core Data**

Two CSV files in `data_raw/`:

**core_locations.csv:**
```csv
core_id,longitude,latitude,stratum,collection_date,core_type,scenario_type
HR_001,-123.72,48.91,Mid Marsh,2024-06-15,hr_core,PROJECT
COMP_001,-123.73,48.92,Lower Marsh,2024-06-15,composite,PROJECT
```

**Required columns:**
- `core_id`: Unique identifier
- `longitude`, `latitude`: WGS84 coordinates
- `stratum`: One of 5 valid strata (see config)
- `collection_date`: YYYY-MM-DD format
- `core_type`: "hr_core" or "composite"
- `scenario_type`: "BASELINE", "PROJECT", "CONTROL", or "DEGRADED"

**core_samples.csv:**
```csv
core_id,depth_top_cm,depth_bottom_cm,soc_g_kg,bulk_density_g_cm3
HR_001,0,5,45.2,0.9
HR_001,5,10,38.1,1.0
```

**Required columns:**
- `core_id`: Links to core_locations
- `depth_top_cm`, `depth_bottom_cm`: Depth interval
- `soc_g_kg`: Soil organic carbon (g/kg)
- `bulk_density_g_cm3`: Bulk density (g/cm³)

### **2. Remote Sensing Covariates**

Export from Google Earth Engine using `BlueCarbon_CovariateExtraction_Tool.js`

Place TIF files in `covariates/`:
```
covariates/
├── optical/
│   ├── NDVI_median.tif
│   ├── NDWI_median.tif
│   ├── EVI_median.tif
├── sar/
│   ├── VV_median.tif
│   ├── VH_median.tif
├── tidal/
│   ├── elevation.tif
│   ├── tidal_range.tif
├── topographic/
│   ├── slope.tif
│   ├── aspect.tif
└── quality/
    └── quality_score.tif
```

**Minimum Required:**
- NDVI (vegetation index)
- NDWI (water index)
- Elevation (DEM)
- At least 5-10 total covariates

### **3. Stratum Information** (Optional but Recommended)

**Option A:** Stratum raster
- `covariates/stratum.tif` - Each pixel labeled with stratum name/code

**Option B:** Stratum polygons
- `data_raw/strata_polygons.geojson` - Vector boundaries of each stratum

---

## 🚀 QUICK START GUIDE

### **1. Install and Setup**
```r
# Set working directory to project folder
setwd("/path/to/blue_carbon_project")

# Run setup
source("00b_setup_directories_bluecarbon.R")

# Review and edit configuration
file.edit("blue_carbon_config.R")
```

### **2. Prepare Your Data**
- Add field data CSVs to `data_raw/`
- Add GEE covariate TIFs to `covariates/`
- Verify file formats and column names

### **3. Run Analysis Pipeline**
```r
# Data preparation (adapt Module 01 for your data format)
source("01_data_prep_bluecarbon.R")

# Exploratory analysis
source("02_exploratory_analysis_bluecarbon.R")

# Depth harmonization
source("03_depth_harmonization_bluecarbon.R")

# Spatial predictions (choose one or both)
source("04_raster_predictions_kriging_bluecarbon.R")  # Kriging
source("05_raster_predictions_rf_bluecarbon.R")       # Random Forest (recommended)

# Carbon stock calculation
source("06_carbon_stock_calculation_bluecarbon.R")

# Generate verification package
source("07_mmrv_reporting_bluecarbon.R")
```

### **4. Review Outputs**
```r
# Open verification report in browser
browseURL("outputs/mmrv_reports/vm0033_verification_package.html")

# Review carbon stocks
stocks <- read.csv("outputs/carbon_stocks/carbon_stocks_conservative_vm0033.csv")
print(stocks)

# Check model performance
cv_results <- read.csv("diagnostics/crossvalidation/rf_cv_results.csv")
print(cv_results)
```

---

## ⚙️ CONFIGURATION

Edit `blue_carbon_config.R` to customize:

### **Project Metadata**
```r
PROJECT_NAME <- "Chemainus_BlueCarbon_2024"
PROJECT_SCENARIO <- "PROJECT"  # or BASELINE, CONTROL, DEGRADED
MONITORING_YEAR <- 2024
```

### **Ecosystem Strata**
```r
VALID_STRATA <- c(
  "Upper Marsh",
  "Mid Marsh",
  "Lower Marsh",
  "Underwater Vegetation",
  "Open Water"
)
```

### **Standard Depths (VM0033)**
```r
STANDARD_DEPTHS <- c(0, 5, 10, 15, 20, 25, 30, 40, 50, 75, 100)
```

### **Coordinate Systems**
```r
INPUT_CRS <- 4326      # WGS84 (input data)
PROCESSING_CRS <- 3347 # Canada Albers Equal Area
```

### **Bulk Density Defaults** (by stratum)
```r
BD_DEFAULTS <- list(
  "Upper Marsh" = 0.8,
  "Mid Marsh" = 1.0,
  "Lower Marsh" = 1.2,
  "Underwater Vegetation" = 0.6,
  "Open Water" = 1.0
)
```

---

## 📈 EXPECTED OUTPUTS

### **Carbon Stock Maps**
- `carbon_stock_surface_mean.tif` - 0-30 cm layer
- `carbon_stock_deep_mean.tif` - 30-100 cm layer
- `carbon_stock_total_mean.tif` - 0-100 cm total
- `carbon_stock_*_conservative.tif` - VM0033 lower bound estimates
- `carbon_stock_*_se.tif` - Standard error maps

### **Verification Tables**
1. **Project Metadata** - Overview and parameters
2. **Carbon Stocks by Stratum** - VM0033 format
3. **Model Performance** - CV metrics
4. **QA/QC Summary** - Data quality checks

### **Performance Metrics** (Expected)
- **CV R²:** > 0.7 (strong predictive performance)
- **CV RMSE:** < 10 g/kg (good accuracy)
- **AOA Coverage:** > 90% (limited extrapolation)

---

## 🎯 VM0033 COMPLIANCE CHECKLIST

- [x] **Field Sampling**
  - Sediment cores following VM0033 protocols
  - Stratum-specific sampling design
  - GPS coordinates recorded (WGS84)

- [x] **Laboratory Analysis**
  - SOC measured (g/kg)
  - Bulk density measured (g/cm³)
  - QA/QC standards applied

- [x] **Depth Harmonization**
  - Equal-area splines applied
  - Standard depths (0, 5, 10, 15, 20, 25, 30, 40, 50, 75, 100 cm)
  - Quality flags (realistic, monotonic)

- [x] **Spatial Modeling**
  - Cross-validation performed
  - Model performance documented (R², RMSE)
  - Area of Applicability assessed

- [x] **Uncertainty Quantification**
  - 95% confidence intervals calculated
  - Conservative estimates (lower bound)
  - Uncertainty propagated through calculations

- [x] **Carbon Stock Calculation**
  - Depth intervals: 0-30 cm, 30-100 cm, 0-100 cm total
  - Stratum-specific calculations
  - Conservative approach applied

- [x] **Reporting & Verification**
  - Verification package generated
  - Spatial data exported (GeoTIFFs)
  - QA/QC documentation complete
  - Metadata standards followed

---

## 🌟 BEST PRACTICES

### **Sampling Design**
- **Minimum 30 cores per stratum** for robust spatial modeling
- **Stratified random sampling** within ecosystem boundaries
- **Paired cores** (HR + composite) for validation
- **Replicate cores** (10-20%) for QA/QC

### **Covariate Selection**
- **Minimum 10-15 covariates** for Random Forest
- **Include coastal-specific indices:**
  - NDWI, MNDWI (water/moisture)
  - EVI, NDVI (vegetation)
  - SAR backscatter (VV, VH)
  - Tidal indicators (elevation, range)
  - Salinity proxies

### **Quality Control**
- **Review all QA flags** before final analysis
- **Check for outliers** by stratum
- **Validate predictions** in known areas
- **Examine AOA coverage** (>90% recommended)
- **Inspect high uncertainty areas**

### **Uncertainty Management**
- **Always use conservative estimates** for crediting
- **Document data gaps** and limitations
- **Flag extrapolation areas** (outside AOA)
- **Report uncertainty** transparently

---

## 🔧 TROUBLESHOOTING

### **Common Issues**

#### **"No covariate values extracted"**
- **Cause:** CRS mismatch between cores and covariates
- **Fix:** Check coordinate systems in config, verify data projections

#### **"Insufficient samples for CV"**
- **Cause:** Too few cores per stratum (n < 15)
- **Fix:** Combine strata or use simpler models

#### **"Spline fitting failed"**
- **Cause:** Irregular depth profiles, missing data
- **Fix:** Review core data quality, check for gaps

#### **"High uncertainty (>30%)"**
- **Cause:** Sparse sampling, high spatial variability
- **Fix:** Add more field cores, review stratum boundaries

#### **"AOA coverage low (<80%)"**
- **Cause:** Predicting in areas very different from training
- **Fix:** Collect additional cores in undersampled areas

### **Package Installation Issues**

If packages fail to install:
```r
# Try different repository
options(repos = "https://cloud.r-project.org/")

# Install from source
install.packages("CAST", type = "source")

# Check package availability
available.packages()[grep("CAST", available.packages()[,1]),]
```

### **Memory Issues**

For large study areas:
```r
# Increase memory limit (Windows)
memory.limit(size = 16000)

# Process in chunks or reduce resolution
KRIGING_CELL_SIZE <- 30  # Increase from 10m
RF_CELL_SIZE <- 30
```

---

## 📚 REFERENCES

### **Primary Standards**
1. **VM0033** - Verra VCS Methodology for Tidal Wetland and Seagrass Restoration (2024)
2. **ORRAA** - High Quality Blue Carbon Principles and Guidance (2024)
3. **IPCC** - 2013 Supplement to 2006 Guidelines: Wetlands

### **Supporting Guidance**
4. Restore America's Estuaries (2024) - Coastal Blue Carbon in Practice
5. Blue Carbon Initiative - Practitioner's Guide (2024)
6. Canadian Blue Carbon Network - Provincial Standards

### **Key Papers**
7. Harmonizing Blue Carbon Accounting Protocols (2023)
8. New Technologies for Monitoring Coastal Ecosystems (2024)
9. Flaws in Methodologies for Organic Carbon Analysis (2024)

---

## 📞 SUPPORT & CONTRIBUTION

### **Questions?**
- Review module-specific log files in `logs/`
- Check verification report for flagged issues
- Consult VM0033 methodology document

### **Found a Bug?**
- Document the error message
- Include relevant log file excerpts
- Note your R version and package versions

### **Want to Contribute?**
- Suggest improvements to methodology
- Share region-specific calibrations
- Report successful verifications

---

## 📄 LICENSE & CITATION

**Workflow Version:** 1.0 (November 2025)  
**Developed for:** Canadian Blue Carbon Projects  
**Compliance:** VM0033, ORRAA, IPCC Wetlands Supplement

**Citation:**
```
Blue Carbon MMRV Workflow v1.0 (2025). 
VM0033-compliant analysis pipeline for Canadian coastal ecosystems.
```

---

## 🎓 ACKNOWLEDGMENTS

This workflow integrates best practices from:
- Verra VM0033 methodology
- ORRAA High Quality Blue Carbon Principles
- IPCC Wetlands Supplement guidance
- Canadian Blue Carbon Network
- Restore America's Estuaries
- Blue Carbon Initiative

Developed to support transparent, science-based blue carbon verification in Canada.

---

**🌊 Ready to quantify coastal carbon? Start with Module 00!**
