# Carbon Assessment Data Structure
## For Both Coastal Blue Carbon and Canadian Grassland Workflows

---

## 🎯 CHOOSE YOUR WORKFLOW

This repository supports **TWO** workflows with similar but ecosystem-specific data requirements:

- **🌊 COASTAL BLUE CARBON:** See sections marked with 🌊
- **🌾 CANADIAN GRASSLAND:** See sections marked with 🌾

Both workflows use the same two CSV files (`core_locations.csv` and `core_samples.csv`), but with different required fields.

---

## Required CSV Files (BOTH WORKFLOWS)

### 1. core_locations.csv

**Required columns (ALL workflows):**
- `core_id` (character): Unique identifier for each core (e.g., "HR_001", "COMP_001", "GRASS_001")
- `longitude` (numeric): Longitude in decimal degrees (WGS84)
- `latitude` (numeric): Latitude in decimal degrees (WGS84)
- `stratum` (character): Ecosystem type - **ECOSYSTEM-SPECIFIC:**

**🌊 COASTAL BLUE CARBON strata:**
  - "Upper Marsh"
  - "Mid Marsh"
  - "Lower Marsh"
  - "Underwater Vegetation"
  - "Open Water"

**🌾 CANADIAN GRASSLAND strata:**
  - "Fescue Prairie"
  - "Mixed-Grass Prairie"
  - "Aspen Parkland"
  - "Improved Pasture"
  - "Degraded Grassland"
- `core_type` (character): Type of core - must be one of:
  - **"HR"**: High resolution core (fine depth intervals, e.g., 0-5, 5-10, 10-15 cm)
  - **"Paired Composite"**: Composite core with a corresponding HR core at same location
  - **"Unpaired Composite"**: Standalone composite core (coarse depth intervals, e.g., 0-15, 15-30 cm)
- `paired_with` (character): For paired cores, the core_id of the matching core; "NA" for unpaired
- `scenario_type` (character): VM0033 scenario - must be one of:
  - "PROJECT": Project scenario (with intervention)
  - "BASELINE": Baseline scenario (without intervention)
  - "CONTROL": Control area
  - "DEGRADED": Degraded reference area
- `monitoring_year` (integer): Year of sampling (e.g., 2024)

**Optional columns (BOTH workflows):**
- `site_name`: Name of sampling site
- `sampling_date`: Date of core collection (YYYY-MM-DD)
- `sampler`: Person/team who collected core
- `notes`: Any additional notes

**🌾 GRASSLAND-SPECIFIC REQUIRED FIELDS:**

For Canadian grassland carbon workflow, **ADD these additional columns**:

- `grazing_history` (character): Grazing intensity - must be one of:
  - "None" (never grazed or >20 years since grazing)
  - "Light" (low stocking rate, rotational)
  - "Moderate" (typical ranch stocking)
  - "Heavy" (high stocking rate)
  - "Severe" (overgrazed, significant degradation)
  - OR specify years since last grazing (e.g., "10 years")

- `fire_history` (character): Fire regime - must be one of:
  - "None" (no recorded fire)
  - ">20 years" (long time since fire)
  - "10 years" (specific years since fire)
  - "Prescribed annual" (managed fire regime)
  - OR number of years since last fire

- `grass_type` (character): Grassland composition - must be one of:
  - "Native" (native prairie species)
  - "Seeded" (introduced, seeded species)
  - "Mixed" (mix of native and seeded)
  - "Invasive" (dominated by invasive species)

- `land_use` (character): Current land use - examples:
  - "Rangeland" (extensive grazing)
  - "Pasture" (improved pasture)
  - "Hayland" (hay production)
  - "Conservation" (protected, no grazing)
  - "Cropland (former)" (converted from cropland)

- `ecoregion` (character): Canadian prairie ecoregion (optional but recommended):
  - "Fescue Grasslands"
  - "Mixed Grasslands"
  - "Moist Mixed Grasslands"
  - "Aspen Parkland"
  - "Cypress Upland"
  - "Northern Fescue"

**Example grassland core_locations.csv:**
```csv
core_id,longitude,latitude,stratum,core_type,scenario_type,monitoring_year,grazing_history,fire_history,grass_type,land_use,ecoregion
GRASS_001,-110.5,50.2,Fescue Prairie,composite,PROJECT,2024,Moderate,10 years,Native,Rangeland,Fescue Grasslands
GRASS_002,-105.8,49.8,Mixed-Grass Prairie,composite,PROJECT,2024,Heavy,>20 years,Native,Rangeland,Mixed Grasslands
GRASS_003,-112.1,51.5,Aspen Parkland,composite,BASELINE,2024,Light,None,Mixed,Conservation,Aspen Parkland
GRASS_004,-108.3,50.5,Improved Pasture,composite,PROJECT,2024,Moderate,None,Seeded,Pasture,Mixed Grasslands
GRASS_005,-106.7,49.3,Degraded Grassland,composite,DEGRADED,2024,Severe,None,Invasive,Rangeland,Mixed Grasslands
```

---

### 2. core_samples.csv

**Required columns (ALL workflows):**
- `core_id` (character): Must match core_id in core_locations.csv
- `depth_top_cm` (numeric): Top depth of sample interval in cm (e.g., 0, 5, 15)
- `depth_bottom_cm` (numeric): Bottom depth of sample interval in cm (e.g., 5, 10, 30)
- `soc_g_kg` (numeric): Soil organic carbon content in g/kg
  - 🌊 **Coastal:** 0-500 g/kg typical range (high organic content)
  - 🌾 **Grassland:** 0-150 g/kg typical range (20-100 g/kg in topsoil)

**Highly recommended columns:**
- `bulk_density_g_cm3` (numeric): Dry bulk density in g/cm³
  - 🌊 **Coastal:** 0.6-1.2 g/cm³ typical range (organic-rich)
  - 🌾 **Grassland:** 1.0-1.4 g/cm³ typical range (mineral soils)
  - If missing, stratum-specific defaults will be used (see config)
  - AAFC/VM0033 recommends measuring BD for all cores

**Optional columns (BOTH workflows):**
- `total_carbon_pct`: Total carbon percentage
- `total_nitrogen_pct`: Total nitrogen percentage
- `c_n_ratio`: Carbon to nitrogen ratio
- `sample_notes`: Any notes about the sample

**🌾 GRASSLAND-SPECIFIC OPTIONAL FIELD:**
- `root_biomass_g_m2` (numeric): Root biomass in g/m² if measured
  - Most grassland root biomass in top 30 cm
  - Useful for validating carbon accumulation patterns
  - Typical range: 200-2000 g/m² depending on depth

**Example grassland core_samples.csv:**
```csv
core_id,depth_top_cm,depth_bottom_cm,soc_g_kg,bulk_density_g_cm3,root_biomass_g_m2
GRASS_001,0,10,65.3,1.05,850
GRASS_001,10,30,42.1,1.15,320
GRASS_001,30,50,28.5,1.25,150
GRASS_001,50,100,18.2,1.30,80
```

---

## Core Type Definitions

### High Resolution (HR) Cores
- **Purpose**: Detailed depth profiles for understanding carbon distribution
- **Depth intervals**: Fine increments (typically 0-5, 5-10, 10-15, 15-20, 20-25, 25-30, 30-40, 40-50, 50-75, 75-100 cm)
- **Use case**: Provides detailed carbon stock profile
- **VM0033**: Can be used alone or paired with composites for uncertainty reduction

### Paired Composite Cores
- **Purpose**: Cost-effective sampling that can be validated against HR cores
- **Depth intervals**: Coarse increments matching VM0033 intervals (0-15, 15-30, 30-50, 50-100 cm)
- **Location**: Collected at same location as HR core (within 1-2m)
- **Use case**: If statistically similar to HR cores, composites can be used across larger area
- **Pairing**: Use `paired_with` field to link to HR core_id

### Unpaired Composite Cores
- **Purpose**: Standalone samples covering VM0033 depth intervals
- **Depth intervals**: Same as paired composites (0-15, 15-30, 30-50, 50-100 cm)
- **Location**: Independent locations not paired with HR cores
- **Use case**: Standard VM0033 sampling when HR cores not needed

---

## Statistical Analysis

The data prep script (`01_data_prep_bluecarbon.R`) will automatically:

1. **Compare HR vs Paired Composites**: Two-sample t-tests by stratum
   - If p ≥ 0.05: No significant difference → paired sampling assumption supported
   - If p < 0.05: Significant difference → analyze HR and composites separately

2. **Uncertainty Quantification**:
   - Paired cores reduce uncertainty vs unpaired cores
   - HR cores provide more detailed profiles than composites
   - Measured BD reduces uncertainty vs estimated BD

3. **VM0033 Compliance**:
   - Minimum 3 cores per stratum
   - Target precision: ≤20% relative error at 95% CI
   - Recommended: mix of HR and composite for validation

---

## Example Naming Convention

### PROJECT Scenario
- HR cores: `HR_001`, `HR_002`, `HR_003`, ...
- Paired composites: `COMP_001`, `COMP_002`, `COMP_003`, ... (same numbers as HR)
- Unpaired composites: `COMP_101`, `COMP_102`, `COMP_103`, ...

### BASELINE Scenario
- HR cores: `BASE_HR_001`, `BASE_HR_002`, ...
- Paired composites: `BASE_COMP_001`, `BASE_COMP_002`, ...
- Unpaired composites: `BASE_COMP_101`, `BASE_COMP_102`, ...

---

## Quality Control

### Before data collection:
1. Plan paired sampling locations (HR + Composite at same spot)
2. Ensure unpaired composites are well-distributed across strata
3. Aim for ≥3 cores per stratum minimum (VM0033 requirement)

### During data collection:
1. Record GPS coordinates accurately
2. Measure bulk density when possible (reduces uncertainty)
3. Note any issues in sample_notes field
4. Keep paired cores truly paired (<2m apart)

### After data processing:
1. Review VM0033 compliance report
2. Check HR vs Composite statistical tests
3. Evaluate bulk density transparency report
4. Assess depth profile completeness

---

## Template Files

See `core_locations_TEMPLATE.csv` and `core_samples_TEMPLATE.csv` for example data structure.

To use:
1. Copy templates to `core_locations.csv` and `core_samples.csv`
2. Replace example data with your actual field data
3. Ensure column names match exactly (case-sensitive)
4. Run `source("01_data_prep_bluecarbon.R")`
