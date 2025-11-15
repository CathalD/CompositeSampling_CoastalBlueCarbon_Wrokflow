# Temporal Analysis & Scenario Modeling Guide

## Overview

The temporal analysis modules (08, 09, 10) enable comparison of carbon stocks across different scenarios (BASELINE vs PROJECT) and time periods. These modules are essential for demonstrating **additionality** - the carbon stock gains attributable to restoration projects.

**Key VM0033 Update:** All temporal modules now track **4 separate depth intervals** (0-15cm, 15-30cm, 30-50cm, 50-100cm) instead of aggregating into surface/deep groups.

---

## Module Workflow

```
Module 06 (Carbon Stock Calculation)
    ↓
    Generates: carbon_stocks_by_stratum_rf_wide.csv (per scenario/year)
    ↓
Module 08 (Temporal Data Harmonization)
    ↓
    Loads and aligns multiple scenarios/years
    ↓
Module 09 (Additionality & Temporal Analysis)
    ↓
    Calculates PROJECT - BASELINE differences
    ↓
Module 10 (VM0033 Final Verification)
    ↓
    Generates verification package with Excel tables and HTML reports
```

---

## Module 08: Temporal Data Harmonization

### Purpose
Load and align carbon stock data from multiple scenarios and time periods for temporal comparison.

### Required Input Files

#### Directory Structure
```
outputs/carbon_stocks/
├── BASELINE_2024/
│   ├── carbon_stocks_by_stratum_rf_wide.csv  ← REQUIRED
│   └── maps/
│       ├── carbon_stock_0-15cm_mean.tif
│       ├── carbon_stock_15-30cm_mean.tif
│       ├── carbon_stock_30-50cm_mean.tif
│       ├── carbon_stock_50-100cm_mean.tif
│       ├── carbon_stock_0-100cm total_mean.tif
│       └── *_conservative.tif versions
├── PROJECT_2024/
│   ├── carbon_stocks_by_stratum_rf_wide.csv  ← REQUIRED
│   └── maps/
│       └── (same rasters as above)
└── PROJECT_Y5_2029/  (optional - for multi-year analysis)
    ├── carbon_stocks_by_stratum_rf_wide.csv
    └── maps/
```

#### Wide-Format CSV Structure
Each `carbon_stocks_by_stratum_rf_wide.csv` file must contain these columns:

```
method, stratum, area_ha,
carbon_stock_0-15cm,           carbon_stock_se_0-15cm,           carbon_stock_conservative_0-15cm,
carbon_stock_15-30cm,          carbon_stock_se_15-30cm,          carbon_stock_conservative_15-30cm,
carbon_stock_30-50cm,          carbon_stock_se_30-50cm,          carbon_stock_conservative_30-50cm,
carbon_stock_50-100cm,         carbon_stock_se_50-100cm,         carbon_stock_conservative_50-100cm,
carbon_stock_0-100cm total,    carbon_stock_se_0-100cm total,    carbon_stock_conservative_0-100cm total
```

**How to Generate:** Module 06 automatically creates these files (as of the latest update).

### Output Files

```
data_temporal/
├── carbon_stocks_aligned.rds          # Combined RDS with all scenarios/years
├── temporal_metadata.csv              # Scenario/year tracking
└── stratum_coverage.csv               # Which strata appear in which scenarios
```

### Configuration Requirements

In `blue_carbon_config.R`:
```r
VALID_SCENARIOS <- c("BASELINE", "PROJECT", "PROJECT_Y5", "PROJECT_Y10")
MIN_YEARS_FOR_CHANGE <- 3
ADDITIONALITY_CONFIDENCE <- 0.95
```

---

## Module 09: Additionality & Temporal Analysis

### Purpose
Calculate carbon stock differences between scenarios and temporal trends.

### Required Input Files

```
data_temporal/
├── carbon_stocks_aligned.rds          # From Module 08
├── temporal_metadata.csv              # From Module 08
└── stratum_coverage.csv               # From Module 08
```

### Output Directories & Files

#### Additionality Outputs
```
outputs/additionality/
├── additionality_PROJECT_vs_BASELINE.csv       # Detailed results per stratum
├── additionality_all_scenarios.csv             # Combined all PROJECT scenarios
│
└── Raster Maps (if spatial data available):
    ├── additionality_interval_0_15_mean.tif
    ├── additionality_interval_15_30_mean.tif
    ├── additionality_interval_30_50_mean.tif
    ├── additionality_interval_50_100_mean.tif
    ├── additionality_total_mean.tif
    ├── additionality_*_conservative.tif versions
    └── significance_*.tif (binary maps showing positive differences)
```

#### CSV Columns (additionality_*.csv)
For each of the 4 VM0033 intervals + total, includes:
- Baseline carbon stock (mean ± SE)
- Project carbon stock (mean ± SE)
- Delta (PROJECT - BASELINE) (mean ± SE)
- 95% Confidence Intervals (lower, upper)
- Conservative estimate (95% CI lower bound)
- Percent change
- Statistical significance (p-value, significant flag)
- Additionality status (Substantial/Moderate/Marginal/None)

#### Temporal Change Outputs
```
outputs/temporal_change/
├── temporal_trends_by_stratum.csv     # Year-to-year trends
└── plots/
    ├── trajectory_total_[stratum].png          # Total 0-100cm over time
    └── trajectory_stacked_[stratum].png        # Stacked area showing all 4 intervals
```

#### Temporal Trends CSV Columns
For each stratum × scenario combination:
- Time span (first year, last year, duration)
- Carbon stocks at t0 and tn for each interval
- Total change and sequestration rate for each interval
- Percent change for each interval

### Analysis Outputs

**Console Reports Include:**
- Additionality for each stratum showing all 4 intervals separately
- Statistical significance markers (*)
- Conservative estimates for VM0033 compliance
- Project-wide summaries
- Temporal trends with interval-specific rates

---

## Module 10: VM0033 Final Verification Package

### Purpose
Generate comprehensive verification package with all required documentation for VM0033 compliance.

### Required Input Files

```
outputs/additionality/
└── additionality_all_scenarios.csv            # From Module 09

outputs/temporal_change/
└── temporal_trends_by_stratum.csv             # From Module 09 (optional)

data_temporal/
└── temporal_metadata.csv                      # From Module 08
```

### Output Files

```
outputs/verification/
├── vm0033_verification_tables.xlsx            # Excel workbook with 5 tabs
├── vm0033_final_verification_report.Rmd       # R Markdown source
└── vm0033_final_verification_report.html      # Final HTML report
```

#### Excel Workbook Tabs

**Tab 1: Project Characteristics**
- Project name, location
- Monitoring years (baseline, project)
- Scenarios analyzed
- Methodology (VM0033, ORRAA)
- Confidence level (95%)

**Tab 2: Carbon Stocks by Stratum**
- Baseline vs Project stocks
- Differences with 95% CI
- Conservative estimates
- Statistical significance
- Additionality status

**Tab 3: Emission Reductions (CO2e)**
- All 4 VM0033 intervals as separate columns
- Total 0-100cm CO2e reductions
- Conservative estimates in tonnes CO2e/ha
- Percent changes

**Tab 4: Uncertainty Analysis**
- Standard errors for baseline, project, difference
- 95% CI widths
- Relative uncertainty percentages
- Cohen's d effect sizes
- T-statistics and p-values

**Tab 5: Temporal Trends** (if multi-year data available)
- Carbon stocks at t0 and tn
- Total change and sequestration rates
- Interval-specific rates for all 4 VM0033 depths

#### HTML Report Sections
- Executive Summary
- Project Information
- Additionality Assessment
- Carbon Stocks by Stratum (interactive tables)
- Additionality Visualization (bar charts with error bars)
- Emission Reductions (CO2e)
- Temporal Trends (if available)
- Uncertainty Analysis
- Verification Statement
- Methods Summary
- Data Quality Assessment

---

## Running the Temporal Workflow

### Step-by-Step Guide

#### 1. Generate Baseline Scenario
```r
# Set configuration for BASELINE scenario
source("blue_carbon_config.R")
PROJECT_SCENARIO <- "BASELINE"
MONITORING_YEAR <- 2024

# Run modules 01-07 (or 01-06 if no spatial prediction needed)
source("01_data_preparation.R")
# ... continue through modules ...
source("06_carbon_stock_calculation_bluecarbon.R")

# Move outputs to scenario folder
dir.create("outputs/carbon_stocks/BASELINE_2024", recursive = TRUE)
file.copy(
  "outputs/carbon_stocks/carbon_stocks_by_stratum_rf_wide.csv",
  "outputs/carbon_stocks/BASELINE_2024/carbon_stocks_by_stratum_rf_wide.csv"
)
# Copy maps/ folder if needed
```

#### 2. Generate Project Scenario
```r
# Update configuration for PROJECT scenario
PROJECT_SCENARIO <- "PROJECT"
MONITORING_YEAR <- 2024

# Modify input data to reflect project conditions
# (e.g., updated vegetation, restoration activities)

# Run modules 01-07 again with project data
# ...

# Move outputs to scenario folder
dir.create("outputs/carbon_stocks/PROJECT_2024", recursive = TRUE)
file.copy(
  "outputs/carbon_stocks/carbon_stocks_by_stratum_rf_wide.csv",
  "outputs/carbon_stocks/PROJECT_2024/carbon_stocks_by_stratum_rf_wide.csv"
)
```

#### 3. Run Temporal Analysis
```r
# Module 08: Harmonize temporal data
source("08_temporal_data_harmonization.R")
# Output: data_temporal/carbon_stocks_aligned.rds

# Module 09: Calculate additionality
source("09_additionality_temporal_analysis.R")
# Output: outputs/additionality/*, outputs/temporal_change/*

# Module 10: Generate verification package
source("10_vm0033_final_verification.R")
# Output: outputs/verification/vm0033_verification_tables.xlsx
```

---

## VM0033 Depth Interval Details

### The 4 Standard Intervals

| Interval | Depth Range | Midpoint | Thickness | Purpose |
|----------|-------------|----------|-----------|---------|
| 1 | 0-15 cm | 7.5 cm | 15 cm | Surface active layer |
| 2 | 15-30 cm | 22.5 cm | 15 cm | Subsurface active layer |
| 3 | 30-50 cm | 40 cm | 20 cm | Upper deep layer |
| 4 | 50-100 cm | 75 cm | 50 cm | Lower deep layer |
| **Total** | **0-100 cm** | - | **100 cm** | **Complete 1-meter profile** |

### Why Track Intervals Separately?

1. **VM0033 Compliance:** Standard requires depth-stratified reporting
2. **Depth-Specific Insights:** Surface layers may accumulate carbon faster
3. **Uncertainty Quantification:** Each interval has independent error estimates
4. **Conservative Crediting:** Use 95% CI lower bound for each interval

---

## Troubleshooting

### Common Issues

**Error: "No carbon_stocks_by_stratum_rf_wide.csv files found"**
- **Cause:** Module 06 not run with latest version, or outputs not moved to scenario folders
- **Fix:** Re-run Module 06 (it now creates wide-format CSVs automatically)

**Error: "No overlapping strata between scenarios"**
- **Cause:** Stratum names differ between BASELINE and PROJECT
- **Fix:** Ensure consistent stratum naming in `stratum_definitions.csv`

**Warning: "No rasters found for spatial alignment"**
- **Cause:** maps/ folders missing from scenario directories
- **Fix:** Optional - only needed for spatial additionality maps

**Error: "Invalid scenario types detected"**
- **Cause:** Folder names don't match VALID_SCENARIOS in config
- **Fix:** Use standard names (BASELINE, PROJECT, PROJECT_Y5, etc.)

### Checking Data Integrity

```r
# Load and inspect harmonized data
temporal_data <- readRDS("data_temporal/carbon_stocks_aligned.rds")

# Check scenarios and years
unique(temporal_data$carbon_stocks$scenario)
unique(temporal_data$carbon_stocks$year)

# Check for required columns (all 4 intervals)
colnames(temporal_data$carbon_stocks)
# Should include: carbon_stock_0-15cm, carbon_stock_15-30cm, etc.

# Check stratum coverage
View(temporal_data$stratum_coverage)
```

---

## Best Practices

### Scenario Naming Convention
```
BASELINE_YYYY        # Baseline scenario for year YYYY
PROJECT_YYYY         # Project scenario for year YYYY
PROJECT_Y5_YYYY      # Project after 5 years
PROJECT_Y10_YYYY     # Project after 10 years
```

### Minimum Requirements

**For Additionality Analysis:**
- At least 1 BASELINE scenario
- At least 1 PROJECT scenario
- Overlapping strata between scenarios

**For Temporal Trends:**
- At least 2 time points (same scenario, different years)
- Minimum 3 years recommended for trend analysis

### VM0033 Conservative Approach

All modules use **95% confidence interval lower bound** for creditable estimates:
```r
conservative_estimate = pmax(0, mean - 1.96 * se)
```

This ensures only statistically robust carbon gains are credited.

---

## Output Summary Table

| Module | Primary Outputs | Secondary Outputs | Format |
|--------|----------------|-------------------|--------|
| 08 | carbon_stocks_aligned.rds | temporal_metadata.csv, stratum_coverage.csv | RDS, CSV |
| 09 | additionality_*.csv | temporal_trends_*.csv, *.tif maps, *.png plots | CSV, TIF, PNG |
| 10 | vm0033_verification_tables.xlsx | vm0033_final_verification_report.html | XLSX, HTML |

---

## References

- **VM0033 Methodology:** Verra Verified Carbon Standard - Tidal Wetland and Seagrass Restoration
- **ORRAA Principles:** Ocean Risk and Resilience Action Alliance High Quality Blue Carbon Principles v1.1
- **IPCC Guidelines:** 2013 Supplement to 2006 IPCC Guidelines for National Greenhouse Gas Inventories: Wetlands

---

**Last Updated:** 2025-01-15
**Workflow Version:** 4 VM0033 intervals (0-15, 15-30, 30-50, 50-100 cm)
