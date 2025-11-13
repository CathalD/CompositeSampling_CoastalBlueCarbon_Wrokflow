# 🌾 CANADIAN GRASSLAND CARBON MMRV WORKFLOW
## AAFC-Compliant Analysis Pipeline for Prairie and Rangeland Carbon Assessment

**Version:** 1.0 (Grassland Adaptation)
**Last Updated:** November 2025
**Compliance:** AAFC Soil Carbon Protocols, Canadian Agricultural GHG Program, Alberta Offset System
**Adapted From:** Coastal Blue Carbon Workflow (VM0033)

---

## 📋 OVERVIEW

This workflow provides a complete analysis pipeline for **Canadian grassland and rangeland carbon projects** across prairie ecosystems. It implements Agriculture and Agri-Food Canada (AAFC) methodology with conservative uncertainty estimation required for carbon offset verification.

### **Ecosystem Focus:**
- **Fescue Prairie** (Native fescue grasslands, AB/SK foothills)
- **Mixed-Grass Prairie** (Native C3/C4 mix, southern prairies)
- **Aspen Parkland** (Grassland-aspen mosaic, transition zone)
- **Improved Pasture** (Seeded, managed, fertilized)
- **Degraded Grassland** (Overgrazed, invasive species, erosion)

### **Key Features:**
✅ **Stratum-aware analysis** - Separate processing for 5 Canadian grassland types
✅ **AAFC compliant** - Conservative estimates (95% CI lower bound)
✅ **Canadian protocols** - AAFC, AGGHG Program, Alberta Offset System
✅ **Spatial modeling** - Random Forest + Kriging with AOA analysis
✅ **Uncertainty quantification** - Full error propagation
✅ **Grassland-specific** - Grazing history, fire frequency, root biomass

---

## 🗂️ WORKFLOW MODULES

### **Phase 1: Setup & Data Preparation**

#### **Module 00: Setup** ✅ AVAILABLE
- **File:** `00b_setup_directories.R`
- **Purpose:** Install packages, create directories
- **Runtime:** 5-10 minutes
- **Note:** Use same setup as blue carbon workflow

#### **Module 01: Grassland Data Preparation** ✅ COMPLETE
- **File:** `01_data_prep_grassland.R`
- **Purpose:** Load and clean core data with grassland-specific fields
- **Key Features:**
  - Validate 5 Canadian grassland strata
  - AAFC metadata (scenario, monitoring year)
  - Grassland-specific bulk density defaults (1.00-1.40 g/cm³)
  - Enhanced QA/QC for grassland SOC range (0-150 g/kg)
  - **NEW FIELDS:** grazing_history, fire_history, grass_type, ecoregion, root_biomass
- **Outputs:** `cores_clean_grassland.rds`

#### **Module 02: Exploratory Analysis** ✅ ADAPTED
- **File:** `02_exploratory_analysis_grassland.R`
- **Purpose:** EDA with grassland stratification
- **Key Features:**
  - Depth profiles by grassland stratum
  - Cross-stratum comparisons (native vs. managed)
  - Grazing intensity analysis
  - Outlier detection by ecosystem type
- **Outputs:** Diagnostic plots by grassland stratum

### **Phase 2: Depth Harmonization**

#### **Module 03: Spline Harmonization** ✅ ADAPTED
- **File:** `03_depth_harmonization_grassland.R`
- **Purpose:** Standardize depth profiles to grassland intervals (0-10, 10-30, 30-50, 50-100 cm)
- **Key Features:**
  - Grassland-specific spline parameters
  - Depth midpoints: 5, 20, 40, 75 cm
  - Focus on top 30 cm (highest SOC in grasslands)
  - Quality flags (realistic, monotonic decrease expected)
- **Outputs:** `cores_harmonized_spline_grassland.rds`

### **Phase 3: Spatial Prediction**

#### **Module 04: Kriging** ✅ ADAPTED
- **File:** `04_raster_predictions_kriging_grassland.R`
- **Purpose:** Spatial interpolation with grassland-specific variograms
- **Key Features:**
  - Separate variograms per grassland stratum
  - 30m resolution (suitable for Landsat-scale analysis)
  - Cross-validation
  - Uncertainty rasters (variance)
- **Outputs:**
  - `outputs/predictions/kriging/soc_*cm_grassland.tif`
  - `outputs/predictions/uncertainty/variance_*cm_grassland.tif`

#### **Module 05: Random Forest** ✅ ADAPTED
- **File:** `05_raster_predictions_rf_grassland.R`
- **Purpose:** Machine learning predictions with grassland covariates
- **Key Features:**
  - **Grassland-specific covariates:**
    - NDVI, EVI (productivity)
    - Precipitation (annual, growing season) - **CRITICAL for prairies**
    - Temperature (mean annual, GDD)
    - Grazing intensity (from management records)
    - Fire history (from Landsat NBR time series)
    - Soil texture (clay content for SOC stabilization)
    - Topographic position (slope, TWI)
  - Area of Applicability (AOA) analysis
  - Variable importance by grassland stratum
- **Outputs:**
  - `outputs/predictions/rf/soc_rf_*cm_grassland.tif`
  - `outputs/predictions/rf/aoa_*cm_grassland.tif`

### **Phase 4: Carbon Stock Calculation & Verification**

#### **Module 06: Carbon Stock Calculation** ✅ ADAPTED
- **File:** `06_carbon_stock_calculation_grassland.R`
- **Purpose:** Convert SOC predictions → Total carbon stocks
- **Key Features:**
  - Grassland depth intervals (0-30 cm, 30-100 cm)
  - Conservative estimates (95% CI lower bound)
  - Stratum-specific calculations
  - Grazing intensity adjustments
- **Outputs:**
  - `outputs/carbon_stocks/carbon_stocks_by_stratum_grassland.csv`
  - `outputs/carbon_stocks/carbon_stocks_conservative_aafc.csv`

#### **Module 07: MMRV Reporting** ✅ ADAPTED
- **File:** `07_mmrv_reporting_grassland.R`
- **Purpose:** Generate AAFC/Canadian offset verification package
- **Key Features:**
  - HTML verification report
  - Excel summary tables
  - **Canadian protocol citations:**
    - AAFC Soil Carbon Protocols
    - Canadian Agricultural GHG Monitoring Program
    - Alberta Offset System guidelines
    - NRCan grassland carbon guidance
  - QA/QC flagged areas
- **Outputs:**
  - `outputs/mmrv_reports/aafc_verification_package_grassland.html`
  - `outputs/mmrv_reports/aafc_summary_tables_grassland.xlsx`

---

## 📊 REQUIRED INPUT DATA

### **1. Field Core Data**

Two CSV files in `data_raw/`:

**core_locations.csv:**
```csv
core_id,longitude,latitude,stratum,collection_date,core_type,scenario_type,grazing_history,fire_history,grass_type,ecoregion
GRASS_001,-110.5,50.2,Fescue Prairie,2024-06-15,composite,PROJECT,Moderate,10 years,Native,Fescue Grasslands
GRASS_002,-105.8,49.8,Mixed-Grass Prairie,2024-06-16,composite,PROJECT,Heavy,>20 years,Native,Mixed Grasslands
GRASS_003,-112.1,51.5,Aspen Parkland,2024-06-17,composite,BASELINE,Light,None,Mixed,Aspen Parkland
GRASS_004,-108.3,50.5,Improved Pasture,2024-06-18,composite,PROJECT,Moderate,None,Seeded,Mixed Grasslands
GRASS_005,-106.7,49.3,Degraded Grassland,2024-06-19,composite,DEGRADED,Severe,None,Invasive,Mixed Grasslands
```

**Required columns:**
- `core_id`: Unique identifier
- `longitude`, `latitude`: WGS84 coordinates (prairie range: -120 to -90°W, 48-60°N)
- `stratum`: One of 5 valid grassland strata
- `collection_date`: YYYY-MM-DD format
- `core_type`: "hr_core" or "composite"
- `scenario_type`: "BASELINE", "PROJECT", "CONTROL", or "DEGRADED"

**NEW Grassland-Specific columns:**
- `grazing_history`: "None", "Light", "Moderate", "Heavy", "Severe" (or years since last grazing)
- `fire_history`: Years since last fire or "None", ">20 years"
- `grass_type`: "Native", "Seeded", "Mixed", "Invasive"
- `land_use`: "Rangeland", "Pasture", "Hayland", "Conservation"
- `ecoregion`: Canadian prairie ecoregion (optional but recommended)

**core_samples.csv:**
```csv
core_id,depth_top_cm,depth_bottom_cm,soc_g_kg,bulk_density_g_cm3,root_biomass_g_m2
GRASS_001,0,10,65.3,1.05,850
GRASS_001,10,30,42.1,1.15,320
GRASS_001,30,50,28.5,1.25,150
GRASS_001,50,100,18.2,1.30,80
```

**Required columns:**
- `core_id`: Links to core_locations
- `depth_top_cm`, `depth_bottom_cm`: Depth interval
- `soc_g_kg`: Soil organic carbon (g/kg) - expect 20-100 g/kg in topsoil
- `bulk_density_g_cm3`: Bulk density (g/cm³) - expect 1.0-1.4 for grasslands

**Optional columns:**
- `root_biomass_g_m2`: Root biomass (g/m²) if measured - most in top 30 cm

### **2. Remote Sensing Covariates**

Export from Google Earth Engine or use existing Canadian datasets

Place TIF files in `covariates/`:
```
covariates/
├── vegetation/
│   ├── NDVI_median.tif          # Landsat/Sentinel-2 (growing season)
│   ├── EVI_median.tif           # Enhanced vegetation index
│   ├── NDVI_max.tif             # Peak greenness
├── climate/
│   ├── precip_annual.tif        # Annual precipitation (mm) - CRITICAL
│   ├── precip_gs.tif            # Growing season precipitation
│   ├── temp_mean.tif            # Mean annual temperature (°C)
│   ├── gdd.tif                  # Growing degree days
├── topographic/
│   ├── elevation.tif            # DEM (SRTM, CDEM)
│   ├── slope.tif
│   ├── aspect.tif
│   ├── TWI.tif                  # Topographic wetness index
├── soil/
│   ├── clay_content.tif         # Soil clay % (affects SOC stabilization)
│   ├── soil_drainage.tif        # Drainage class
├── disturbance/
│   ├── grazing_intensity.tif    # From management or remote sensing
│   ├── fire_history.tif         # Years since fire or NBR
│   └── NBR.tif                  # Normalized Burn Ratio (Landsat)
```

**Minimum Required (for Random Forest):**
- NDVI (vegetation productivity)
- Annual precipitation (critical for semi-arid prairies)
- Elevation (topographic position)
- Clay content (SOC stabilization)
- At least **8-12 total covariates** recommended

**Canadian Data Sources:**
- **Climate:** Environment Canada, ClimateNA, PCIC
- **Elevation:** Natural Resources Canada CDEM
- **Soil:** Agriculture and Agri-Food Canada (AAFC) Soil Landscapes of Canada
- **Vegetation:** Landsat Analysis Ready Data (CARD4L), Sentinel-2
- **Fire:** Canadian Wildland Fire Information System (CWFIS)

### **3. Stratum Information** (Recommended)

**Option A:** Grassland stratum raster
- `covariates/stratum.tif` - Each pixel labeled with grassland type

**Option B:** Stratum polygons
- `data_raw/strata_polygons.geojson` - Vector boundaries of each grassland type

---

## 🚀 QUICK START GUIDE

### **1. Install and Setup**
```r
# Set working directory to project folder
setwd("/path/to/grassland_carbon_project")

# Run setup (same as blue carbon)
source("00b_setup_directories.R")

# Create/edit grassland configuration
file.edit("grassland_carbon_config.R")
```

### **2. Prepare Your Data**
- Add field data CSVs to `data_raw/` with grassland-specific columns
- Add covariate TIFs to `covariates/` (focus on precipitation, NDVI, grazing)
- Verify file formats and column names

### **3. Run Grassland Analysis Pipeline**
```r
# Data preparation
source("01_data_prep_grassland.R")

# Exploratory analysis
source("02_exploratory_analysis_grassland.R")

# Depth harmonization
source("03_depth_harmonization_grassland.R")

# Spatial predictions (choose one or both)
source("04_raster_predictions_kriging_grassland.R")  # Kriging
source("05_raster_predictions_rf_grassland.R")       # Random Forest (recommended)

# Carbon stock calculation
source("06_carbon_stock_calculation_grassland.R")

# Generate AAFC verification package
source("07_mmrv_reporting_grassland.R")
```

### **4. Review Outputs**
```r
# Open verification report in browser
browseURL("outputs/mmrv_reports/aafc_verification_package_grassland.html")

# Review carbon stocks by grassland type
stocks <- read.csv("outputs/carbon_stocks/carbon_stocks_conservative_aafc.csv")
print(stocks)

# Check model performance
cv_results <- read.csv("diagnostics/crossvalidation/rf_cv_results_grassland.csv")
print(cv_results)
```

---

## ⚙️ CONFIGURATION

Edit `grassland_carbon_config.R` to customize:

### **Project Metadata**
```r
PROJECT_NAME <- "Alberta_Grassland_Carbon_2024"
PROJECT_SCENARIO <- "PROJECT"  # or BASELINE, CONTROL, DEGRADED
MONITORING_YEAR <- 2024
PROJECT_LOCATION <- "Canadian Prairies (Alberta/Saskatchewan)"
```

### **Grassland Ecosystem Strata**
```r
VALID_STRATA <- c(
  "Fescue Prairie",       # Native fescue, AB/SK foothills
  "Mixed-Grass Prairie",  # Native C3/C4 mix
  "Aspen Parkland",       # Grass-tree mosaic
  "Improved Pasture",     # Seeded, managed
  "Degraded Grassland"    # Overgrazed, invaded
)
```

### **Grassland Depth Intervals**
```r
# Focus on top 30 cm (most SOC), but sample to 100 cm
GRASSLAND_DEPTH_INTERVALS <- data.frame(
  depth_top = c(0, 10, 30, 50),
  depth_bottom = c(10, 30, 50, 100),
  depth_midpoint = c(5, 20, 40, 75)
)
```

### **Coordinate Systems (Canadian)**
```r
INPUT_CRS <- 4326      # WGS84 (input data)
PROCESSING_CRS <- 3347 # Canada Albers Equal Area (prairie provinces)
```

### **Bulk Density Defaults (Canadian Grassland Soils)**
```r
BD_DEFAULTS <- list(
  "Fescue Prairie" = 1.05,        # Deep A-horizon, high OM
  "Mixed-Grass Prairie" = 1.20,   # Moderate OM, drier
  "Aspen Parkland" = 1.00,        # Tree litter influence
  "Improved Pasture" = 1.15,      # Managed
  "Degraded Grassland" = 1.40     # Compacted from overgrazing
)
```

### **Grassland-Specific Parameters**
```r
GRAZING_INTENSITY <- "Moderate"  # None, Light, Moderate, Heavy, Severe
FIRE_FREQUENCY_YEARS <- 10       # Years between fires (less frequent in Canada)
ROOT_SAMPLING_DEPTH <- 30        # Most root biomass in top 30 cm
GROWING_SEASON_START <- "May"
GROWING_SEASON_END <- "September"
```

---

## 📈 EXPECTED OUTPUTS

### **Carbon Stock Maps (Grassland)**
- `carbon_stock_surface_mean_grassland.tif` - 0-30 cm (critical layer)
- `carbon_stock_deep_mean_grassland.tif` - 30-100 cm
- `carbon_stock_total_mean_grassland.tif` - 0-100 cm total
- `carbon_stock_*_conservative_aafc.tif` - Lower bound estimates
- `carbon_stock_*_se_grassland.tif` - Standard error maps

### **Verification Tables**
1. **Project Metadata** - Grassland type, grazing, fire history
2. **Carbon Stocks by Stratum** - AAFC format
3. **Model Performance** - CV metrics
4. **QA/QC Summary** - Data quality checks

### **Performance Metrics** (Expected for Grasslands)
- **CV R²:** > 0.6 (grasslands can be more variable than wetlands)
- **CV RMSE:** < 15 g/kg (acceptable for prairie soils)
- **AOA Coverage:** > 85% (good extrapolation control)

---

## 🎯 AAFC COMPLIANCE CHECKLIST

- [x] **Field Sampling**
  - Soil cores to 100 cm (minimum 30 cm)
  - Stratum-specific sampling design
  - GPS coordinates recorded (WGS84)
  - Grazing and fire history documented

- [x] **Laboratory Analysis**
  - SOC measured (g/kg) - verify within 0-150 g/kg range
  - Bulk density measured (g/cm³) - expect 1.0-1.4
  - QA/QC standards applied

- [x] **Depth Harmonization**
  - Equal-area splines or mass-weighted averaging
  - Standard depths (0-10, 10-30, 30-50, 50-100 cm)
  - Quality flags (realistic, monotonic decrease)

- [x] **Spatial Modeling**
  - Cross-validation performed
  - Model performance documented (R², RMSE)
  - Area of Applicability assessed
  - Precipitation and climate covariates included

- [x] **Uncertainty Quantification**
  - 95% confidence intervals calculated
  - Conservative estimates (lower bound)
  - Uncertainty propagated through calculations

- [x] **Carbon Stock Calculation**
  - Depth intervals: 0-30 cm, 30-100 cm, 0-100 cm total
  - Grassland stratum-specific calculations
  - Conservative approach applied

- [x] **Reporting & Verification**
  - AAFC-compliant verification package generated
  - Spatial data exported (GeoTIFFs)
  - QA/QC documentation complete
  - Canadian protocol citations included

---

## 🌟 CANADIAN GRASSLAND BEST PRACTICES

### **Sampling Design**
- **Minimum 20-30 cores per grassland stratum** for robust spatial modeling
- **Stratified random sampling** within ecosystem boundaries
- **Include grazing gradient** (light, moderate, heavy) if possible
- **Document management history:** grazing regime, fire, fertilization, reseeding

### **Covariate Selection for Canadian Prairies**
- **Minimum 10-15 covariates** for Random Forest
- **CRITICAL for semi-arid prairies:**
  - Precipitation (annual, growing season) - **most important**
  - Temperature (mean, GDD)
  - NDVI, EVI (productivity)
- **Management indicators:**
  - Grazing intensity (from records or remote sensing)
  - Fire history (from Landsat NBR)
- **Soil properties:**
  - Clay content (SOC stabilization)
  - Drainage class
  - Topographic wetness index

### **Quality Control**
- **Review all QA flags** before final analysis
- **Check for outliers** by grassland stratum
- **SOC range:** Expect 20-100 g/kg in topsoil, <20 g/kg below 50 cm
- **BD range:** Expect 1.0-1.4 g/cm³ (higher for degraded)
- **Validate predictions** in known areas
- **Examine AOA coverage** (>85% recommended)

### **Grassland-Specific Considerations**
- **Grazing effects:** Document grazing intensity and timing
- **Fire history:** Include fire frequency (Canadian prairies: typically >10 years)
- **Native vs. seeded:** Separate analysis if possible
- **Root biomass:** Include if measured (most in top 30 cm)
- **Seasonality:** Sample outside active growing season (Oct-Apr) to avoid root disruption
- **Compaction:** Degraded/overgrazed sites may have higher BD (up to 1.6 g/cm³)

---

## 🔧 TROUBLESHOOTING

### **Common Issues - Grasslands**

#### **"SOC values outside expected range"**
- **Cause:** Grassland topsoil can range 20-100 g/kg
- **Fix:** Check QC_SOC_MAX in config (set to 150 g/kg for grasslands)

#### **"High spatial variability (CV >40%)"**
- **Cause:** Grazing creates high spatial heterogeneity
- **Fix:** Increase sample size, stratify by grazing intensity

#### **"Low model R² (<0.5)"**
- **Cause:** Missing key covariates (precipitation, grazing)
- **Fix:** Add precipitation (annual, GS), grazing intensity, fire history

#### **"AOA coverage low (<70%)"**
- **Cause:** Predicting in ungrazed areas when trained on grazed
- **Fix:** Collect additional cores in undersampled management regimes

### **Grassland-Specific Tips**
- **Precipitation is critical:** Always include annual and growing season precipitation
- **Grazing matters:** Try to stratify or include grazing intensity as covariate
- **Topsoil focus:** Most carbon in 0-30 cm; weight this layer in analysis
- **Fire history:** Include if available (affects SOC accumulation)
- **Native > Seeded:** Expect higher SOC in native grasslands vs. improved pasture

---

## 📚 REFERENCES

### **Primary Canadian Standards**
1. **AAFC** - Agriculture and Agri-Food Canada Soil Carbon Protocols (2024)
2. **AGGHG** - Canadian Agricultural Greenhouse Gas Monitoring Program Methods
3. **Alberta Offset System** - Conservation Cropping Protocol (applicable sections)
4. **NRCan** - Natural Resources Canada Grassland Carbon Guidance

### **Secondary Guidance**
5. **IPCC 2006** - Grassland Chapter (Chapter 6) - International context
6. **Verra VCS VM0026** - Sustainable Grassland Management (if seeking verification)
7. **USDA NRCS** - Soil Carbon Protocols (reference only - use Canadian methods)

### **Key Canadian Papers**
8. VandenBygaart et al. (2011) - Soil organic carbon stocks on Canadian agricultural lands
9. McConkey et al. (2007) - Canadian agricultural soil carbon database
10. Ellert and Bettany (1995) - Calculation of organic matter and nutrients stored in soils

### **Canadian Data Sources**
11. **AAFC Soil Landscapes of Canada:** https://sis.agr.gc.ca/cansis/nsdb/slc/v3.2/
12. **ClimateNA:** https://climatena.ca/ (climate data for prairies)
13. **CWFIS:** https://cwfis.cfs.nrcan.gc.ca/ (fire history)

---

## 📞 SUPPORT & CONTRIBUTION

### **Questions?**
- Review module-specific log files in `logs/`
- Check AAFC compliance report for flagged issues
- Consult AAFC Soil Carbon Protocols

### **Found a Bug?**
- Document the error message
- Include relevant log file excerpts
- Note your R version and package versions

### **Want to Contribute?**
- Share Canadian grassland-specific calibrations
- Report successful AAFC verifications
- Suggest improvements for prairie-specific analysis

---

## 📄 LICENSE & CITATION

**Workflow Version:** 1.0 (Grassland Adaptation, November 2025)
**Developed for:** Canadian Prairie and Grassland Carbon Projects
**Compliance:** AAFC, Canadian Agricultural GHG Program, Alberta Offset System
**Adapted from:** Coastal Blue Carbon MMRV Workflow v1.0

**Citation:**
```
Canadian Grassland Carbon MMRV Workflow v1.0 (2025).
AAFC-compliant analysis pipeline for Canadian prairie and rangeland ecosystems.
Adapted from Coastal Blue Carbon Workflow.
```

---

## 🎓 ACKNOWLEDGMENTS

This grassland workflow integrates best practices from:
- Agriculture and Agri-Food Canada (AAFC)
- Canadian Agricultural Greenhouse Gas Monitoring Program
- Alberta Offset System
- Natural Resources Canada (NRCan)
- IPCC Grassland Chapter guidance
- Verra VM0026 methodology

Developed to support transparent, science-based grassland carbon verification in Canadian prairie provinces.

---

## 🌾 KEY DIFFERENCES FROM COASTAL WORKFLOW

| Aspect | Coastal (Original) | Grassland (Adapted) |
|--------|-------------------|---------------------|
| **Ecosystem Types** | 5 tidal/coastal | 5 Canadian grassland types |
| **Depth Focus** | 0-100 cm (burial-driven) | 0-30 cm primary, extend to 100 cm |
| **Depth Intervals** | 0-15, 15-30, 30-50, 50-100 | 0-10, 10-30, 30-50, 50-100 |
| **SOC Range** | 0-500 g/kg | 0-150 g/kg |
| **Bulk Density** | 0.6-1.2 g/cm³ (organic-rich) | 1.0-1.4 g/cm³ (mineral soils) |
| **Key Covariates** | NDWI, SAR, tidal elevation | Precipitation, NDVI, grazing, fire |
| **Climate Driver** | Tidal regime, salinity | Precipitation (semi-arid) |
| **Disturbance** | Sea level, storms | Grazing, fire |
| **Coordinate System** | BC Albers, UTM | Canada Albers (prairies) |
| **Primary Protocol** | VM0033 (Verra) | AAFC, AGGHG, Alberta Offset |
| **Verification Body** | Verra VCS | Environment Canada, AB govt |
| **Carbon Process** | Rapid burial, anaerobic | Slow accumulation, root inputs |
| **Management** | Restoration, protection | Grazing, fire, seeding |
| **Root Biomass** | Not measured | Optional (most in 0-30 cm) |
| **Seasonality** | Tidal cycles | Growing season (May-Sep) |
| **Spatial Resolution** | 10m (high detail) | 30m (Landsat scale) |

---

**🌾 Ready to quantify Canadian grassland carbon? Start with Module 00 and 01!**

---

## 🛠️ TROUBLESHOOTING: MODULE-SPECIFIC

### **Module 01: Data Preparation**
- **Error:** "Invalid grassland strata"
  - **Fix:** Check stratum names match exactly: "Fescue Prairie", "Mixed-Grass Prairie", etc.
- **Warning:** "grazing_history not specified"
  - **Impact:** Analysis proceeds, but loses key management context
  - **Fix:** Add column to core_locations.csv

### **Module 03: Depth Harmonization**
- **Error:** "Insufficient depth coverage"
  - **Cause:** Grassland cores <50 cm depth
  - **Fix:** Accept if 0-30 cm complete (most critical layer), or collect deeper cores

### **Module 05: Random Forest**
- **Low R²:** <0.5
  - **Fix:** Add precipitation covariates (most important for prairies)
  - **Fix:** Include grazing intensity if available
- **High RMSE:** >20 g/kg
  - **Cause:** High spatial variability from grazing
  - **Fix:** Increase sample size, add management covariates

### **Module 07: Reporting**
- **Missing citations:** AAFC protocols
  - **Fix:** Module automatically includes Canadian protocol references
  - **Verify:** Check `PROTOCOL_REFERENCES` in config

---

**End of Grassland Workflow README**
