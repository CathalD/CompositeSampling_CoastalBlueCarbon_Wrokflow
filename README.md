# 🌊🌾 COMPOSITE SAMPLING CARBON MMRV WORKFLOWS
## Multi-Ecosystem Analysis Pipeline for Canadian Carbon Projects

**Version:** 1.0
**Last Updated:** November 2025
**Ecosystems:** Coastal Blue Carbon & Prairie Grasslands

---

## 📋 OVERVIEW

This repository provides **TWO complete analysis pipelines** for Canadian carbon assessment projects:

### 🌊 **COASTAL BLUE CARBON WORKFLOW**
Complete analysis pipeline for blue carbon projects in Canadian coastal ecosystems (tidal marshes, seagrass beds, underwater vegetation). Implements VM0033 (Verra) methodology with conservative uncertainty estimation required for carbon credit verification.

**→ See [README_BLUE_CARBON_WORKFLOW.md](README_BLUE_CARBON_WORKFLOW.md) for full documentation**

### 🌾 **CANADIAN GRASSLAND CARBON WORKFLOW** ✨ NEW
Complete analysis pipeline for **Canadian prairie and rangeland** carbon assessment. Implements AAFC Soil Carbon Protocols and Canadian Agricultural GHG Program methodology for grassland ecosystems.

**→ See [README_GRASSLAND_WORKFLOW.md](README_GRASSLAND_WORKFLOW.md) for full documentation**

---

## 🎯 QUICK START: WHICH WORKFLOW DO I NEED?

| **Use Coastal Blue Carbon if:** | **Use Grassland Carbon if:** |
|----------------------------------|------------------------------|
| Tidal wetlands, salt marshes | Prairie grasslands, rangelands |
| Seagrass beds | Fescue prairie, mixed-grass prairie |
| Mangroves (future) | Aspen parkland |
| Coastal restoration projects | Grazing lands, improved pasture |
| VM0033 verification needed | AAFC/Alberta Offset compliance needed |
| 0-500 g/kg SOC range | 0-150 g/kg SOC range |
| Anaerobic, high burial rates | Aerobic, root-driven accumulation |

---

## 📦 REPOSITORY STRUCTURE

```
CompositeSampling_CoastalBlueCarbon_Workflow/
├── README.md                              # This file (overview of both workflows)
├── README_BLUE_CARBON_WORKFLOW.md         # 🌊 Coastal blue carbon documentation
├── README_GRASSLAND_WORKFLOW.md           # 🌾 Grassland carbon documentation (NEW)
│
├── Configuration Files:
│   ├── blue_carbon_config.R               # 🌊 Coastal ecosystem parameters
│   ├── grassland_carbon_config.R          # 🌾 Grassland ecosystem parameters (NEW)
│
├── Coastal Blue Carbon Modules (🌊):
│   ├── 01_data_prep_bluecarbon.R
│   ├── 02_exploratory_analysis_bluecarbon.R
│   ├── 03_depth_harmonization_bluecarbon.R
│   ├── 04_raster_predictions_kriging_bluecarbon.R
│   ├── 05_raster_predictions_rf_bluecarbon.R
│   ├── 06_carbon_stock_calculation_bluecarbon.R
│   └── 07_mmrv_reporting_bluecarbon.R
│
├── Grassland Carbon Modules (🌾) - NEW:
│   ├── 01_data_prep_grassland.R
│   ├── 02_exploratory_analysis_grassland.R
│   ├── 03_depth_harmonization_grassland.R
│   ├── 04_raster_predictions_kriging_grassland.R
│   ├── 05_raster_predictions_rf_grassland.R
│   ├── 06_carbon_stock_calculation_grassland.R
│   └── 07_mmrv_reporting_grassland.R
│
├── Shared Setup:
│   ├── 00a_install_packages_v2.R
│   └── 00b_setup_directories.R
│
└── Data Directories:
    ├── data_raw/                          # Input field data
    ├── data_processed/                    # Cleaned data
    ├── covariates/                        # Remote sensing data
    └── outputs/                           # Results, maps, reports
```

---

## 🌊 COASTAL BLUE CARBON WORKFLOW

This workflow provides a complete analysis pipeline for blue carbon projects in Canadian coastal ecosystems (tidal marshes, seagrass beds, underwater vegetation). It implements VM0033 (Verra) methodology with conservative uncertainty estimation required for carbon credit verification.

### **Key Features:**
✅ **Stratum-aware analysis** - Separate processing for 5 coastal ecosystem types
✅ **VM0033 compliant** - Conservative estimates (95% CI lower bound)
✅ **ORRAA principles** - Transparent, science-based MRV
✅ **Spatial modeling** - Random Forest + Kriging with AOA analysis
✅ **Uncertainty quantification** - Full error propagation
✅ **Verification ready** - Automated report generation

**📘 Full Documentation:** [README_BLUE_CARBON_WORKFLOW.md](README_BLUE_CARBON_WORKFLOW.md)

---

## 🌾 CANADIAN GRASSLAND CARBON WORKFLOW ✨ NEW

This workflow provides a complete analysis pipeline for **Canadian prairie and rangeland carbon projects** across grassland ecosystems. Implements AAFC Soil Carbon Protocols with conservative uncertainty estimation required for Canadian offset verification.

### **Ecosystem Types:**
- **Fescue Prairie** - Native fescue grasslands (AB/SK foothills)
- **Mixed-Grass Prairie** - Native C3/C4 mix (southern prairies)
- **Aspen Parkland** - Grassland-aspen mosaic (transition zone)
- **Improved Pasture** - Seeded, managed, fertilized
- **Degraded Grassland** - Overgrazed, invasive species

### **Key Features:**
✅ **Grassland-specific strata** - 5 Canadian prairie ecosystem types
✅ **AAFC compliant** - Agriculture and Agri-Food Canada protocols
✅ **Canadian protocols** - AGGHG Program, Alberta Offset System
✅ **Grazing & fire history** - Management-specific carbon assessment
✅ **Prairie-adapted depths** - Focus on 0-30 cm (highest SOC)
✅ **Climate-driven modeling** - Precipitation-focused (semi-arid prairies)

### **Key Differences from Coastal:**
- **Depth focus:** 0-30 cm (most SOC) vs. 0-100 cm burial
- **SOC range:** 0-150 g/kg (mineral soils) vs. 0-500 g/kg (organic)
- **Bulk density:** 1.0-1.4 g/cm³ vs. 0.6-1.2 g/cm³
- **Key covariates:** Precipitation, grazing, fire vs. tidal, NDWI, SAR
- **Management:** Grazing intensity, fire frequency vs. tidal restoration
- **Protocols:** AAFC, AGGHG vs. VM0033, ORRAA
- **Verification:** Environment Canada, AB govt vs. Verra VCS

**📗 Full Documentation:** [README_GRASSLAND_WORKFLOW.md](README_GRASSLAND_WORKFLOW.md)

---

## 🚀 GETTING STARTED

### **1. Choose Your Workflow**
- **Coastal/wetland projects:** Use blue carbon workflow
- **Grassland/prairie projects:** Use grassland workflow

### **2. Install Dependencies**
```r
# Set working directory
setwd("/path/to/project")

# Install required packages
source("00a_install_packages_v2.R")

# Setup directory structure
source("00b_setup_directories.R")
```

### **3. Configure Your Project**

**For Coastal Blue Carbon:**
```r
# Edit configuration
file.edit("blue_carbon_config.R")

# Run workflow
source("01_data_prep_bluecarbon.R")
source("02_exploratory_analysis_bluecarbon.R")
source("03_depth_harmonization_bluecarbon.R")
source("04_raster_predictions_kriging_bluecarbon.R")  # OR
source("05_raster_predictions_rf_bluecarbon.R")
source("06_carbon_stock_calculation_bluecarbon.R")
source("07_mmrv_reporting_bluecarbon.R")
```

**For Canadian Grassland Carbon:**
```r
# Edit configuration
file.edit("grassland_carbon_config.R")

# Run workflow
source("01_data_prep_grassland.R")
source("02_exploratory_analysis_grassland.R")
source("03_depth_harmonization_grassland.R")
source("04_raster_predictions_kriging_grassland.R")  # OR
source("05_raster_predictions_rf_grassland.R")
source("06_carbon_stock_calculation_grassland.R")
source("07_mmrv_reporting_grassland.R")
```

---

## 📊 INPUT DATA REQUIREMENTS

### **Both Workflows Require:**

1. **Field core data** (`data_raw/`)
   - `core_locations.csv` - GPS coordinates, stratum assignments
   - `core_samples.csv` - Depth profiles, SOC, bulk density

2. **Remote sensing covariates** (`covariates/`)
   - Vegetation indices (NDVI, EVI)
   - Climate data (precipitation, temperature)
   - Topographic data (elevation, slope)
   - Ecosystem-specific covariates

3. **Stratum boundaries** (optional)
   - Raster or vector format

### **Grassland-Specific Additional Fields:**
- `grazing_history` - Grazing intensity (None, Light, Moderate, Heavy, Severe)
- `fire_history` - Years since last fire
- `grass_type` - Native, Seeded, Mixed, Invasive
- `ecoregion` - Canadian prairie ecoregion

See ecosystem-specific READMEs for detailed data requirements.

---

## 📚 DOCUMENTATION

| Document | Description |
|----------|-------------|
| **[README_BLUE_CARBON_WORKFLOW.md](README_BLUE_CARBON_WORKFLOW.md)** | 🌊 Complete coastal blue carbon documentation |
| **[README_GRASSLAND_WORKFLOW.md](README_GRASSLAND_WORKFLOW.md)** | 🌾 Complete grassland carbon documentation |
| **[data_raw/README_DATA_STRUCTURE.md](data_raw/README_DATA_STRUCTURE.md)** | Data format specifications |

---

## 🌟 KEY FEATURES (Both Workflows)

### **Shared Capabilities:**
- ✅ **7-module pipeline** - Data prep → MMRV reporting
- ✅ **Spatial prediction** - Kriging and/or Random Forest
- ✅ **Uncertainty quantification** - 95% CI, error propagation
- ✅ **Cross-validation** - Spatial CV for model validation
- ✅ **Area of Applicability** - Flag extrapolation zones
- ✅ **Conservative estimates** - Lower bound for crediting
- ✅ **Automated reporting** - HTML + Excel verification packages
- ✅ **QA/QC framework** - Comprehensive quality checks

### **Ecosystem-Specific:**
- 🌊 **Blue Carbon:** VM0033 compliant, tidal/coastal focus, 0-100 cm
- 🌾 **Grassland:** AAFC compliant, grazing/fire history, 0-30 cm focus

---

## 🗂️ WORKFLOW MODULES (SHARED STRUCTURE)

**Module 00:** Setup & package installation
**Module 01:** Data preparation & QA/QC
**Module 02:** Exploratory analysis & visualization
**Module 03:** Depth harmonization (splines)
**Module 04:** Spatial prediction (Kriging)
**Module 05:** Spatial prediction (Random Forest)
**Module 06:** Carbon stock calculation
**Module 07:** MMRV reporting & verification

**See ecosystem-specific READMEs for detailed module documentation.**

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

### **🌊 Coastal Blue Carbon Standards**
1. **VM0033** - Verra VCS Methodology for Tidal Wetland and Seagrass Restoration (2024)
2. **ORRAA** - High Quality Blue Carbon Principles and Guidance (2024)
3. **IPCC** - 2013 Supplement to 2006 Guidelines: Wetlands
4. Canadian Blue Carbon Network - Provincial Standards

### **🌾 Canadian Grassland Carbon Standards**
5. **AAFC** - Agriculture and Agri-Food Canada Soil Carbon Protocols (2024)
6. **AGGHG** - Canadian Agricultural Greenhouse Gas Monitoring Program Methods
7. **Alberta Offset System** - Conservation Cropping Protocol
8. **NRCan** - Natural Resources Canada Grassland Carbon Guidance
9. **IPCC 2006** - Grassland Chapter (Chapter 6)

### **Supporting Guidance (Both Ecosystems)**
10. **Verra VCS VM0026** - Sustainable Grassland Management (grassland)
11. Blue Carbon Initiative - Practitioner's Guide (coastal)
12. Restore America's Estuaries - Coastal Blue Carbon in Practice (coastal)

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
**Developed for:** Canadian Carbon Projects (Coastal & Grassland)
**Compliance:**
- 🌊 Coastal: VM0033, ORRAA, IPCC Wetlands Supplement
- 🌾 Grassland: AAFC, AGGHG Program, Alberta Offset System

**Citation:**
```
Composite Sampling Carbon MMRV Workflows v1.0 (2025).
Multi-ecosystem analysis pipeline for Canadian coastal and grassland carbon projects.
Includes:
  - Blue Carbon: VM0033-compliant analysis for coastal ecosystems
  - Grassland Carbon: AAFC-compliant analysis for prairie ecosystems
```

---

## 🎓 ACKNOWLEDGMENTS

### **🌊 Coastal Blue Carbon Workflow:**
Integrates best practices from:
- Verra VM0033 methodology
- ORRAA High Quality Blue Carbon Principles
- IPCC Wetlands Supplement guidance
- Canadian Blue Carbon Network
- Restore America's Estuaries
- Blue Carbon Initiative

### **🌾 Grassland Carbon Workflow:**
Integrates best practices from:
- Agriculture and Agri-Food Canada (AAFC)
- Canadian Agricultural Greenhouse Gas Monitoring Program
- Alberta Offset System
- Natural Resources Canada (NRCan)
- IPCC Grassland Chapter guidance
- Verra VM0026 methodology

**Developed to support transparent, science-based carbon verification in Canada across multiple ecosystems.**

---

**🌊 Ready to quantify coastal carbon? See [README_BLUE_CARBON_WORKFLOW.md](README_BLUE_CARBON_WORKFLOW.md)**

**🌾 Ready to quantify grassland carbon? See [README_GRASSLAND_WORKFLOW.md](README_GRASSLAND_WORKFLOW.md)**
