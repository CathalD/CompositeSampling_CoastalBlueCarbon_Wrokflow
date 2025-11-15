# BAYESIAN WORKFLOW GUIDE (Part 4 - Optional)
## Blue Carbon Monitoring - VM0033 Compliant

**Purpose**: Combine prior knowledge (GEE global datasets) with field data for improved carbon stock estimates with reduced uncertainty.

**Theory**: Bayesian updating combines prior knowledge with field observations:
- **Prior**: Global/regional datasets (SoilGrids, Sothe et al. 2022)
- **Likelihood**: Field-based predictions (RF/Kriging from Modules 04/05)
- **Posterior**: Precision-weighted combination (best of both worlds)

---

## WORKFLOW OVERVIEW

```
┌─────────────────────────────────────────────────────────────────┐
│                    BAYESIAN WORKFLOW (Part 4)                   │
└─────────────────────────────────────────────────────────────────┘

 GEE EXPORT                MODULE 00C              MODULE 01C
┌──────────┐             ┌──────────┐            ┌──────────┐
│ Export   │             │ Process  │            │ Neyman   │
│ Priors   │────────────▶│ Priors   │───────────▶│ Sampling │
│ from GEE │             │          │            │ Design   │
└──────────┘             └──────────┘            └──────────┘
                                                       │
                                                       ▼
                                              [Field Sampling]
                                                       │
                                                       ▼
                                              Modules 01-05
                                              (Standard Workflow)
                                                       │
                                                       ▼
                                              MODULE 06C
                                             ┌──────────┐
                                             │Posterior │
                                             │Estimation│
                                             └──────────┘
                                                  │
                                                  ▼
                                            Module 06 & 07
                                          (Carbon Stocks & MMRV)
```

---

## STEP 0: ENABLE BAYESIAN WORKFLOW

### Edit Configuration
**File**: `blue_carbon_config.R`

```r
# Enable Bayesian workflow
USE_BAYESIAN <- TRUE

# Enable Neyman optimal sampling
USE_NEYMAN_SAMPLING <- TRUE

# Uncertainty strata thresholds (CV %)
UNCERTAINTY_LOW_THRESHOLD <- 10    # CV < 10% = low uncertainty
UNCERTAINTY_HIGH_THRESHOLD <- 30   # CV > 30% = high uncertainty

# Bayesian weighting method
BAYESIAN_WEIGHT_METHOD <- "sqrt_samples"  # Options: "sqrt_samples", "linear", "fixed"
BAYESIAN_TARGET_SAMPLES <- 30             # Target sample size for full field weight

# Prior uncertainty inflation (conservative approach)
PRIOR_UNCERTAINTY_INFLATION <- 1.2  # Multiply prior SE by 1.2
```

---

## STEP 1: EXPORT PRIORS FROM GOOGLE EARTH ENGINE

### File: `GEE_EXPORT_BAYESIAN_PRIORS.js`

> **IMPORTANT**: The GEE script exports **carbon stocks (kg/m²)**, not SOC (g/kg).
> The Bayesian workflow expects carbon stock priors to match the units used in Modules 03-06.

**Data Sources and Strategy**:
1. **SoilGrids 250m** (Poggio et al. 2021) - **Global baseline for depth patterns**
   - Global soil organic carbon dataset at 250m resolution
   - Provides depth-specific layers (0-5, 5-15, 15-30, 30-60, 60-100 cm)
   - Used to calculate carbon stocks for all VM0033 depth intervals
   - Provides the depth distribution pattern (how carbon varies with depth)

2. **Sothe et al. 2022** - **BC Coast regional refinement (total 0-100cm)**
   - Regional soil carbon dataset for British Columbia coast
   - Provides total carbon to 1m depth (0-100cm) in kg/m² with uncertainty
   - **Blended with SoilGrids 0-100cm total (sum of all 4 intervals)**
   - Blending method: Precision-weighted average of totals, then proportional scaling

**How Blending Works**:
1. Calculate 4 depth intervals from SoilGrids: 0-15, 15-30, 30-50, 50-100 cm
2. Sum all 4 intervals → SoilGrids total 0-100cm
3. Blend: (SoilGrids total) + (Sothe et al. total) using precision weights
4. Calculate scaling factor = Blended_total / SoilGrids_original_total
5. Apply scaling factor to **ALL 4 depth intervals** proportionally
6. Result: Regional accuracy from Sothe + depth pattern from SoilGrids

**Why This Strategy?**
- SoilGrids provides reliable depth distribution patterns globally
- Sothe et al. provides higher regional accuracy for BC Coast total stocks
- Blending totals and scaling preserves depth patterns while adding regional accuracy
- All depths benefit from regional refinement, not just one layer
- Precision-weighting ensures the most reliable data source has more influence

### Instructions:

1. **Open Google Earth Engine Code Editor**
   - Go to: https://code.earthengine.google.com/

2. **Define Study Area**
   ```javascript
   // Option 1: Draw polygon manually
   // Option 2: Import shapefile from Assets
   // Option 3: Use coordinates
   var studyArea = ee.Geometry.Rectangle([-123.5, 49.0, -123.0, 49.3]);
   ```

3. **Set Export Parameters**
   ```javascript
   var EXPORT_SCALE = 250;  // Resolution in meters
   var EXPORT_CRS = 'EPSG:3005';  // BC Albers
   var EXPORT_FOLDER = 'BlueCarbon_Priors';  // Google Drive folder
   ```

4. **Update Asset Paths** for Sothe et al. 2022 BC Coast data:
   ```javascript
   // Required for blending with 50-100cm depth:
   var SOTHE_SOIL_CARBON = 'projects/northstarlabs/assets/McMasterWWFCanadasoilcarbon1m250mkgm2version3';
   var SOTHE_SOIL_CARBON_UNCERTAINTY = 'projects/northstarlabs/assets/McMasterWWFCanadasoilcarbon1muncertainty250mkgm2version30';

   // Optional (not used for priors):
   var SOTHE_FOREST_BIOMASS = 'projects/sat-io/open-datasets/carbon_stocks_ca/forest_carbon_2019';
   ```

5. **Understand the Blending Process**:

   The script will:
   - **Step 1**: Calculate carbon stocks from SoilGrids for all 4 VM0033 depth intervals
     - 0-15cm (7.5cm midpoint), 15-30cm (22.5cm), 30-50cm (40cm), 50-100cm (75cm)
   - **Step 2**: Sum all 4 SoilGrids intervals to get total 0-100cm stock
     - Total_SG = 0-15cm + 15-30cm + 30-50cm + 50-100cm
   - **Step 3**: Blend the two 0-100cm totals using precision-weighted average:
     - `w_SG = 1/SE_SG²`, `w_Sothe = 1/SE_Sothe²`
     - `Blended_total = (w_SG × Total_SG + w_Sothe × Total_Sothe) / (w_SG + w_Sothe)`
     - `Blended_SE = sqrt(1 / (w_SG + w_Sothe))`
   - **Step 4**: Calculate scaling factor
     - `Scaling = Blended_total / Original_SG_total`
   - **Step 5**: Apply scaling to ALL 4 depth intervals proportionally
     - Each interval gets multiplied by the same scaling factor
     - Preserves SoilGrids depth pattern, adds Sothe regional accuracy

6. **Run Script**
   - Click "Run" button
   - Check console for blending confirmation
   - Wait for Tasks to appear in Tasks tab

7. **Export All Tasks**
   - Go to Tasks tab (top right)
   - Click "RUN" for each task (~13 tasks)
   - Files will export to Google Drive

### Expected GEE Exports:

**Required Files for Bayesian Workflow** (8 files total):

**Prior Mean Files** (4 files - carbon stocks in kg/m²):
- `carbon_stock_prior_mean_7.5cm.tif` ← SoilGrids pattern × Regional scaling
- `carbon_stock_prior_mean_22.5cm.tif` ← SoilGrids pattern × Regional scaling
- `carbon_stock_prior_mean_40cm.tif` ← SoilGrids pattern × Regional scaling
- `carbon_stock_prior_mean_75cm.tif` ← SoilGrids pattern × Regional scaling

**Prior Uncertainty Files** (4 files - carbon stocks in kg/m²):
- `carbon_stock_prior_se_7.5cm.tif` ← Scaled uncertainty
- `carbon_stock_prior_se_22.5cm.tif` ← Scaled uncertainty
- `carbon_stock_prior_se_40cm.tif` ← Scaled uncertainty
- `carbon_stock_prior_se_75cm.tif` ← Scaled uncertainty

> **Note**: When Sothe et al. data is available, ALL 4 depth intervals are adjusted by the same
> regional scaling factor. The scaling factor is calculated by blending the 0-100cm totals from
> SoilGrids and Sothe et al., then applied proportionally to preserve depth patterns.

**Optional Files for Diagnostics**:
- `carbon_stock_prior_cv_7.5cm.tif` - Coefficient of variation (%)
- `carbon_stock_prior_cv_22.5cm.tif`
- `carbon_stock_prior_cv_40cm.tif`
- `carbon_stock_prior_cv_75cm.tif`
- `uncertainty_strata.tif` - For Neyman sampling visualization

### Download from Google Drive:

1. Go to Google Drive
2. Find folder: `BlueCarbon_Priors/`
3. Download all `.tif` files
4. Place in: `data_prior/gee_exports/`

**Directory Structure**:
```
CompositeSampling_CoastalBlueCarbon_Wrokflow/
├── data_prior/
│   └── gee_exports/
│       ├── carbon_stock_prior_mean_7.5cm.tif
│       ├── carbon_stock_prior_mean_22.5cm.tif
│       ├── carbon_stock_prior_mean_40cm.tif
│       ├── carbon_stock_prior_mean_75cm.tif
│       ├── carbon_stock_prior_se_7.5cm.tif
│       ├── carbon_stock_prior_se_22.5cm.tif
│       ├── carbon_stock_prior_se_40cm.tif
│       ├── carbon_stock_prior_se_75cm.tif
│       └── uncertainty_strata.tif (optional)
```

---

## STEP 2: MODULE 00C - PROCESS BAYESIAN PRIORS

### File: `00c_bayesian_prior_setup_bluecarbon.R`

**Purpose**: Process and align GEE-exported priors to study area

**Important**: This module expects files already named `carbon_stock_prior_mean_*.tif` and `carbon_stock_prior_se_*.tif` from the GEE export script. If Sothe et al. data was available, ALL 4 depth files contain regionally-scaled values (not just the deepest layer).

### Prerequisites:
- ✓ GEE exports downloaded to `data_prior/gee_exports/`
- ✓ Files correctly named: `carbon_stock_prior_mean_7.5cm.tif`, etc.
- ✓ `USE_BAYESIAN = TRUE` in config
- ✓ Study area boundary (optional): `data_raw/study_area_boundary.shp`

### Run Module:
```r
source("00c_bayesian_prior_setup_bluecarbon.R")
```

### What It Does:
1. Loads GEE-exported prior maps (already in carbon stocks kg/m²)
2. Reprojects to EPSG:3005 (BC Albers) if needed
3. Clips to study area boundary (if provided)
4. Aligns all rasters to common grid
5. Inflates uncertainty by `PRIOR_UNCERTAINTY_INFLATION` factor (conservative)
6. Creates metadata CSV documenting data sources

### Inputs:
```
data_prior/gee_exports/
├── carbon_stock_prior_mean_*.tif (from GEE - carbon stocks kg/m²)
├── carbon_stock_prior_se_*.tif (from GEE - carbon stocks kg/m²)
└── uncertainty_strata.tif (optional, from GEE)
```

### Outputs:
```
data_prior/
├── carbon_stock_prior_mean_7.5cm.tif     ← Regionally-scaled if Sothe available (kg/m²)
├── carbon_stock_prior_mean_22.5cm.tif    ← Regionally-scaled if Sothe available (kg/m²)
├── carbon_stock_prior_mean_40cm.tif      ← Regionally-scaled if Sothe available (kg/m²)
├── carbon_stock_prior_mean_75cm.tif      ← Regionally-scaled if Sothe available (kg/m²)
├── carbon_stock_prior_se_7.5cm.tif       ← Scaled uncertainty (kg/m²)
├── carbon_stock_prior_se_22.5cm.tif      ← Scaled uncertainty (kg/m²)
├── carbon_stock_prior_se_40cm.tif        ← Scaled uncertainty (kg/m²)
├── carbon_stock_prior_se_75cm.tif        ← Scaled uncertainty (kg/m²)
├── uncertainty_strata.tif       ← Uncertainty strata (1=low, 2=med, 3=high)
├── prior_metadata.csv           ← Source info and statistics
└── prior_depth_summary.csv      ← Depth-specific summary statistics
```

### Expected Output:
```
=== MODULE 00C: BAYESIAN PRIOR SETUP ===
Project: Chemainus Estuary Blue Carbon
Bayesian workflow enabled ✓

Checking for GEE exported files...
Found 4 prior mean files:
  - carbon_stock_prior_mean_7.5cm.tif
  - carbon_stock_prior_mean_22.5cm.tif
  - carbon_stock_prior_mean_40cm.tif
  - carbon_stock_prior_mean_75cm.tif

Processing prior maps for VM0033 standard depths...
  Processing depth: 7.5 cm
    Loaded mean: carbon_stock_prior_mean_7.5cm.tif
    Loaded SE: carbon_stock_prior_se_7.5cm.tif
    Reprojected to EPSG:3005
    Clipped to study area
    Saved: data_prior/carbon_stock_prior_mean_7.5cm.tif

Prior processing complete!
Created metadata file: data_prior/prior_metadata.csv
```

---

## STEP 3: MODULE 01C - BAYESIAN SAMPLING DESIGN

### File: `01c_bayesian_sampling_design_bluecarbon.R`

**Purpose**: Design optimal sampling using **Neyman allocation**

**Theory**: Allocate more samples to high-uncertainty areas
```
n_h ∝ N_h × σ_h

Where:
- n_h = samples allocated to stratum h
- N_h = area of stratum h (ha)
- σ_h = standard deviation in stratum h (from priors)
```

### Prerequisites:
- ✓ Module 00C completed (priors processed)
- ✓ `USE_NEYMAN_SAMPLING = TRUE` in config

### Run Module:
```r
source("01c_bayesian_sampling_design_bluecarbon.R")
```

### What It Does:
1. Loads processed priors from Module 00C
2. Calculates coefficient of variation (CV = SE/mean × 100)
3. Creates uncertainty strata based on CV thresholds:
   - Stratum 1: CV < 10% (low uncertainty)
   - Stratum 2: 10% ≤ CV < 30% (medium uncertainty)
   - Stratum 3: CV ≥ 30% (high uncertainty)
4. Applies Neyman allocation formula
5. Generates spatially balanced sample points (SSP)
6. Creates field-ready sampling locations CSV

### Inputs:
```
data_prior/
├── carbon_stock_prior_mean_7.5cm.tif (from Module 00C)
├── carbon_stock_prior_se_7.5cm.tif (from Module 00C)
└── uncertainty_strata.tif (optional)
```

### Outputs:
```
├── sampling_locations_neyman.csv        ← GPS coordinates for field sampling
├── sampling_allocation_neyman.csv       ← Samples per stratum
├── sampling_map_neyman.png             ← Map visualization
└── data_processed/neyman_strata.tif    ← Uncertainty strata raster
```

### Example Output - `sampling_allocation_neyman.csv`:
```csv
stratum,description,area_ha,mean_cv_pct,neyman_allocation,buffer_allocation,locations_generated
1,Low Uncertainty,45.2,7.3,8,10,10
2,Medium Uncertainty,102.5,18.5,22,27,27
3,High Uncertainty,67.8,42.1,20,24,24
ALL,Total Study Area,215.5,23.1,50,61,61
```

### Example Output - `sampling_locations_neyman.csv`:
```csv
point_id,stratum,longitude,latitude,utm_east,utm_north,accessibility_notes
NEYM_001,3,-123.4567,49.1234,512345,5445678,High uncertainty area - priority
NEYM_002,2,-123.4523,49.1298,512456,5446123,Medium uncertainty
NEYM_003,3,-123.4489,49.1156,512567,5445234,High uncertainty area - priority
...
```

**Field Use**: Take `sampling_locations_neyman.csv` to the field with a GPS device.

---

## STEP 4: STANDARD WORKFLOW (MODULES 01-05)

**After completing Neyman sampling design**, proceed with standard workflow:

1. **Module 01**: Import field data collected at Neyman-allocated locations
2. **Module 02**: QA/QC field data
3. **Module 03**: Depth harmonization (SOC, BD, carbon stocks)
4. **Module 04**: Kriging predictions (optional)
5. **Module 05**: Random Forest predictions (likelihood maps)

**Note**: These modules run exactly as before - the Neyman allocation just optimizes WHERE you sample, not how you process the data.

---

## STEP 5: MODULE 06C - BAYESIAN POSTERIOR ESTIMATION

### File: `06c_bayesian_posterior_estimation_bluecarbon.R`

**Purpose**: Combine priors with field data to generate posterior estimates

**Theory**: Precision-weighted Bayesian update
```
Precision (τ) = 1 / variance (σ²)

μ_posterior = (τ_prior × μ_prior + τ_field × μ_field) / (τ_prior + τ_field)
σ²_posterior = 1 / (τ_prior + τ_field)

Result: Lower uncertainty than either prior or field data alone!
```

### Prerequisites:
- ✓ Module 00C completed (priors)
- ✓ Modules 01-05 completed (field data + predictions)
- ✓ `USE_BAYESIAN = TRUE` in config

### Run Module:
```r
source("06c_bayesian_posterior_estimation_bluecarbon.R")
```

### What It Does:
1. Loads prior maps from Module 00C
2. Loads likelihood maps (RF or Kriging) from Module 05
3. Calculates sample density field (nearby samples = higher field weight)
4. Applies precision-weighted Bayesian update
5. Generates posterior mean and SE maps
6. Calculates information gain (uncertainty reduction)
7. Creates comparative visualizations

### Inputs:
```
data_prior/
├── carbon_stock_prior_mean_*.tif (from Module 00C)
└── carbon_stock_prior_se_*.tif (from Module 00C)

outputs/predictions/rf/
├── carbon_stock_rf_*cm.tif (from Module 05)
└── se_combined_*cm.tif (from Module 05)

OR

outputs/predictions/kriging/
├── carbon_stock_*.tif (from Module 04)
└── se_combined_*.tif (from Module 04)
```

### Outputs:
```
outputs/predictions/posterior/
├── carbon_stock_posterior_mean_7.5cm.tif        ← Posterior mean (kg/m²)
├── carbon_stock_posterior_mean_22.5cm.tif
├── carbon_stock_posterior_mean_40cm.tif
├── carbon_stock_posterior_mean_75cm.tif
├── carbon_stock_posterior_se_7.5cm.tif          ← Posterior SE (kg/m²)
├── carbon_stock_posterior_se_22.5cm.tif
├── carbon_stock_posterior_se_40cm.tif
├── carbon_stock_posterior_se_75cm.tif
└── carbon_stock_posterior_conservative_*.tif    ← Conservative (lower 95% CI)

diagnostics/bayesian/
├── information_gain_7.5cm.tif          ← Uncertainty reduction map
├── information_gain_22.5cm.tif
├── information_gain_40cm.tif
├── information_gain_75cm.tif
├── uncertainty_reduction.csv           ← Summary statistics
└── prior_likelihood_posterior_comparison.png  ← Visual comparison
```

### Expected Console Output:
```
=== MODULE 06C: BAYESIAN POSTERIOR ESTIMATION ===
Project: Chemainus Estuary Blue Carbon
Bayesian posterior estimation enabled ✓

Loading field sample locations...
Loaded 61 sample locations

Checking for likelihood maps...
Using RF for likelihood

Loading Bayesian priors...
Found 4 prior depth layers

Processing depth: 7.5 cm
  Prior mean: 45.2 kg/m², SE: 8.3 kg/m²
  Field mean: 52.1 kg/m², SE: 6.1 kg/m²
  Posterior mean: 49.8 kg/m², SE: 4.9 kg/m²
  ✓ Uncertainty reduced by 40.7%

Processing depth: 22.5 cm
  Prior mean: 38.7 kg/m², SE: 7.1 kg/m²
  Field mean: 44.3 kg/m², SE: 5.8 kg/m²
  Posterior mean: 42.1 kg/m², SE: 4.5 kg/m²
  ✓ Uncertainty reduced by 36.6%

Bayesian posterior estimation complete!
Saved posterior maps: outputs/predictions/posterior/
```

### Key Metrics - `uncertainty_reduction.csv`:
```csv
depth_cm,prior_mean,prior_se,field_mean,field_se,posterior_mean,posterior_se,uncertainty_reduction_pct,information_gain
7.5,45.2,8.3,52.1,6.1,49.8,4.9,40.7,High
22.5,38.7,7.1,44.3,5.8,42.1,4.5,36.6,High
40,31.2,6.8,36.5,7.2,33.9,4.8,29.4,Medium
75,22.1,5.9,24.8,8.1,23.2,4.7,20.3,Medium
```

**Interpretation**:
- **High information gain**: Prior + field data combined well (>30% uncertainty reduction)
- **Medium information gain**: Moderate improvement (20-30% reduction)
- **Low information gain**: Prior not very informative (<20% reduction)

---

## STEP 6: CONTINUE WITH STANDARD MODULES

After Module 06C, use posterior maps in place of RF/Kriging predictions:

### Module 06: Carbon Stock Calculation
- Modify to use `outputs/predictions/posterior/` instead of RF/Kriging
- Aggregate posterior maps to VM0033 intervals
- Calculate conservative estimates

### Module 07: MMRV Reporting
- Generate VM0033 verification package
- Include Bayesian methodology in documentation
- Report uncertainty reduction as quality metric

---

## BAYESIAN WORKFLOW SUMMARY

### Required Files Checklist:

**From Google Earth Engine**:
- [ ] `carbon_stock_prior_mean_7.5cm.tif`
- [ ] `carbon_stock_prior_mean_22.5cm.tif`
- [ ] `carbon_stock_prior_mean_40cm.tif`
- [ ] `carbon_stock_prior_mean_75cm.tif`
- [ ] `carbon_stock_prior_se_7.5cm.tif`
- [ ] `carbon_stock_prior_se_22.5cm.tif`
- [ ] `carbon_stock_prior_se_40cm.tif`
- [ ] `carbon_stock_prior_se_75cm.tif`
- [ ] `uncertainty_strata.tif` (optional)

**From Standard Workflow**:
- [ ] Field data (Modules 01-03)
- [ ] RF or Kriging predictions (Modules 04-05)
- [ ] Study area boundary (optional)

### Expected Benefits:

1. **Optimized Sampling** (Module 01C):
   - Target high-uncertainty areas
   - Reduce field costs
   - Maximize information per sample

2. **Improved Estimates** (Module 06C):
   - Lower uncertainty than field data alone
   - Spatially complete coverage (no gaps)
   - Better predictions in under-sampled areas

3. **VM0033 Compliance**:
   - Conservative estimates (lower 95% CI)
   - Documented methodology
   - Quantified uncertainty reduction

### When to Use Bayesian Workflow:

**✓ Use Bayesian When**:
- Prior data available and reasonably accurate
- Limited field sampling budget
- Need to optimize sample allocation
- Want to reduce uncertainty
- Study area partially inaccessible

**✗ Skip Bayesian When**:
- No reliable prior data exists
- Prior data known to be biased/inaccurate
- Sufficient field samples for good coverage
- Simple study area with homogeneous conditions

---

## TROUBLESHOOTING

### Issue: "No prior files found in data_prior/gee_exports/"
**Solution**:
1. Ensure GEE exports completed
2. Downloaded all .tif files from Google Drive
3. Placed in correct directory: `data_prior/gee_exports/`

### Issue: "Bayesian workflow is disabled"
**Solution**: Edit `blue_carbon_config.R`:
```r
USE_BAYESIAN <- TRUE
```

### Issue: "Prior and field data don't align"
**Solution**: Module 00C automatically reprojects and aligns. Check:
1. CRS settings in config (PROCESSING_CRS)
2. Study area boundary matches field extent

### Issue: "Information gain is low (<20%)"
**Possible Causes**:
1. Prior data inaccurate for your region
2. Prior uncertainty underestimated
3. Field data uncertainty is very low
**Solution**: Increase `PRIOR_UNCERTAINTY_INFLATION` in config

### Issue: "Posterior estimates seem wrong"
**Check**:
1. Prior units (should be kg/m² for carbon stocks)
2. Field prediction units match prior units (kg/m²)
3. Sample density calculation working correctly
4. Weighting method appropriate (`BAYESIAN_WEIGHT_METHOD`)
5. GEE export script updated to export carbon stocks (not SOC)

---

## REFERENCES

**Data Sources**:
- **Poggio, L., et al. (2021)**. SoilGrids 2.0: producing soil information for the globe with quantified spatial uncertainty. *Soil*, 7, 217-240.
  - Global dataset at 250m resolution
  - Soil organic carbon (SOC) and bulk density at multiple depths
  - Used as baseline for all VM0033 depth intervals
  - Access: Google Earth Engine (`projects/soilgrids-isric/`)

- **Sothe, C., et al. (2022)**. Large soil carbon storage in terrestrial ecosystems of Canada. *Global Biogeochemical Cycles*, 36(4), e2021GB007213.
  - Regional dataset for Canada at 250m resolution
  - Total soil carbon to 1m depth (0-100cm) with uncertainty estimates
  - Blended with SoilGrids 0-100cm total using precision-weighted average
  - Scaling factor applied proportionally to all depth intervals
  - Access: Google Earth Engine (`projects/northstarlabs/assets/`)

**Methodology**:
- Neyman, J. (1934). On the two different aspects of the representative method. *Journal of the Royal Statistical Society*, 97(4), 558-625.
- Gelman, A., et al. (2013). *Bayesian Data Analysis*. CRC Press.

**VM0033 Standard**:
- Verra. (2015). VM0033 Methodology for Tidal Wetland and Seagrass Restoration. Version 2.0.

---

## QUICK COMMAND SEQUENCE

```r
# 1. Configure
source("blue_carbon_config.R")
# Set USE_BAYESIAN <- TRUE

# 2. Process priors (after GEE export)
source("00c_bayesian_prior_setup_bluecarbon.R")

# 3. Design sampling
source("01c_bayesian_sampling_design_bluecarbon.R")

# 4. Standard workflow with field data
source("01_import_field_data.R")
source("02_qaqc_field_data.R")
source("03_depth_harmonization_bluecarbon.R")
source("04_raster_predictions_kriging_bluecarbon.R")  # or skip
source("05_raster_predictions_rf_bluecarbon.R")

# 5. Bayesian posterior
source("06c_bayesian_posterior_estimation_bluecarbon.R")

# 6. Continue standard workflow
source("06_carbon_stock_calculation_bluecarbon.R")  # may need modification
source("07_mmrv_reporting_bluecarbon.R")
```

---

**End of Bayesian Workflow Guide**

For questions or issues, refer to module-specific comments or consult the VM0033 methodology documentation.
