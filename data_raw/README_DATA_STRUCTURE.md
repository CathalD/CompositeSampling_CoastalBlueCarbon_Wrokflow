# Blue Carbon Data Structure

## Required CSV Files

### 1. core_locations.csv

**Required columns:**
- `core_id` (character): Unique identifier for each core (e.g., "HR_001", "COMP_001", "BASE_HR_001")
- `longitude` (numeric): Longitude in decimal degrees (WGS84)
- `latitude` (numeric): Latitude in decimal degrees (WGS84)
- `stratum` (character): Ecosystem type - must match one of:
  - "Upper Marsh"
  - "Mid Marsh"
  - "Lower Marsh"
  - "Underwater Vegetation"
  - "Open Water"
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

**Optional columns:**
- `site_name`: Name of sampling site
- `sampling_date`: Date of core collection (YYYY-MM-DD)
- `sampler`: Person/team who collected core
- `notes`: Any additional notes

---

### 2. core_samples.csv

**Required columns:**
- `core_id` (character): Must match core_id in core_locations.csv
- `depth_top_cm` (numeric): Top depth of sample interval in cm (e.g., 0, 5, 15)
- `depth_bottom_cm` (numeric): Bottom depth of sample interval in cm (e.g., 5, 10, 30)
- `soc_g_kg` (numeric): Soil organic carbon content in g/kg (0-500 typical range)

**Highly recommended columns:**
- `bulk_density_g_cm3` (numeric): Dry bulk density in g/cm³ (0.1-3.0 typical range)
  - If missing, stratum-specific defaults will be used (see config)
  - VM0033 recommends measuring BD for all cores

**Optional columns:**
- `total_carbon_pct`: Total carbon percentage
- `total_nitrogen_pct`: Total nitrogen percentage
- `c_n_ratio`: Carbon to nitrogen ratio
- `sample_notes`: Any notes about the sample

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
