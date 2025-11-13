[README_BLUE_CARBON_WORKFLOW.md](https://github.com/user-attachments/files/23505496/README_BLUE_CARBON_WORKFLOW.md)
# 🌊 BLUE CARBON MMRV WORKFLOW
## VM0033 & ORRAA Compliant Analysis Pipeline for Canadian Coastal Ecosystems

**Version:** 1.0  
**Last Updated:** November 2025  
**Compliance:** VM0033, ORRAA High Quality Principles, IPCC Wetlands Supplement

---

## 📋 OVERVIEW

This workflow provides a complete 3-part analysis pipeline for blue carbon projects in Canadian coastal ecosystems (tidal marshes, seagrass beds, underwater vegetation). It implements VM0033 (Verra) methodology with conservative uncertainty estimation required for carbon credit verification and additionality assessment.

### **Key Features:**
✅ **3-Part Workflow** - Modular design: GEE setup → Carbon stocks → Temporal analysis
✅ **Stratum-aware analysis** - Flexible ecosystem stratification
✅ **VM0033 compliant** - Conservative estimates (95% CI lower bound)
✅ **ORRAA principles** - Transparent, science-based MRV
✅ **Spatial modeling** - Random Forest + Kriging with AOA analysis
✅ **Temporal analysis** - Additionality and multi-period monitoring
✅ **Uncertainty quantification** - Full error propagation

---

## 🚀 3-PART WORKFLOW STRUCTURE

### **PART 1: FIELD CAMPAIGN PLANNING** (Google Earth Engine)
**Purpose:** Design sampling strategy and export spatial data

**GEE Tools:**
1. **Stratification Tool** - Define ecosystem boundaries, export stratum masks
2. **Sampling Design Tool** - Generate stratified random sampling points
3. **Covariate Extraction** - Export environmental covariates (NDVI, NDWI, SAR, elevation)

**Deliverable:** Field sampling plan with GPS coordinates and covariate library

---

### **PART 2: CARBON STOCK ASSESSMENT** (R Modules 00-07)
**Purpose:** Process field data and calculate carbon stocks for ONE scenario/time period

**Key Concept:** Run Part 2 independently for each scenario/year (e.g., BASELINE 2020, PROJECT 2024, PROJECT 2029). Each run produces a complete carbon stock assessment.

#### **Module 00: Setup** ✅
- **File:** `00b_setup_directories_bluecarbon.R`
- **Purpose:** Install packages, create directories, initialize configuration
- **Outputs:** Directory structure, `blue_carbon_config.R`

#### **Module 01: Data Preparation** ✅
- **File:** `01_data_prep_bluecarbon.R`
- **Purpose:** Load and clean field core data for THIS scenario/year
- **Key Features:**
  - Validate ecosystem strata
  - QA/QC checks (coordinates, SOC, bulk density)
  - VM0033 sample size validation
  - Stratum-specific bulk density defaults
- **Outputs:** `data_processed/cores_clean_bluecarbon.rds`

#### **Module 02: Exploratory Analysis** ✅
- **File:** `02_exploratory_analysis_bluecarbon.R`
- **Purpose:** EDA with stratum stratification
- **Outputs:** Diagnostic plots by stratum

#### **Module 03: Depth Harmonization** ✅
- **File:** `03_depth_harmonization_bluecarbon.R`
- **Purpose:** Standardize depth profiles to VM0033 intervals
- **Key Features:**
  - Equal-area spline harmonization
  - Bootstrap uncertainty quantification
  - Quality flags (realistic, monotonic)
- **Outputs:** `data_processed/cores_harmonized_spline_bluecarbon.rds`

#### **Module 04: Kriging** ✅
- **File:** `04_raster_predictions_kriging_bluecarbon.R`
- **Purpose:** Spatial interpolation with stratum-specific variograms
- **Key Features:**
  - Stratum-specific variogram models
  - Cross-validation
  - Uncertainty rasters
- **Outputs:** `outputs/predictions/kriging/soc_*cm.tif`

#### **Module 05: Random Forest** ✅
- **File:** `05_raster_predictions_rf_bluecarbon.R`
- **Purpose:** ML-based spatial prediction with coastal covariates
- **Key Features:**
  - Stratum as covariate (flexible auto-detection)
  - Coastal-specific covariates (NDWI, SAR, tidal metrics)
  - Area of Applicability (AOA) analysis
  - Spatial cross-validation
- **Outputs:** `outputs/predictions/rf/soc_rf_*cm.tif`, AOA maps

#### **Module 06: Carbon Stock Calculation** ✅
- **File:** `06_carbon_stock_calculation_bluecarbon.R`
- **Purpose:** Convert SOC predictions → Total carbon stocks
- **Key Features:**
  - VM0033 depth intervals (0-30 cm, 30-100 cm, 0-100 cm total)
  - Conservative estimates (95% CI lower bound)
  - Uncertainty propagation
- **Outputs:**
  - `outputs/carbon_stocks/carbon_stocks_by_stratum.csv`
  - `outputs/carbon_stocks/maps/*.tif`

#### **Module 07: Single-Scenario MMRV Report** ✅
- **File:** `07_mmrv_reporting_bluecarbon.R`
- **Purpose:** Generate verification package for THIS scenario/year
- **Outputs:** `outputs/mmrv_reports/vm0033_report_[scenario]_[year].html`

**How to run Part 2 for multiple scenarios:**
```r
# Run 1: Baseline
PROJECT_SCENARIO <- "BASELINE"
MONITORING_YEAR <- 2020
source("01_data_prep_bluecarbon.R")  # Run through Module 07

# Run 2: Project Year 1
PROJECT_SCENARIO <- "PROJECT"
MONITORING_YEAR <- 2024
source("01_data_prep_bluecarbon.R")  # Run through Module 07

# Run 3: Project Year 2
PROJECT_SCENARIO <- "PROJECT"
MONITORING_YEAR <- 2029
source("01_data_prep_bluecarbon.R")  # Run through Module 07
```

---

### **PART 3: TEMPORAL ANALYSIS & ADDITIONALITY** (R Modules 08-09)
**Purpose:** Compare scenarios and calculate emission reductions

**Key Concept:** Run Part 3 ONCE after all Part 2 scenarios are complete. Loads and compares multiple carbon stock outputs.

#### **Module 08: Temporal Data Harmonization** ✅
- **File:** `08_temporal_data_harmonization.R`
- **Purpose:** Load and align carbon stocks from multiple scenarios/years
- **Key Features:**
  - Auto-detect scenarios/years from file naming convention
  - Validate spatial alignment (CRS, extent, resolution)
  - Resample to common grid if needed
  - Check stratum coverage across scenarios
- **Outputs:**
  - `data_temporal/carbon_stocks_aligned.rds`
  - `data_temporal/temporal_metadata.csv`
  - `data_temporal/stratum_coverage.csv`

#### **Module 09: Additionality & Temporal Change** ✅
- **File:** `09_additionality_temporal_analysis.R`
- **Purpose:** Calculate project vs baseline differences and temporal trends
- **Key Features:**
  - **Additionality Analysis (PROJECT - BASELINE):**
    - Conservative estimates (95% CI lower bound)
    - Statistical testing (t-tests, p-values)
    - Uncertainty propagation
    - Effect sizes (Cohen's d)
    - Difference raster maps
  - **Temporal Change Analysis (Multi-Period):**
    - Sequestration rates (Mg C/ha/yr)
    - Trend analysis
    - Time series plots
- **Outputs:**
  - `outputs/additionality/additionality_by_stratum.csv`
  - `outputs/additionality/additionality_*.tif` (difference maps)
  - `outputs/temporal_change/temporal_trends_by_stratum.csv`
  - `outputs/temporal_change/plots/*.png` (time series)

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

### **PART 1: GEE Preparation** (Before field work)
Use Google Earth Engine to:
1. Define ecosystem strata boundaries
2. Export stratum masks to `data_raw/gee_strata/`
3. Export covariates to `covariates/`
4. Generate stratified sampling locations

### **PART 2: Carbon Stock Assessment** (For each scenario/year)

#### **Step 1: Install and Setup**
```r
# Set working directory
setwd("/path/to/blue_carbon_project")

# Run setup (only once)
source("00b_setup_directories_bluecarbon.R")

# Review and edit configuration
file.edit("blue_carbon_config.R")
```

#### **Step 2: Configure Scenario**
Edit `blue_carbon_config.R`:
```r
PROJECT_SCENARIO <- "BASELINE"  # or "PROJECT", "CONTROL", etc.
MONITORING_YEAR <- 2020         # Year of data collection
```

#### **Step 3: Prepare Data**
- Add field data CSVs to `data_raw/`:
  - `core_locations.csv` (GPS coordinates, stratum, scenario_type)
  - `core_samples.csv` (depth profiles, SOC, bulk density)
- Verify GEE exports are in place

#### **Step 4: Run Carbon Stock Pipeline**
```r
# Data preparation
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

# Generate single-scenario report
source("07_mmrv_reporting_bluecarbon.R")
```

#### **Step 5: Review Single-Scenario Outputs**
```r
# Open verification report
browseURL("outputs/mmrv_reports/vm0033_verification_package.html")

# Review carbon stocks
stocks <- read.csv("outputs/carbon_stocks/carbon_stocks_by_stratum.csv")
print(stocks)
```

#### **Step 6: Repeat for Additional Scenarios**
Change `PROJECT_SCENARIO` and `MONITORING_YEAR` in config, then re-run Steps 4-5.

**Example multi-scenario workflow:**
```r
# Scenario 1: Baseline
PROJECT_SCENARIO <- "BASELINE"
MONITORING_YEAR <- 2020
source("01_data_prep_bluecarbon.R")  # Run through Module 07

# Scenario 2: Project Year 1
PROJECT_SCENARIO <- "PROJECT"
MONITORING_YEAR <- 2024
source("01_data_prep_bluecarbon.R")  # Run through Module 07

# Scenario 3: Project Year 2
PROJECT_SCENARIO <- "PROJECT"
MONITORING_YEAR <- 2029
source("01_data_prep_bluecarbon.R")  # Run through Module 07
```

---

### **PART 3: Temporal Analysis** (After all scenarios are complete)

#### **Step 1: Harmonize Temporal Data**
```r
# Load and align all scenario/year datasets
source("08_temporal_data_harmonization.R")
```

This will detect and align all carbon stock outputs from Part 2.

#### **Step 2: Analyze Additionality and Trends**
```r
# Calculate PROJECT - BASELINE and temporal trends
source("09_additionality_temporal_analysis.R")
```

#### **Step 3: Review Temporal Outputs**
```r
# Additionality results
additionality <- read.csv("outputs/additionality/additionality_by_stratum.csv")
print(additionality)

# Temporal trends
trends <- read.csv("outputs/temporal_change/temporal_trends_by_stratum.csv")
print(trends)

# View time series plots
list.files("outputs/temporal_change/plots/", pattern = "*.png")
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

## 🗺️ CUSTOMIZING ECOSYSTEM STRATA

Module 05 supports flexible stratum definitions to accommodate different project types, management zones, or restoration stages. You have two options:

### **Method 1: Simple Configuration (Recommended)**

Define your strata in `blue_carbon_config.R` using `VALID_STRATA`:

```r
# Example: Restoration stages
VALID_STRATA <- c(
  "Emerging Marsh",
  "Restored Marsh",
  "Degraded Marsh",
  "Reference Marsh"
)
```

Module 05 will **auto-detect GEE export files** using this naming convention:
- **"Emerging Marsh"** → `data_raw/gee_strata/emerging_marsh.tif`
- **"Restored Marsh"** → `data_raw/gee_strata/restored_marsh.tif`
- **"Degraded Marsh"** → `data_raw/gee_strata/degraded_marsh.tif`
- **"Reference Marsh"** → `data_raw/gee_strata/reference_marsh.tif`

**Convention:** Stratum names are converted to lowercase with underscores replacing spaces.

### **Method 2: Advanced CSV Configuration**

For custom file names or additional metadata, create `stratum_definitions.csv` in the project root:

```csv
stratum_name,gee_file,stratum_code,description,restoration_type,baseline_vs_project,age_years
Emerging Marsh,emerging_marsh.tif,1,Recently restored marsh (0-5 years),active_restoration,project,3
Restored Marsh,restored_marsh.tif,2,Established restored marsh (>5 years),active_restoration,project,8
Degraded Marsh,degraded_marsh.tif,3,Degraded baseline condition,none,baseline,NA
Reference Marsh,reference_natural.tif,4,Natural reference site,natural,reference,NA
```

**Required columns:**
- `stratum_name` - Display name for reports
- `gee_file` - Filename in `data_raw/gee_strata/`
- `stratum_code` - Numeric code (must be unique)

**Optional columns:** (can be left blank)
- `description` - Text description
- `restoration_type` - Type of restoration activity
- `baseline_vs_project` - VM0033 scenario classification
- `age_years` - Age of restored area

See `stratum_definitions_EXAMPLE.csv` for template.

### **Stratum Definition Examples**

#### **Restoration Stages**
```r
VALID_STRATA <- c("Emerging Marsh", "Restored Marsh", "Degraded Marsh", "Reference Marsh")
```
Use for: Tracking carbon accumulation across restoration timeline

#### **Habitat Types**
```r
VALID_STRATA <- c("Salt Marsh", "Eelgrass Beds", "Mangrove", "Mudflat")
```
Use for: Multi-habitat coastal projects

#### **Management Zones**
```r
VALID_STRATA <- c("Protected", "Managed", "Degraded", "Restored")
```
Use for: Conservation area management

#### **VM0033 Scenarios**
```r
VALID_STRATA <- c("Baseline", "Project", "Control", "Reference")
```
Use for: Additionality analysis and baseline comparison

### **GEE Stratum Export Workflow**

1. **Export binary masks from Google Earth Engine** for each stratum:
   - Value = 1 where stratum is present
   - Value = 0 or NA elsewhere
   - Export as GeoTIFF to `data_raw/gee_strata/`

2. **Use consistent naming:**
   - Follow lowercase + underscore convention
   - Example: "Upper Marsh" → `upper_marsh.tif`

3. **Module 05 will:**
   - Detect and validate all stratum files
   - Warn about missing files but continue with available ones
   - Create unified categorical raster
   - Use stratum as Random Forest covariate
   - Save reference of used strata to `data_processed/stratum_mapping_used.csv`

### **Troubleshooting Strata**

#### **"No VALID_STRATA defined"**
- **Cause:** Missing stratum configuration
- **Fix:** Define `VALID_STRATA` in `blue_carbon_config.R` or create `stratum_definitions.csv`

#### **"Stratum file missing"**
- **Cause:** GEE export file not found in `data_raw/gee_strata/`
- **Fix:** Check file name matches convention, verify directory location
- **Note:** Module 05 will warn but continue with available strata

#### **"Stratum not in VALID_STRATA"**
- **Cause:** Core data references stratum not in config
- **Fix:** Update `VALID_STRATA` to include all strata in field data

#### **Strata overlap in raster**
- **Cause:** Multiple stratum masks have value 1 at same location
- **Fix:** Review GEE export logic, ensure mutually exclusive masks
- **Note:** If overlap occurs, higher stratum_code takes precedence

### **Files Created by Module 05**

- `data_processed/stratum_raster.tif` - Unified categorical raster
- `data_processed/stratum_mapping_used.csv` - Reference of strata used in analysis

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
