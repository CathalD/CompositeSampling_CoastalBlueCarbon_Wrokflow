# ============================================================================
# GRASSLAND CARBON PROJECT CONFIGURATION
# ============================================================================
# Configuration for Canadian Prairie and Grassland Carbon Assessment
# Adapted from coastal blue carbon workflow for terrestrial grassland ecosystems
# This file is sourced by analysis modules

# ============================================================================
# PROJECT METADATA (AAFC/Canadian Offset Protocol Required)
# ============================================================================

PROJECT_NAME <- "Grassland_Carbon_Canada"
PROJECT_SCENARIO <- "PROJECT"  # Options: BASELINE, PROJECT, CONTROL, DEGRADED
MONITORING_YEAR <- 2024

# Project location (for documentation)
PROJECT_LOCATION <- "Canadian Prairies (Alberta/Saskatchewan)"
PROJECT_DESCRIPTION <- "Grassland carbon assessment for Canadian prairie and rangeland ecosystems"

# ============================================================================
# ECOSYSTEM STRATIFICATION (CANADIAN GRASSLAND TYPES)
# ============================================================================

# Valid grassland strata (Canadian prairie ecosystem types)
VALID_STRATA <- c(
  "Fescue Prairie",       # Native fescue grasslands, Alberta/Saskatchewan foothills
  "Mixed-Grass Prairie",  # Native prairie, C3/C4 mix, southern prairies
  "Aspen Parkland",       # Grassland-aspen mosaic, transition zone
  "Improved Pasture",     # Seeded, managed, fertilized
  "Degraded Grassland"    # Overgrazed, invasive species, erosion
)

# Stratum colors for plotting (Canadian grassland types)
STRATUM_COLORS <- c(
  "Fescue Prairie" = "#99CC66",        # Light green - productive native
  "Mixed-Grass Prairie" = "#FFCC66",   # Golden - mixed native grasses
  "Aspen Parkland" = "#66CC99",        # Blue-green - tree-grass mosaic
  "Improved Pasture" = "#99FF99",      # Bright green - managed
  "Degraded Grassland" = "#CC9966"     # Brown - degraded
)

# ============================================================================
# DEPTH CONFIGURATION (GRASSLAND SOILS)
# ============================================================================

# Grassland standard depth intervals (cm) - focus on topsoil with deep sampling
# Most carbon in top 30 cm, but extend to 100 cm for completeness
GRASSLAND_DEPTH_MIDPOINTS <- c(5, 20, 40, 75)

# Grassland depth intervals (cm) - for mass-weighted aggregation
GRASSLAND_DEPTH_INTERVALS <- data.frame(
  depth_top = c(0, 10, 30, 50),
  depth_bottom = c(10, 30, 50, 100),
  depth_midpoint = c(5, 20, 40, 75),
  thickness_cm = c(10, 20, 20, 50)
)

# Standard depths for harmonization (grassland midpoints)
STANDARD_DEPTHS <- GRASSLAND_DEPTH_MIDPOINTS

# Fine-scale depth intervals (optional, for detailed analysis)
FINE_SCALE_DEPTHS <- c(0, 5, 10, 15, 20, 25, 30, 40, 50, 75, 100)

# Maximum core depth (cm)
MAX_CORE_DEPTH <- 100

# Key depth intervals for reporting (cm) - grassland focus
REPORTING_DEPTHS <- list(
  surface = c(0, 30),      # Top 30 cm (most active layer, highest SOC)
  subsurface = c(30, 100)  # 30-100 cm (long-term storage)
)

# ============================================================================
# COORDINATE SYSTEMS (CANADIAN PROJECTIONS)
# ============================================================================

# Input CRS (usually WGS84 for GPS data)
INPUT_CRS <- 4326  # EPSG:4326 (WGS84)

# Processing CRS (projected, equal-area for accurate calculations)
# Canada Albers Equal Area - optimal for prairie provinces
PROCESSING_CRS <- 3347  # EPSG:3347 (Canada Albers Equal Area)
# Alternative provincial systems:
#   - 3400: NAD83 / Alberta 10-TM (Forest)
#   - 2955: NAD83(CSRS) / UTM zone 13N (Saskatchewan)
#   - 3401: NAD83 / Saskatchewan TMBR (TM)

# ============================================================================
# BULK DENSITY DEFAULTS BY STRATUM (CANADIAN GRASSLAND SOILS)
# ============================================================================
# Use these when bulk density is not measured
# Values in g/cm³ based on Canadian prairie soil literature

BD_DEFAULTS <- list(
  "Fescue Prairie" = 1.05,        # Deep A-horizon, moderate BD, high organic matter
  "Mixed-Grass Prairie" = 1.20,   # Moderate organic matter, drier conditions
  "Aspen Parkland" = 1.00,        # Influenced by tree litter, lower BD
  "Improved Pasture" = 1.15,      # Managed, less compaction than degraded
  "Degraded Grassland" = 1.40     # Compacted from overgrazing, higher BD
)

# ============================================================================
# GRASSLAND-SPECIFIC PARAMETERS (NEW FOR GRASSLANDS)
# ============================================================================

# Grazing intensity (typical/default for project area)
GRAZING_INTENSITY <- "Moderate"  # Options: "None", "Light", "Moderate", "Heavy", "Severe"

# Fire frequency (years between fires) - Canadian prairies less frequent than US
FIRE_FREQUENCY_YEARS <- 10  # Conservative - prescribed fire less common in Canada

# Root sampling depth (cm) - most root biomass in top 30 cm for grasslands
ROOT_SAMPLING_DEPTH <- 30

# Growing season definition (Canadian prairie climate)
GROWING_SEASON_START <- "May"    # Month name
GROWING_SEASON_END <- "September" # Month name
GROWING_SEASON_MONTHS <- 5       # Number of months

# Grazing season (typical for Canadian prairies)
GRAZING_SEASON_START <- "May"
GRAZING_SEASON_END <- "October"

# ============================================================================
# QUALITY CONTROL THRESHOLDS (CANADIAN GRASSLAND SOILS)
# ============================================================================

# Soil Organic Carbon (SOC) thresholds (g/kg)
# Canadian grasslands typically 20-100 g/kg in topsoil
QC_SOC_MIN <- 0      # Minimum valid SOC
QC_SOC_MAX <- 150    # Maximum valid SOC (adjusted for grassland range)

# Bulk Density thresholds (g/cm³)
QC_BD_MIN <- 0.5     # Minimum valid bulk density (grasslands rarely below this)
QC_BD_MAX <- 2.0     # Maximum valid bulk density (compacted grassland soils)

# Depth thresholds (cm)
QC_DEPTH_MIN <- 0
QC_DEPTH_MAX <- MAX_CORE_DEPTH

# Coordinate validity (decimal degrees for WGS84)
# Canadian prairies: roughly 49-55°N, -115 to -95°W
QC_LON_MIN <- -120
QC_LON_MAX <- -90
QC_LAT_MIN <- 48
QC_LAT_MAX <- 60

# ============================================================================
# CANADIAN PROTOCOL SAMPLING REQUIREMENTS
# ============================================================================

# Minimum cores per stratum (AAFC/Canadian protocol requirement)
AAFC_MIN_CORES <- 3  # Minimum, but 30+ recommended for spatial modeling

# Target precision (acceptable range: 10-20% relative error at 95% CI)
AAFC_TARGET_PRECISION <- 20  # percent

# Target CV threshold (higher CV = higher uncertainty)
AAFC_CV_THRESHOLD <- 30  # percent

# Assumed CV for sample size calculation (conservative estimate)
AAFC_ASSUMED_CV <- 30  # percent (grasslands can be highly variable)

# ============================================================================
# DEPTH HARMONIZATION PARAMETERS (GRASSLAND ADAPTED)
# ============================================================================

# Interpolation method: "equal_area_spline", "smoothing_spline", "linear", "all"
INTERPOLATION_METHOD <- "equal_area_spline"  # Recommended default

# Spline smoothing parameters by core type
SPLINE_SPAR_HR <- 0.3           # Less smoothing for high-resolution cores
SPLINE_SPAR_COMPOSITE <- 0.5    # More smoothing for composite cores
SPLINE_SPAR_AUTO <- NULL        # NULL = automatic cross-validation

# Monotonicity parameters (grasslands typically decrease with depth)
ALLOW_DEPTH_INCREASES <- FALSE   # Grassland SOC typically decreases with depth
MAX_INCREASE_THRESHOLD <- 10     # Maximum % increase allowed between adjacent depths

# ============================================================================
# UNCERTAINTY PARAMETERS
# ============================================================================

# Confidence level for uncertainty estimation (Canadian protocols require 95%)
CONFIDENCE_LEVEL <- 0.95

# Bootstrap parameters for spline uncertainty
BOOTSTRAP_ITERATIONS <- 100
BOOTSTRAP_SEED <- 42

# Cross-validation parameters
CV_FOLDS <- 3           # Number of folds for spatial CV (reduced for small datasets)
CV_SEED <- 42           # Random seed for reproducibility

# ============================================================================
# SPATIAL MODELING PARAMETERS (GRASSLAND LANDSCAPES)
# ============================================================================

# Prediction resolution (meters) - grasslands can use coarser resolution
KRIGING_CELL_SIZE <- 30  # 30m suitable for grassland variability
RF_CELL_SIZE <- 30       # Match Landsat resolution

# Kriging parameters (adjusted for grassland spatial patterns)
KRIGING_MAX_DISTANCE <- 10000  # Maximum distance for variogram (meters)
KRIGING_CUTOFF <- NULL         # NULL = automatic
KRIGING_WIDTH <- 250           # Lag width for variogram (meters)

# Random Forest parameters
RF_NTREE <- 500              # Number of trees
RF_MTRY <- NULL              # NULL = automatic (sqrt of predictors)
RF_MIN_NODE_SIZE <- 5        # Minimum node size
RF_IMPORTANCE <- "permutation"  # Variable importance method

# ============================================================================
# GRASSLAND COVARIATE SPECIFICATIONS
# ============================================================================

# Key covariates for Canadian grassland carbon modeling
# These should be available as raster files in covariates/ directory

REQUIRED_COVARIATES <- c(
  "NDVI",              # Productivity, greenness
  "EVI",               # Enhanced vegetation index
  "precipitation_annual",    # Critical in semi-arid prairies
  "precipitation_gs",        # Growing season precipitation
  "temperature_mean",        # Mean annual temperature
  "elevation",         # Topographic position
  "slope",            # Affects moisture and erosion
  "clay_content"      # Affects SOC stabilization
)

OPTIONAL_COVARIATES <- c(
  "aspect",           # Affects moisture
  "TWI",              # Topographic wetness index
  "grazing_intensity", # From management records or remote sensing
  "fire_history",     # From Landsat time series
  "soil_drainage",    # Drainage class
  "growing_degree_days", # GDD for productivity
  "landsat_NBR",      # Normalized Burn Ratio
  "landsat_NDMI"      # Normalized Difference Moisture Index
)

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
# CANADIAN PROTOCOL REFERENCES
# ============================================================================

# Primary guidelines for Canadian grassland carbon assessment
PROTOCOL_REFERENCES <- list(
  primary = c(
    "Agriculture and Agri-Food Canada (AAFC) Soil Carbon Protocols",
    "Canadian Grazing Lands and Rangelands Carbon Offset Protocol",
    "Alberta Offset System - Conservation Cropping Protocol",
    "Canadian Agricultural Greenhouse Gas Monitoring Program"
  ),
  secondary = c(
    "IPCC 2006 Grassland Chapter (Chapter 6)",
    "Natural Resources Canada (NRCan) Grassland Carbon Guidance",
    "Verra VCS VM0026 (Sustainable Grassland Management)"
  )
)

# ============================================================================
# ECOREGION CLASSIFICATIONS (CANADIAN PRAIRIES)
# ============================================================================

# Canadian prairie ecoregions for stratification
PRAIRIE_ECOREGIONS <- c(
  "Fescue Grasslands",
  "Mixed Grasslands",
  "Moist Mixed Grasslands",
  "Aspen Parkland",
  "Cypress Upland",
  "Northern Fescue"
)

# ============================================================================
# END OF CONFIGURATION
# ============================================================================

# Print confirmation when loaded
if (interactive()) {
  cat("Grassland Carbon Configuration Loaded ✓\n")
  cat(sprintf("  Project: %s\n", PROJECT_NAME))
  cat(sprintf("  Location: %s\n", PROJECT_LOCATION))
  cat(sprintf("  Scenario: %s\n", PROJECT_SCENARIO))
  cat(sprintf("  Monitoring year: %d\n", MONITORING_YEAR))
  cat(sprintf("  Grassland types: %d strata\n", length(VALID_STRATA)))
  cat(sprintf("  Depth range: 0-%d cm\n", MAX_CORE_DEPTH))
  cat(sprintf("  Grazing intensity: %s\n", GRAZING_INTENSITY))
  cat(sprintf("  Fire frequency: %d years\n", FIRE_FREQUENCY_YEARS))
}
