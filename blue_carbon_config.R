# ============================================================================
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
  cat("Blue Carbon configuration loaded ✓
")
  cat(sprintf("  Project: %s
", PROJECT_NAME))
  cat(sprintf("  Location: %s
", PROJECT_LOCATION))
  cat(sprintf("  Scenario: %s
", PROJECT_SCENARIO))
  cat(sprintf("  Monitoring year: %d
", MONITORING_YEAR))
}

