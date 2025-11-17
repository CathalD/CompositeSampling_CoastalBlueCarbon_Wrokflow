# 🌾 CANADIAN GRASSLAND CARBON MMRV WORKFLOW
## VM0026/VM0032/VM0042 & Alberta TIER Compliant Analysis Pipeline for Canadian Prairie Ecosystems

**Version:** 1.0 (Adapted from Blue Carbon Workflow)
**Last Updated:** November 2024
**Compliance:** VM0026, VM0032, VM0042, Alberta TIER, Canadian Agricultural GHG Methodology (IPCC Tier 3)

---

## 📋 OVERVIEW

This workflow provides a complete analysis pipeline for grassland carbon projects in Canadian prairie ecosystems (native prairie, improved pastures, restored grasslands). It implements multiple Verra (VCS) methodologies and Alberta TIER protocols with conservative uncertainty estimation required for carbon credit verification.

### **Target Ecosystems:**
- Native Prairie (never cultivated, reference condition)
- Improved Pasture (seeded, fertilized, managed grazing)
- Degraded Grassland (overgrazed, invaded, compacted)
- Restored Grassland (cropland to grassland conversion)
- Riparian Grassland (wetland margins, higher moisture)

### **Key Features:**
✅ **Multiple Protocol Compliance** - VM0026, VM0032, VM0042, Alberta TIER
✅ **Grassland-Specific Depths** - Focus on 0-30 cm active layer, full profile to 100 cm
✅ **Canadian Context** - Alberta/Saskatchewan/Manitoba parameters and data sources
✅ **Management Variables** - Grazing history, species composition, soil texture
✅ **Conservative Estimates** - 95% CI lower bound for crediting
✅ **Spatial Modeling** - Random Forest + Kriging with grassland covariates
✅ **Temporal Analysis** - Additionality and multi-period monitoring

---

## 🌍 VERIFICATION STANDARDS COVERED

### **VCS VM0026 - Avoided Grassland Conversion**
- **Application:** Preventing conversion of native grassland to cropland
- **Key Requirements:**
  - Minimum 5 cores per stratum
  - Documentation of conversion threat
  - Species composition surveys
  - Baseline scenario modeling

### **VCS VM0032 - Improved Grassland Management**
- **Application:** Improved grazing management on existing grasslands
- **Key Requirements:**
  - Minimum 5 cores per stratum
  - Grazing management documentation (stocking rates, rest periods)
  - Baseline vs project comparison
  - Monitoring every 5 years

### **VCS VM0042 - Improved Agricultural Land Management**
- **Application:** Soil carbon sequestration through agricultural practices
- **Key Requirements:**
  - Primary focus on 0-30 cm soil layer
  - Soil texture analysis (clay content)
  - Management history documentation
  - Cross-validation of spatial predictions

### **Alberta TIER - Grassland Carbon Offsets**
- **Application:** Alberta-specific offset crediting system
- **Key Requirements:**
  - Minimum 3 cores per stratum
  - 8-year crediting period
  - Alberta-specific SOC baselines
  - Provincial reporting format

### **Canadian Agricultural GHG Methodology (IPCC Tier 3)**
- **Application:** High-accuracy national GHG accounting
- **Key Requirements:**
  - Site-specific field data (Tier 3)
  - 95% confidence intervals
  - Canadian CRS and data sources
  - Target precision ≤20% relative error

---

## 🔬 GRASSLAND-SPECIFIC PARAMETERS

### **Depth Intervals (Replaces VM0033 Marine Depths)**

```r
# Primary grassland depth midpoints
GRASSLAND_DEPTH_MIDPOINTS <- c(7.5, 22.5, 40, 75)  # cm

# Depth intervals
# 0-15 cm:   Primary active layer (root concentration, management effects)
# 15-30 cm:  Secondary active layer (lower root zone)
# 30-50 cm:  Transition zone (minimal management effect)
# 50-100 cm: Deep storage (legacy carbon)

# Optional shallow depths for grazing impact assessment
SHALLOW_DEPTH_INTERVALS <- c(0-5, 5-10, 10-15 cm)
```

### **Grassland Strata Definitions**

| Stratum | Description | Expected SOC (0-30cm) | Bulk Density |
|---------|-------------|----------------------|--------------|
| **Native Prairie** | Never cultivated, reference | 60-80 Mg C/ha | 1.1 g/cm³ |
| **Improved Pasture** | Seeded, fertilized, managed | 40-60 Mg C/ha | 1.3 g/cm³ |
| **Degraded Grassland** | Overgrazed, compacted | 30-45 Mg C/ha | 1.4 g/cm³ |
| **Restored Grassland** | Ex-cropland restoration | 35-55 Mg C/ha | 1.2 g/cm³ |
| **Riparian Grassland** | Wetland margins, high OM | 55-75 Mg C/ha | 1.0 g/cm³ |

### **Quality Control Thresholds**

```r
# Soil Organic Carbon (g/kg)
QC_SOC_MIN <- 10    # Lower than wetlands, higher than cropland
QC_SOC_MAX <- 150   # Native prairie/riparian upper bound

# Bulk Density (g/cm³)
QC_BD_MIN <- 0.8    # Organic-rich riparian
QC_BD_MAX <- 1.6    # Heavily compacted degraded grassland

# Focus on top 30 cm for management effects
```

### **Spatial Covariates (Grassland-Specific)**

#### **Climate Covariates** (High Importance)
- Growing degree days (GDD base 5°C)
- Annual precipitation (mm)
- Growing season precipitation (Apr-Sep)
- Aridity index
- Frost-free days

#### **Soil Covariates** (Critical for SOC)
- Clay content (% - crucial for SOC protection)
- Soil pH
- Cation exchange capacity (CEC)
- Available water capacity
- Soil depth to bedrock

#### **Topographic Covariates**
- Elevation
- Slope
- Aspect
- Topographic wetness index (TWI)
- Solar radiation

#### **Vegetation Covariates** (Remote Sensing)
- NDVI (median, max, std, integral)
- EVI (Enhanced Vegetation Index)
- SAVI (Soil-Adjusted Vegetation Index)
- NBR (Normalized Burn Ratio)
- Greenup/senescence dates

#### **Land Use Covariates**
- Years since cropland conversion
- Distance to water
- Land use intensity index

---

## 📊 REQUIRED INPUT DATA

### **1. Field Core Data**

Two CSV files in `data_raw/`:

**core_locations.csv:**
```csv
core_id,longitude,latitude,stratum,collection_date,core_type,scenario_type,grazing_system,stocking_rate_AUM
AB_001,-113.5,51.0,Native Prairie,2024-06-15,hr_core,PROJECT,rotational,4.5
AB_002,-113.6,51.1,Improved Pasture,2024-06-15,composite,PROJECT,continuous,6.2
```

**Required columns:**
- `core_id`: Unique identifier
- `longitude`, `latitude`: WGS84 coordinates
- `stratum`: One of 5 valid grassland strata
- `collection_date`: YYYY-MM-DD
- `core_type`: "hr_core" or "composite"
- `scenario_type`: "BASELINE", "PROJECT", "NATIVE", "DEGRADED", "CROPLAND"

**Optional but Recommended (VM0032):**
- `grazing_system`: rotational, continuous, seasonal
- `stocking_rate_AUM`: Animal Unit Months per ha
- `rest_period_days`: Days of rest per year
- `native_species_pct`: % native species cover
- `clay_pct`: % clay content

**core_samples.csv:**
```csv
core_id,depth_top_cm,depth_bottom_cm,soc_g_kg,bulk_density_g_cm3,clay_pct,root_biomass_g_m2
AB_001,0,15,65.3,1.05,28,850
AB_001,15,30,52.1,1.12,32,320
```

**Required columns:**
- `core_id`: Links to core_locations
- `depth_top_cm`, `depth_bottom_cm`: Depth interval
- `soc_g_kg`: Soil organic carbon (g/kg)
- `bulk_density_g_cm3`: Bulk density (g/cm³)

**Optional but Recommended:**
- `clay_pct`: % clay (VM0042 requirement)
- `root_biomass_g_m2`: Root biomass (g/m²)

### **2. Remote Sensing Covariates**

Export from Google Earth Engine or use Canadian data sources:

**Minimum Required:**
```
covariates/
├── vegetation/
│   ├── NDVI_median.tif
│   ├── NDVI_max.tif
│   ├── EVI_median.tif
├── climate/
│   ├── growing_degree_days.tif
│   ├── precipitation_annual.tif
│   ├── precipitation_growing_season.tif
├── soil/
│   ├── clay_content_pct.tif
│   ├── soil_pH.tif
├── topographic/
│   ├── elevation.tif
│   ├── slope.tif
│   ├── topographic_wetness_index.tif
```

**Canadian Data Sources:**
- **Agriculture and Agri-Food Canada (AAFC):** Annual Crop Inventory, soil data
- **SoilGrids 250m:** Global SOC maps (can use as Bayesian priors)
- **CanSIS:** Canadian Soil Information Service
- **NFIS:** National Forest Inventory System
- **Provincial inventories:** Alberta Grassland Vegetation Inventory, Saskatchewan prairie data

---

## 🚀 QUICK START GUIDE

### **Step 1: Setup**

```r
# Set working directory
setwd("/path/to/grassland_carbon_project")

# Run setup (only once)
source("00b_setup_directories.R")

# Review and edit grassland configuration
file.edit("grassland_carbon_config.R")
```

### **Step 2: Configure Project**

Edit `grassland_carbon_config.R`:

```r
PROJECT_NAME <- "Alberta_Prairie_Carbon_2024"
PROJECT_SCENARIO <- "PROJECT"  # or BASELINE, NATIVE, DEGRADED
MONITORING_YEAR <- 2024

# Choose applicable standards
VM0026_ENABLED <- TRUE   # Avoided conversion
VM0032_ENABLED <- TRUE   # Improved management
VM0042_ENABLED <- FALSE  # Agricultural land mgmt
ALBERTA_TIER_ENABLED <- TRUE

# Set grassland strata
VALID_STRATA <- c(
  "Native Prairie",
  "Improved Pasture",
  "Degraded Grassland",
  "Restored Grassland",
  "Riparian Grassland"
)
```

### **Step 3: Prepare Field Data**

Add CSV files to `data_raw/`:
- `core_locations.csv` (GPS, stratum, grazing data)
- `core_samples.csv` (SOC, bulk density, depths)

### **Step 4: Run Analysis Pipeline**

```r
# Use grassland config instead of blue carbon
source("grassland_carbon_config.R")

# Data preparation (adapt Module 01 for grassland variables)
source("01_data_prep_bluecarbon.R")  # Will read grassland_carbon_config.R

# Exploratory analysis
source("02_exploratory_analysis_bluecarbon.R")

# Depth harmonization (uses GRASSLAND_DEPTH_MIDPOINTS)
source("03_depth_harmonization_bluecarbon.R")

# Spatial predictions
source("05_raster_predictions_rf_bluecarbon.R")  # Uses grassland covariates

# Carbon stock calculation (0-30 cm focus, full profile to 100 cm)
source("06_carbon_stock_calculation_bluecarbon.R")

# Generate grassland standards compliance report
source("07b_comprehensive_standards_report_grassland.R")
```

### **Step 5: Review Grassland Standards Report**

```r
browseURL("outputs/reports/comprehensive_grassland_standards_report.html")
```

The report includes:
- ✅ VM0026, VM0032, VM0042, TIER, Canadian IPCC compliance checks
- 📊 Carbon stocks by grassland stratum
- 📈 Cross-validation performance
- ⚠️ Actionable recommendations
- 📋 Data quality summary

---

## 🔄 MULTI-SCENARIO WORKFLOW

For additionality analysis (PROJECT vs BASELINE):

```r
# Scenario 1: Baseline (pre-project or conventional management)
PROJECT_SCENARIO <- "BASELINE"
MONITORING_YEAR <- 2020
source("01_data_prep_bluecarbon.R")  # Run through Module 07

# Scenario 2: Project (improved management or avoided conversion)
PROJECT_SCENARIO <- "PROJECT"
MONITORING_YEAR <- 2024
source("01_data_prep_bluecarbon.R")  # Run through Module 07

# Scenario 3: Native Prairie Reference
PROJECT_SCENARIO <- "NATIVE"
MONITORING_YEAR <- 2024
source("01_data_prep_bluecarbon.R")  # Run through Module 07

# Temporal analysis (PROJECT - BASELINE)
source("08_temporal_data_harmonization.R")
source("09_additionality_temporal_analysis.R")
```

---

## 📝 ADDITIONAL VARIABLES TO DOCUMENT

### **Grazing Management (VM0032)**

- **Grazing system:** rotational, continuous, seasonal, deferred
- **Stocking rate:** AUM/ha (Animal Unit Months per hectare)
- **Rest periods:** days of rest per year
- **Grazing intensity:** light (<30% utilization), moderate (30-50%), heavy (>50%)
- **Grazing season:** start and end dates

### **Species Composition (VM0026)**

- **Native species:** % cover native grasses and forbs
- **C3 grasses:** % cool-season grasses
- **C4 grasses:** % warm-season grasses
- **Forbs:** % non-grass herbaceous plants
- **Shrubs:** % woody plants
- **Invasive species:** % non-native invasive plants

### **Soil Texture (VM0042)**

- **Clay content:** % clay (<0.002 mm) - **CRITICAL for SOC protection**
- **Silt content:** % silt (0.002-0.05 mm)
- **Sand content:** % sand (0.05-2 mm)
- **Texture class:** clay, clay loam, loam, sandy loam, etc.

### **Root Biomass (Optional but Recommended)**

- **Root biomass (0-30 cm):** g/m² or Mg/ha
- **Root:shoot ratio:** ratio of below to aboveground biomass
- **Fine root percentage:** % roots <2mm diameter

### **Management History (Required for Additionality)**

- **Cultivation history:** timeline of tillage events
- **Years since cultivation:** years since last tillage (for restored grasslands)
- **Fertilization history:** N fertilizer application rates (kg N/ha/yr)
- **Fire history:** prescribed burn timeline and frequency
- **Years since fire:** years since last burn

---

## 🎯 VERIFICATION CHECKLIST

### **Field Sampling**
- [ ] Minimum 5 cores per stratum (VM0026/VM0032) or 3 cores (TIER)
- [ ] GPS coordinates recorded (WGS84)
- [ ] Depth intervals: 0-15, 15-30, 30-50, 50-100 cm
- [ ] Grazing management documented (VM0032)
- [ ] Species composition surveyed (VM0026)

### **Laboratory Analysis**
- [ ] SOC measured (g/kg) - valid range 10-150
- [ ] Bulk density measured (g/cm³) - valid range 0.8-1.6
- [ ] Clay content analyzed (% clay) - VM0042 requirement
- [ ] QA/QC standards applied

### **Spatial Modeling**
- [ ] Grassland-specific covariates (NDVI, GDD, precipitation, clay)
- [ ] Cross-validation performed (R² > 0.5 recommended)
- [ ] Area of Applicability assessed
- [ ] Spatial resolution appropriate (30m recommended)

### **Uncertainty Quantification**
- [ ] 95% confidence intervals calculated
- [ ] Conservative estimates (lower bound) reported
- [ ] Target precision ≤20% relative error

### **Documentation**
- [ ] Grazing management records (stocking rates, rest periods)
- [ ] Management history (tillage, fertilizer, fire)
- [ ] Baseline scenario defined (for additionality)
- [ ] Monitoring schedule established (every 5 years)

---

## 🌟 BEST PRACTICES FOR GRASSLAND PROJECTS

### **Sampling Design**
- **Minimum 30 cores total** across all strata for robust modeling
- **Stratified random sampling** within grassland types
- **Include native prairie reference** sites when possible
- **Permanent plot markers** for repeat monitoring
- **Paired designs** (pre/post, treatment/control) for improved management projects

### **Covariate Selection**
- **Priority covariates:**
  1. Climate: Growing degree days, precipitation
  2. Soil: Clay content (% clay)
  3. Vegetation: NDVI time series
  4. Topography: Topographic wetness index
  5. Land use: Years since conversion
- **Target 10-15 total covariates** for Random Forest
- **Use Canadian data sources** when available (AAFC, CanSIS)

### **Quality Control**
- **Review grazing compliance** thresholds (VM0032):
  - Stocking rate <8 AUM/ha (site-specific)
  - Rest period >60 days/year
  - Utilization <50%
- **Check SOC plausibility** by stratum:
  - Native prairie: highest
  - Degraded grassland: lowest
  - Restored grassland: intermediate, increasing over time
- **Validate spatial predictions** in known areas
- **Examine AOA coverage** (>90% recommended)

### **Uncertainty Management**
- **Always use conservative estimates** (95% CI lower bound) for crediting
- **Account for management variability** (grasslands have higher CV than forests)
- **Document data gaps** and limitations
- **Inflate uncertainty** for modeled scenarios (+15%)

---

## 📚 KEY DIFFERENCES FROM BLUE CARBON WORKFLOW

| Parameter | Blue Carbon (VM0033) | Grassland (VM0026/VM0032/VM0042) |
|-----------|---------------------|----------------------------------|
| **Depth intervals** | 0-15, 15-30, 30-50, 50-100 cm | 0-15, 15-30, 30-50, 50-100 cm (same) |
| **Primary depth focus** | 0-100 cm (full profile) | 0-30 cm (management effects) |
| **SOC range** | 0-500 g/kg (very high) | 10-150 g/kg (moderate) |
| **Bulk density** | 0.1-3.0 g/cm³ (wide range) | 0.8-1.6 g/cm³ (soil-specific) |
| **Strata** | Marine ecosystems (marsh, seagrass) | Grassland types (native, improved, degraded) |
| **Key covariates** | NDWI, tidal elevation, SAR | NDVI, GDD, precipitation, clay |
| **Management variables** | Tidal restoration, hydrologic change | Grazing, species composition, fire |
| **Verification standards** | VM0033, ORRAA | VM0026, VM0032, VM0042, TIER |
| **Monitoring frequency** | 5 years | 5 years (same) |
| **Assumed CV** | 30% | 35% (higher variability) |
| **Cell size** | 10m | 30m (larger areas) |

---

## 📖 REFERENCES

### **Primary Protocols**

1. **VCS VM0026** - Avoided Grassland Conversion (Verra, 2024)
2. **VCS VM0032** - Improved Grassland Management (Verra, 2024)
3. **VCS VM0042** - Improved Agricultural Land Management (Verra, 2024)
4. **Alberta TIER** - Technology Innovation and Emissions Reduction Offset Protocols
5. **Canadian Agricultural GHG Methodology** - IPCC Tier 3

### **Supporting Guidance**

6. **Canada Grassland Project Protocol** - Climate Action Reserve (draft)
7. **Canada Grassland Protocol: Backgrounder** - Canadian Federation of Agriculture
8. **Robust carbon MRV for grassland management** - NFWF / Woods Hole (2025)
9. **Grasslands protocol framework** - ALUS
10. **How to measure, report and verify soil carbon change** - Smith et al.

### **Canadian Data Sources**

11. **AAFC Soil Organic Carbon Database** - https://sis.agr.gc.ca/cansis/nsdb/soc/
12. **Canadian Soil Information Service (CanSIS)** - https://sis.agr.gc.ca/cansis/
13. **Alberta Grassland Vegetation Inventory (AGVI)**
14. **Carbon sequestration in Canada's croplands** - review (2022)

---

## 📞 SUPPORT & CONTRIBUTION

### **Questions?**
- Review module-specific log files in `logs/`
- Check grassland standards report for flagged issues
- Consult VM0026/VM0032/VM0042 methodology documents

### **Found a Bug?**
- Document the error message
- Note your R version and package versions
- Include relevant log file excerpts

---

## 📄 LICENSE & CITATION

**Workflow Version:** 1.0 (November 2024)
**Adapted From:** Blue Carbon Composite Sampling Workflow
**Developed For:** Canadian Grassland Carbon Projects
**Compliance:** VM0026, VM0032, VM0042, Alberta TIER, Canadian IPCC Tier 3

**Citation:**
```
Canadian Grassland Carbon MMRV Workflow v1.0 (2024).
VM0026/VM0032/VM0042-compliant analysis pipeline for Canadian prairie ecosystems.
Adapted from Blue Carbon MMRV Workflow.
```

---

## 🎓 ACKNOWLEDGMENTS

This grassland workflow adapts the Blue Carbon MMRV Workflow for Canadian prairie ecosystems, integrating best practices from:
- Verra VM0026/VM0032/VM0042 methodologies
- Alberta TIER offset protocols
- Canadian Agricultural GHG methodology
- Canadian Federation of Agriculture
- Climate Action Reserve
- ALUS (Alternative Land Use Services)

Developed to support transparent, science-based grassland carbon verification in Canada's prairie provinces (Alberta, Saskatchewan, Manitoba).

---

**🌾 Ready to quantify grassland carbon? Start with the grassland configuration file!**
