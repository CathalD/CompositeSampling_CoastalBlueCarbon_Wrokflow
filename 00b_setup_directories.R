# ============================================================================
# MODULE 00b: BLUE CARBON - DIRECTORY SETUP & CONFIGURATION
# ============================================================================
# PURPOSE: Create directory structure and configuration files
# USAGE: Run this AFTER 00a_install_packages.R
# ============================================================================

cat("========================================\n")
cat("BLUE CARBON - DIRECTORY SETUP\n")
cat("========================================\n\n")

# ============================================================================
# CONFIGURATION
# ============================================================================

log_file <- file.path(getwd(), paste0("directory_setup_log_", Sys.Date(), ".txt"))
log_message <- function(msg, level = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  log_entry <- sprintf("[%s] %s: %s", timestamp, level, msg)
  cat(log_entry, "\n")
  if (file.exists(dirname(log_file))) {
    cat(log_entry, "\n", file = log_file, append = TRUE)
  }
}

log_message("Starting directory setup")

# ============================================================================
# CHECK PACKAGE INSTALLATION
# ============================================================================

cat("Checking package installation status...\n")

if (file.exists("data_processed/package_install_summary.rds")) {
  install_summary <- readRDS("data_processed/package_install_summary.rds")
  cat(sprintf("  Package installation: %.1f%% complete\n", install_summary$success_rate))
  
  if (install_summary$success_rate < 90) {
    cat("\n⚠ WARNING: Less than 90% of packages installed.\n")
    cat("  Some features may not work correctly.\n")
    cat("  Consider re-running 00a_install_packages.R\n\n")
  } else {
    cat("  ✓ Package installation OK\n\n")
  }
} else {
  cat("  ⚠ Package installation status unknown\n")
  cat("  Have you run 00a_install_packages.R?\n\n")
}

# ============================================================================
# CREATE DIRECTORY STRUCTURE
# ============================================================================

cat("========================================\n")
cat("CREATING DIRECTORY STRUCTURE\n")
cat("========================================\n\n")

directories <- c(
  # Data directories
  "data_raw",
  "data_processed",
  
  # Covariate directories
  "covariates",
  "covariates/optical",
  "covariates/sar",
  "covariates/tidal",
  "covariates/topographic",
  "covariates/quality",
  
  # Output directories
  "outputs",
  "outputs/plots",
  "outputs/plots/by_stratum",
  "outputs/plots/exploratory",
  "outputs/plots/diagnostics",
  "outputs/models",
  "outputs/models/kriging",
  "outputs/models/rf",
  "outputs/models/splines",
  "outputs/predictions",
  "outputs/predictions/kriging",
  "outputs/predictions/rf",
  "outputs/predictions/uncertainty",
  "outputs/carbon_stocks",
  "outputs/mmrv_reports",
  
  # Analysis directories
  "logs",
  "qaqc",
  "diagnostics",
  "diagnostics/variograms",
  "diagnostics/crossvalidation"
)

created <- 0
existed <- 0
failed <- 0

for (dir_name in directories) {
  tryCatch({
    if (!dir.exists(dir_name)) {
      dir.create(dir_name, recursive = TRUE, showWarnings = FALSE)
      created <- created + 1
      cat(sprintf("  ✓ Created: %s\n", dir_name))
      log_message(sprintf("Created directory: %s", dir_name))
    } else {
      existed <- existed + 1
      # Don't print for existing dirs to reduce clutter
    }
  }, error = function(e) {
    failed <- failed + 1
    cat(sprintf("  ✗ Failed: %s\n", dir_name))
    log_message(sprintf("Failed to create %s: %s", dir_name, e$message), "ERROR")
  })
}

cat(sprintf("\nDirectory summary:\n"))
cat(sprintf("  Created: %d\n", created))
cat(sprintf("  Already existed: %d\n", existed))
if (failed > 0) {
  cat(sprintf("  Failed: %d\n", failed))
}
cat("\n")

# ============================================================================
# CREATE CONFIGURATION FILE
# ============================================================================

cat("========================================\n")
cat("CREATING CONFIGURATION FILE\n")
cat("========================================\n\n")

config_content <- '# ============================================================================
# BLUE CARBON PROJECT CONFIGURATION
# ============================================================================
# Edit these parameters for your specific project
# This file is sourced by analysis modules

# ============================================================================
# PROJECT METADATA (VM0033 Required)
# ============================================================================

PROJECT_NAME <- "Blue_Carbon_Canada"
PROJECT_SCENARIO <- "PROJECT"  # Options: BASELINE, PROJECT, CONTROL, DEGRADED
MONITORING_YEAR <- 2024

# Project location (for documentation)
PROJECT_LOCATION <- "Chemainus Estuary, British Columbia, Canada"
PROJECT_DESCRIPTION <- "Blue carbon assessment of coastal salt marsh and eelgrass ecosystems"

# ============================================================================
# ECOSYSTEM STRATIFICATION
# ============================================================================

# Valid ecosystem strata (must match GEE stratification tool)
VALID_STRATA <- c(
  "Upper Marsh",           # Infrequent flooding, salt-tolerant shrubs
  "Mid Marsh",             # Regular inundation, mixed halophytes (HIGHEST C sequestration)
  "Lower Marsh",           # Daily tides, dense Spartina (HIGHEST burial rates)
  "Underwater Vegetation", # Subtidal seagrass beds
  "Open Water"            # Tidal channels, lagoons
)

# Stratum colors for plotting (match GEE tool)
STRATUM_COLORS <- c(
  "Upper Marsh" = "#FFFF99",
  "Mid Marsh" = "#99FF99",
  "Lower Marsh" = "#33CC33",
  "Underwater Vegetation" = "#0066CC",
  "Open Water" = "#000099"
)

# ============================================================================
# DEPTH CONFIGURATION
# ============================================================================

# Standard depth intervals (cm) - VM0033 recommendations
STANDARD_DEPTHS <- c(0, 5, 10, 15, 20, 25, 30, 40, 50, 75, 100)

# Maximum core depth (cm)
MAX_CORE_DEPTH <- 100

# Key depth intervals for reporting (cm)
REPORTING_DEPTHS <- list(
  surface = c(0, 30),      # Top 30 cm (most active layer)
  subsurface = c(30, 100)  # 30-100 cm (long-term storage)
)

# ============================================================================
# COORDINATE SYSTEMS
# ============================================================================

# Input CRS (usually WGS84 for GPS data)
INPUT_CRS <- 4326  # EPSG:4326 (WGS84)

# Processing CRS (projected, equal-area for accurate calculations)
# Change this for your region:
PROCESSING_CRS <- 3347  # EPSG:3347 (Canada Albers Equal Area)
# Other options:
#   - 3005: NAD83 / BC Albers
#   - 32610: WGS 84 / UTM zone 10N (BC coast)
#   - 32611: WGS 84 / UTM zone 11N (BC interior)

# ============================================================================
# BULK DENSITY DEFAULTS BY STRATUM
# ============================================================================
# Use these when bulk density is not measured
# Values in g/cm³ based on literature for BC coastal ecosystems

BD_DEFAULTS <- list(
  "Upper Marsh" = 0.8,              # Lower density, more organic matter
  "Mid Marsh" = 1.0,                # Moderate density
  "Lower Marsh" = 1.2,              # Higher density, more mineral content
  "Underwater Vegetation" = 0.6,    # Lowest density, high organic content
  "Open Water" = 1.0                # Moderate, mostly mineral
)

# ============================================================================
# QUALITY CONTROL THRESHOLDS
# ============================================================================

# Soil Organic Carbon (SOC) thresholds (g/kg)
QC_SOC_MIN <- 0      # Minimum valid SOC
QC_SOC_MAX <- 500    # Maximum valid SOC (adjust for your ecosystem)

# Bulk Density thresholds (g/cm³)
QC_BD_MIN <- 0.1     # Minimum valid bulk density
QC_BD_MAX <- 3.0     # Maximum valid bulk density

# Depth thresholds (cm)
QC_DEPTH_MIN <- 0
QC_DEPTH_MAX <- MAX_CORE_DEPTH

# Coordinate validity (decimal degrees for WGS84)
QC_LON_MIN <- -180
QC_LON_MAX <- 180
QC_LAT_MIN <- -90
QC_LAT_MAX <- 90

# ============================================================================
# UNCERTAINTY PARAMETERS
# ============================================================================

# Confidence level for uncertainty estimation (VM0033 requires 95%)
CONFIDENCE_LEVEL <- 0.95

# Bootstrap parameters for spline uncertainty
BOOTSTRAP_ITERATIONS <- 100
BOOTSTRAP_SEED <- 42

# Cross-validation parameters
CV_FOLDS <- 3           # Number of folds for spatial CV (reduced for small datasets)
CV_SEED <- 42           # Random seed for reproducibility

# ============================================================================
# SPATIAL MODELING PARAMETERS
# ============================================================================

# Prediction resolution (meters)
KRIGING_CELL_SIZE <- 10
RF_CELL_SIZE <- 10

# Kriging parameters
KRIGING_MAX_DISTANCE <- 5000  # Maximum distance for variogram (meters)
KRIGING_CUTOFF <- NULL        # NULL = automatic
KRIGING_WIDTH <- 100          # Lag width for variogram (meters)

# Random Forest parameters
RF_NTREE <- 500              # Number of trees
RF_MTRY <- NULL              # NULL = automatic (sqrt of predictors)
RF_MIN_NODE_SIZE <- 5        # Minimum node size
RF_IMPORTANCE <- "permutation"  # Variable importance method

# ============================================================================
# AREA OF APPLICABILITY (AOA) PARAMETERS
# ============================================================================

# Enable AOA analysis (requires CAST package)
ENABLE_AOA <- TRUE

# AOA threshold (dissimilarity index)
AOA_THRESHOLD <- "default"  # "default" or numeric value

# ============================================================================
# REPORT GENERATION PARAMETERS
# ============================================================================

# Figure dimensions for saving (inches)
FIGURE_WIDTH <- 10
FIGURE_HEIGHT <- 6
FIGURE_DPI <- 300

# Table formatting
TABLE_DIGITS <- 2  # Decimal places for tables

# ============================================================================
# END OF CONFIGURATION
# ============================================================================

# Print confirmation when loaded
if (interactive()) {
  cat("Blue Carbon configuration loaded ✓\n")
  cat(sprintf("  Project: %s\n", PROJECT_NAME))
  cat(sprintf("  Location: %s\n", PROJECT_LOCATION))
  cat(sprintf("  Scenario: %s\n", PROJECT_SCENARIO))
  cat(sprintf("  Monitoring year: %d\n", MONITORING_YEAR))
}
'

config_file <- "blue_carbon_config.R"

tryCatch({
  writeLines(config_content, config_file)
  cat(sprintf("✓ Created: %s\n\n", config_file))
  log_message("Created configuration file")
  
  # Test loading the config
  source(config_file)
  cat("  Configuration file validated ✓\n\n")
  
}, error = function(e) {
  cat(sprintf("✗ Failed to create configuration file: %s\n\n", e$message))
  log_message(sprintf("Failed to create config: %s", e$message), "ERROR")
})

# ============================================================================
# CREATE .RPROFILE
# ============================================================================

cat("========================================\n")
cat("CREATING .RPROFILE\n")
cat("========================================\n\n")

rprofile_content <- '# ============================================================================
# Blue Carbon Project .Rprofile
# ============================================================================
# This file is automatically loaded when R starts in this directory

# Set project-specific options
options(
  stringsAsFactors = FALSE,    # Modern R default
  scipen = 999,                 # Avoid scientific notation
  digits = 4,                   # Decimal places for printing
  max.print = 100,              # Limit console output
  warn = 1                      # Print warnings as they occur
)

# Set CRAN mirror
options(repos = c(CRAN = "https://cloud.r-project.org/"))

# Load commonly used packages (suppress startup messages)
suppressPackageStartupMessages({
  if (require("dplyr", quietly = TRUE)) cat("✓ dplyr loaded\\n")
  if (require("ggplot2", quietly = TRUE)) cat("✓ ggplot2 loaded\\n")
  if (require("sf", quietly = TRUE)) cat("✓ sf loaded\\n")
})

# Welcome message
cat("\\n")
cat("========================================\\n")
cat("BLUE CARBON MMRV PROJECT\\n")
cat("========================================\\n")
cat("Working directory:", getwd(), "\\n")
cat("R version:", R.version$version.string, "\\n")
cat("\\n")
cat("Configuration: source(\\"blue_carbon_config.R\\")\\n")
cat("Start analysis: source(\\"01_data_prep_bluecarbon.R\\")\\n")
cat("\\n")
'

rprofile_file <- ".Rprofile"

tryCatch({
  writeLines(rprofile_content, rprofile_file)
  cat(sprintf("✓ Created: %s\n", rprofile_file))
  cat("  (Restart R to activate)\n\n")
  log_message("Created .Rprofile")
}, error = function(e) {
  cat(sprintf("✗ Failed to create .Rprofile: %s\n\n", e$message))
  log_message(sprintf("Failed to create .Rprofile: %s", e$message), "WARNING")
})

# ============================================================================
# CREATE README
# ============================================================================

cat("========================================\n")
cat("CREATING README\n")
cat("========================================\n\n")

readme_content <- '# Blue Carbon MMRV Analysis Workflow

## Project Overview
This project implements a VM0033-compliant workflow for blue carbon monitoring, reporting, and verification (MMRV) in coastal ecosystems.

## Directory Structure

```
├── data_raw/                  # Raw field data (add your CSV files here)
├── data_processed/            # Processed R objects
├── covariates/               # GEE covariate exports
│   ├── optical/              # NDVI, NDWI, etc.
│   ├── sar/                  # SAR backscatter
│   ├── tidal/                # Tidal indicators
│   ├── topographic/          # DEM derivatives
│   └── quality/              # QA/QC layers
├── outputs/                  # Analysis outputs
│   ├── plots/                # Figures
│   ├── models/               # Saved models
│   ├── predictions/          # Spatial predictions
│   ├── carbon_stocks/        # Stock calculations
│   └── mmrv_reports/         # VM0033 reports
├── logs/                     # Analysis logs
├── qaqc/                     # Quality control outputs
└── diagnostics/              # Model diagnostics

```

## Workflow Modules

### Setup (Run Once)
1. **00a_install_packages.R** - Install all required R packages
2. **00b_setup_directories.R** - Create directory structure and config files

### Analysis Pipeline
1. **01_data_prep_bluecarbon.R** - Load and clean field data
2. **02_exploratory_analysis_bluecarbon.R** - EDA by stratum
3. **03_depth_harmonization_bluecarbon.R** - Spline fitting
4. **04_raster_predictions_kriging_bluecarbon.R** - Kriging interpolation
5. **05_raster_predictions_rf_bluecarbon.R** - Random forest prediction
6. **06_carbon_stock_calculation.R** - Carbon stock integration
7. **07_mmrv_reporting.R** - VM0033 verification outputs

## Required Input Files

Place in `data_raw/`:
- **core_locations.csv** - GPS coordinates and stratum assignments
- **core_samples.csv** - Depth profiles and SOC measurements

### core_locations.csv format:
```
core_id,longitude,latitude,stratum,collection_date,core_type,scenario_type
HR_001,-123.72,48.91,Mid Marsh,2024-06-15,hr_core,PROJECT
```

### core_samples.csv format:
```
core_id,depth_top_cm,depth_bottom_cm,soc_g_kg,bulk_density_g_cm3
HR_001,0,5,45.2,0.9
```

## Configuration

Edit `blue_carbon_config.R` to customize:
- Project metadata
- Valid strata names
- Coordinate systems
- QC thresholds
- Model parameters

## Getting Started

1. Install packages:
   ```r
   source("00a_install_packages.R")
   ```

2. Setup directories:
   ```r
   source("00b_setup_directories.R")
   ```

3. Add your data files to `data_raw/`

4. Start analysis:
   ```r
   source("01_data_prep_bluecarbon.R")
   ```

## VM0033 Compliance

This workflow implements:
- Stratum-specific sampling and analysis
- Conservative uncertainty estimation (95% CI)
- Area of Applicability (AOA) analysis
- Comprehensive QA/QC
- Verification-ready reporting

## Support

For questions or issues, check the logs in `logs/` directory.
'

readme_file <- "README.md"

tryCatch({
  writeLines(readme_content, readme_file)
  cat(sprintf("✓ Created: %s\n\n", readme_file))
  log_message("Created README")
}, error = function(e) {
  cat(sprintf("✗ Failed to create README: %s\n\n", e$message))
  log_message(sprintf("Failed to create README: %s", e$message), "WARNING")
})

# ============================================================================
# DATA FILE CHECK
# ============================================================================

cat("========================================\n")
cat("CHECKING FOR DATA FILES\n")
cat("========================================\n\n")

required_files <- c(
  "data_raw/core_locations.csv",
  "data_raw/core_samples.csv"
)

found <- 0
missing <- 0

for (file in required_files) {
  if (file.exists(file)) {
    found <- found + 1
    cat(sprintf("  ✓ Found: %s\n", basename(file)))
  } else {
    missing <- missing + 1
    cat(sprintf("  ✗ Missing: %s\n", basename(file)))
  }
}

if (missing > 0) {
  cat("\n⚠ Data files missing. Please add to data_raw/:\n")
  cat("  - core_locations.csv (GPS + stratum)\n")
  cat("  - core_samples.csv (depth profiles + SOC)\n")
  cat("\nSee README.md for file format details.\n\n")
}

# ============================================================================
# FINAL SUMMARY
# ============================================================================

cat("\n========================================\n")
cat("SETUP COMPLETE\n")
cat("========================================\n\n")

cat("Summary:\n")
cat("----------------------------------------\n")
cat(sprintf("R version: %s\n", R.version$version.string))
cat(sprintf("Working directory: %s\n", getwd()))
cat(sprintf("Directories created: %d\n", created + existed))
cat(sprintf("Configuration files: %d\n", 
            sum(file.exists(c("blue_carbon_config.R", ".Rprofile", "README.md")))))
cat(sprintf("Data files found: %d/%d\n", found, length(required_files)))
cat("\n")

# Save setup summary
setup_summary <- list(
  date = Sys.Date(),
  r_version = R.version$version.string,
  working_directory = getwd(),
  directories_created = created,
  directories_existed = existed,
  config_files_created = file.exists(c("blue_carbon_config.R", ".Rprofile", "README.md")),
  data_files_found = found,
  data_files_missing = missing
)

saveRDS(setup_summary, "data_processed/setup_summary.rds")
cat("Setup summary saved to: data_processed/setup_summary.rds\n\n")

# ============================================================================
# NEXT STEPS
# ============================================================================

if (missing == 0) {
  cat("✓✓✓ READY TO START ANALYSIS!\n\n")
  cat("Next steps:\n")
  cat("  1. Review blue_carbon_config.R (optional)\n")
  cat("  2. Run: source('01_data_prep_bluecarbon.R')\n\n")
  
} else {
  cat("⚠ SETUP COMPLETE (data files needed)\n\n")
  cat("Next steps:\n")
  cat("  1. Add data files to data_raw/:\n")
  cat("     - core_locations.csv\n")
  cat("     - core_samples.csv\n")
  cat("  2. Review blue_carbon_config.R\n")
  cat("  3. Run: source('01_data_prep_bluecarbon.R')\n\n")
}

log_message("Directory setup complete")

cat("Setup complete! 🌊\n\n")
