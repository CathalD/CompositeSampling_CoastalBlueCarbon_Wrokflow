# ============================================================================
# CANADIAN GRASSLAND CARBON PROJECT CONFIGURATION
# ============================================================================
# Adapted from Blue Carbon MMRV Workflow for Canadian Prairie Ecosystems
# Edit these parameters for your specific grassland project
# This file is sourced by analysis modules

# ============================================================================
# PROJECT METADATA (Canadian Grassland Standards)
# ============================================================================

PROJECT_NAME <- "Alberta_Mixed_Grassland_Carbon_2024"
PROJECT_SCENARIO <- "PROJECT"  # Options: BASELINE, PROJECT, CONTROL, DEGRADED, RESTORED, NATIVE
MONITORING_YEAR <- 2024

# Project location (for documentation)
# Update this to your specific region
PROJECT_LOCATION <- "Mixed Grass Natural Subregion, Southern Alberta, Canada"
PROJECT_DESCRIPTION <- "Grassland soil organic carbon monitoring for improved grazing management - VM0032 compliant assessment with baseline comparison for carbon offset generation under Alberta TIER protocol"

# ============================================================================
# ECOSYSTEM STRATIFICATION - GRASSLAND TYPES
# ============================================================================

# Valid grassland strata (replaces marine ecosystem strata)
#
# FILE NAMING CONVENTION:
#   Module 05 auto-detects GEE stratum masks using this pattern:
#   "Stratum Name" → stratum_name.tif in data_raw/gee_strata/
#
# Examples:
#   "Native Prairie"        → native_prairie.tif
#   "Improved Pasture"      → improved_pasture.tif
#   "Restored Grassland"    → restored_grassland.tif
#
# GRASSLAND ECOSYSTEM TYPES:
#   - Native Prairie: Never cultivated, reference condition, high diversity
#   - Improved Pasture: Seeded, fertilized, managed for livestock
#   - Degraded Grassland: Overgrazed, invaded by weeds, compacted soils
#   - Restored Grassland: Ex-cropland restoration, recovery trajectory
#   - Riparian Grassland: Wetland margins, higher moisture, unique species
#
VALID_STRATA <- c(
  "Native Prairie",        # Never cultivated, reference (HIGHEST SOC, ~60-80 Mg C/ha 0-30cm)
  "Improved Pasture",      # Seeded, fertilized (MODERATE SOC, ~40-60 Mg C/ha)
  "Degraded Grassland",    # Overgrazed, invaded (LOW SOC, ~30-45 Mg C/ha)
  "Restored Grassland",    # Ex-cropland restoration (VARIABLE, 35-55 Mg C/ha)
  "Riparian Grassland"     # Wetland margins (HIGH SOC, ~55-75 Mg C/ha)
)

# Stratum colors for plotting (earth tones for grasslands)
STRATUM_COLORS <- c(
  "Native Prairie" = "#8B7355",         # Brown - natural reference
  "Improved Pasture" = "#9ACD32",       # Yellow-green - managed
  "Degraded Grassland" = "#D2B48C",     # Tan - degraded
  "Restored Grassland" = "#90EE90",     # Light green - restoration
  "Riparian Grassland" = "#20B2AA"      # Light sea green - riparian
)

# ============================================================================
# DEPTH CONFIGURATION - GRASSLAND SOIL PROFILES
# ============================================================================

# GRASSLAND standard depth intervals (cm) - replaces VM0033 marine depths
# Based on Canadian agricultural GHG methodology and VM0042
# Focus on top 30 cm for management effects, extend to 100 cm for full profile

# PRIMARY GRASSLAND DEPTH MIDPOINTS (cm)
# These correspond to key agricultural soil layers:
#   0-15 cm:   Primary active layer (tillage depth, root concentration)
#   15-30 cm:  Secondary active layer (lower root zone)
#   30-50 cm:  Transition zone (minimal management effect)
#   50-100 cm: Deep storage (legacy carbon, minimal change)
GRASSLAND_DEPTH_MIDPOINTS <- c(7.5, 22.5, 40, 75)

# GRASSLAND depth intervals (cm) - for mass-weighted aggregation
GRASSLAND_DEPTH_INTERVALS <- data.frame(
  depth_top = c(0, 15, 30, 50),
  depth_bottom = c(15, 30, 50, 100),
  depth_midpoint = c(7.5, 22.5, 40, 75),
  thickness_cm = c(15, 15, 20, 50)
)

# COMPATIBILITY ALIASES: Allow existing modules to work with grassland config
# These aliases enable seamless ecosystem switching without module code changes
VM0033_DEPTH_INTERVALS <- GRASSLAND_DEPTH_INTERVALS
VM0033_DEPTH_MIDPOINTS <- GRASSLAND_DEPTH_MIDPOINTS

# OPTIONAL: Fine-scale depth intervals for management effects
# Include shallow depths (0-5, 5-10 cm) to capture surface management impacts
FINE_SCALE_DEPTHS_GRASSLAND <- c(0, 5, 10, 15, 20, 25, 30, 40, 50, 75, 100)

# SHALLOW DEPTH INTERVALS (for grazing/management impact assessment)
SHALLOW_DEPTH_INTERVALS <- data.frame(
  depth_top = c(0, 5, 10),
  depth_bottom = c(5, 10, 15),
  depth_midpoint = c(2.5, 7.5, 12.5),
  thickness_cm = c(5, 5, 5)
)

# Standard depths for harmonization (GRASSLAND midpoints are default)
STANDARD_DEPTHS <- GRASSLAND_DEPTH_MIDPOINTS

# Fine-scale depth intervals (optional, for detailed analysis)
FINE_SCALE_DEPTHS <- FINE_SCALE_DEPTHS_GRASSLAND

# Maximum core depth (cm) - grassland standard
MAX_CORE_DEPTH <- 100

# Key depth intervals for reporting (cm) - GRASSLAND FOCUS
REPORTING_DEPTHS <- list(
  primary = c(0, 30),        # Top 30 cm (PRIMARY for management effects, VM0026/VM0032)
  full_profile = c(0, 100),  # Full profile (0-100 cm for comprehensive accounting)
  deep_storage = c(30, 100)  # Deep storage (minimal management effect)
)

# ============================================================================
# COORDINATE SYSTEMS - CANADIAN GRASSLAND REGIONS
# ============================================================================

# Input CRS (usually WGS84 for GPS data)
INPUT_CRS <- 4326  # EPSG:4326 (WGS84)

# Processing CRS (projected, equal-area for accurate calculations)
# ALBERTA-SPECIFIC (update for your province):
PROCESSING_CRS <- 3400  # EPSG:3400 NAD83(CSRS) / Alberta 10-TM (Resource)

# PROVINCIAL CRS OPTIONS:
#
# ALBERTA (choose based on project location):
#   - 3400: NAD83(CSRS) / Alberta 10-TM (Resource) - RECOMMENDED for AB grasslands
#   - 3402: NAD83(CSRS) / Alberta 10-TM (Forest) - Northern AB
#   - 32612: WGS84 / UTM zone 12N - Southern AB
#
# SASKATCHEWAN:
#   - 2955: NAD83(CSRS) / UTM zone 13N - RECOMMENDED for SK grasslands
#   - 2151: NAD83(CSRS) / Saskatchewan Central
#
# MANITOBA:
#   - 2957: NAD83(CSRS) / UTM zone 14N - RECOMMENDED for MB grasslands
#   - 3158: NAD83(CSRS) / UTM zone 15N - Eastern MB
#
# MULTI-PROVINCE or NATIONAL:
#   - 3347: Canada Albers Equal Area - Best for projects spanning provinces
#
# For carbon accounting, use equal-area projections to ensure accurate area calculations

# ============================================================================
# BULK DENSITY DEFAULTS BY GRASSLAND STRATUM
# ============================================================================
# Use these when bulk density is not measured
# Values in g/cm³ based on Canadian grassland literature

BD_DEFAULTS <- list(
  "Native Prairie" = 1.1,         # Low density, high organic matter, intact structure
  "Improved Pasture" = 1.3,       # Moderate compaction from grazing
  "Degraded Grassland" = 1.4,     # High compaction, overgrazed, reduced OM
  "Restored Grassland" = 1.2,     # Recovering structure, moderate OM
  "Riparian Grassland" = 1.0      # Lower density, high moisture, organic accumulation
)

# Bulk density depth gradients (optional refinement)
# Grassland soils typically show increasing BD with depth
BD_DEPTH_ADJUSTMENT <- data.frame(
  depth_cm = c(7.5, 22.5, 40, 75),
  bd_multiplier = c(1.0, 1.05, 1.10, 1.15)  # 0-15% increase with depth
)

# ============================================================================
# QUALITY CONTROL THRESHOLDS - GRASSLAND SOILS
# ============================================================================

# Soil Organic Carbon (SOC) thresholds (g/kg)
# Grassland range: typically 10-150 g/kg (lower than wetlands, higher than cropland)
QC_SOC_MIN <- 10     # Minimum valid SOC (degraded grassland lower bound)
QC_SOC_MAX <- 150    # Maximum valid SOC (native prairie/riparian upper bound)

# Bulk Density thresholds (g/cm³)
# Grassland range: 0.8-1.6 g/cm³ (higher than wetlands, soil compaction common)
QC_BD_MIN <- 0.8     # Minimum valid bulk density (organic-rich riparian)
QC_BD_MAX <- 1.6     # Maximum valid bulk density (heavily compacted degraded grassland)

# Depth thresholds (cm)
QC_DEPTH_MIN <- 0
QC_DEPTH_MAX <- MAX_CORE_DEPTH

# Coordinate validity (decimal degrees for WGS84)
# Restricted to Canadian Prairie region
QC_LON_MIN <- -120   # Western AB
QC_LON_MAX <- -95    # Eastern MB
QC_LAT_MIN <- 49     # US border
QC_LAT_MAX <- 60     # Northern limit

# ============================================================================
# GRASSLAND CARBON VERIFICATION STANDARDS
# ============================================================================

# PRIMARY VERIFICATION STANDARDS (replaces VM0033)
# Multiple standards may apply depending on project type

# VCS VM0026 - Avoided Grassland Conversion
VM0026_ENABLED <- TRUE
VM0026_MIN_CORES <- 5  # Minimum cores per stratum

# VCS VM0032 - Improved Grassland Management
VM0032_ENABLED <- TRUE
VM0032_MIN_CORES <- 5

# VCS VM0042 - Improved Agricultural Land Management
VM0042_ENABLED <- TRUE
VM0042_MIN_CORES <- 5

# Alberta TIER (Technology Innovation and Emissions Reduction) Offset Protocols
ALBERTA_TIER_ENABLED <- TRUE
ALBERTA_TIER_MIN_CORES <- 3

# Canadian Agricultural GHG Methodology (IPCC Tier 3)
CANADA_IPCC_TIER3_ENABLED <- TRUE

# Target precision (acceptable range: 10-20% relative error at 95% CI)
GRASSLAND_TARGET_PRECISION <- 20  # percent

# Target CV threshold (higher CV = higher uncertainty)
GRASSLAND_CV_THRESHOLD <- 30  # percent

# Assumed CV for sample size calculation (conservative estimate)
GRASSLAND_ASSUMED_CV <- 35  # percent (higher than marine systems due to management variability)

# COMPATIBILITY ALIASES: Module integration
# These ensure existing blue carbon modules work seamlessly with grassland config
VM0033_MIN_CORES <- max(VM0026_MIN_CORES, VM0032_MIN_CORES, VM0042_MIN_CORES)  # Use strictest requirement
VM0033_TARGET_PRECISION <- GRASSLAND_TARGET_PRECISION
VM0033_ASSUMED_CV <- GRASSLAND_ASSUMED_CV
VM0033_CV_THRESHOLD <- GRASSLAND_CV_THRESHOLD
VM0033_MONITORING_FREQUENCY <- GRASSLAND_MONITORING_FREQUENCY

# ============================================================================
# CANADIAN GRASSLAND DATA SOURCES
# ============================================================================

# Agriculture and Agri-Food Canada (AAFC) Soil Organic Carbon Database
AAFC_SOC_DATABASE <- "https://sis.agr.gc.ca/cansis/nsdb/soc/index.html"

# Canadian Soil Information Service (CanSIS)
CANSIS_DATABASE <- "https://sis.agr.gc.ca/cansis/"

# Provincial grassland inventories
ALBERTA_GRASSLAND_INVENTORY <- "https://www.albertaparks.ca/media/6255792/agvi-overview.pdf"
SASKATCHEWAN_PRAIRIE_CONSERVATION <- "https://www.saskatoonprairieconservation.com/"
MANITOBA_SOIL_SURVEY <- "https://www.gov.mb.ca/agriculture/environment/soil-survey/"

# Canadian Forest Service National Forest Inventory
NFIS_DATABASE <- "https://nfi.nfis.org/"

# ============================================================================
# GRASSLAND-SPECIFIC VARIABLES TO COLLECT
# ============================================================================

# GRAZING MANAGEMENT VARIABLES (required for VM0032)
GRAZING_VARIABLES <- c(
  "grazing_history",        # Text: grazing timeline
  "stocking_rate_AUM",      # Numeric: Animal Unit Months per ha
  "grazing_system",         # Factor: continuous, rotational, seasonal
  "rest_period_days",       # Numeric: days of rest per year
  "grazing_intensity"       # Factor: light, moderate, heavy
)

# SPECIES COMPOSITION VARIABLES (required for VM0026)
SPECIES_VARIABLES <- c(
  "native_species_pct",     # Numeric: % cover native species
  "C3_grass_pct",          # Numeric: % C3 grasses
  "C4_grass_pct",          # Numeric: % C4 grasses
  "forb_pct",              # Numeric: % forbs
  "shrub_pct",             # Numeric: % shrubs
  "invasive_species_pct"   # Numeric: % invasive species
)

# SOIL TEXTURE VARIABLES (crucial for C stability)
SOIL_TEXTURE_VARIABLES <- c(
  "clay_pct",              # Numeric: % clay (crucial for SOC protection)
  "silt_pct",              # Numeric: % silt
  "sand_pct",              # Numeric: % sand
  "texture_class"          # Factor: clay, clay loam, loam, sandy loam, etc.
)

# ROOT BIOMASS VARIABLES (optional but recommended)
ROOT_VARIABLES <- c(
  "root_biomass_0_30cm",   # Numeric: g/m² root biomass
  "root_shoot_ratio",      # Numeric: ratio of below to aboveground biomass
  "fine_root_pct"          # Numeric: % fine roots (<2mm)
)

# MANAGEMENT HISTORY VARIABLES (required for additionality)
MANAGEMENT_VARIABLES <- c(
  "cultivation_history",    # Text: cultivation timeline
  "years_since_cultivation", # Numeric: years since last tillage
  "fertilization_history",  # Text: fertilizer application timeline
  "N_fertilizer_kg_ha_yr",  # Numeric: kg N/ha/yr applied
  "fire_history",           # Text: prescribed burn timeline
  "years_since_fire"        # Numeric: years since last fire
)

# ============================================================================
# REPORTING MODIFICATIONS - GRASSLAND STANDARDS
# ============================================================================

# Grazing management compliance checks (VM0032)
CHECK_GRAZING_COMPLIANCE <- TRUE
GRAZING_COMPLIANCE_THRESHOLDS <- list(
  max_stocking_rate_AUM = 8,        # Maximum AUM/ha (site-specific)
  min_rest_period_days = 60,        # Minimum rest period
  max_utilization_pct = 50          # Maximum forage utilization %
)

# Root biomass calculation (optional for comprehensive carbon accounting)
# Grasslands store 60-80% of carbon belowground
INCLUDE_ROOT_BIOMASS <- FALSE  # Set TRUE to add root carbon to total stocks

# Root:shoot ratio estimates (for full carbon accounting)
# Based on Canadian grassland literature
ROOT_SHOOT_RATIOS <- list(
  "Native Prairie" = 4.0,           # High belowground allocation (80% belowground)
  "Improved Pasture" = 2.5,         # Moderate belowground (71% belowground)
  "Degraded Grassland" = 1.5,       # Reduced root biomass (60% belowground)
  "Restored Grassland" = 3.0,       # Recovering root systems (75% belowground)
  "Riparian Grassland" = 3.5        # High productivity (78% belowground)
)

# Root carbon concentration (% of root biomass that is carbon)
ROOT_CARBON_CONCENTRATION <- 0.42  # 42% (typical for grassland roots)

# Root biomass sampling depth (cm)
ROOT_BIOMASS_DEPTH <- 30  # Focus on top 30 cm where most roots occur

# Root biomass calculation method
ROOT_BIOMASS_METHOD <- "ratio"  # Options: "ratio" (from shoot biomass), "direct" (measured)

# If using "direct" method, root biomass should be in core_samples.csv as "root_biomass_g_m2"
# If using "ratio" method, aboveground biomass (ANPP) needed in core_locations.csv

# Canadian agricultural baseline scenarios (for additionality)
BASELINE_SCENARIOS <- c(
  "Cropland_Conventional",          # Conventional tillage cropland
  "Cropland_Conservation",          # No-till/reduced tillage
  "Pasture_Degraded",               # Overgrazed pasture
  "Native_Prairie_Reference"        # Reference condition
)

# TIER offset system compatibility
TIER_REPORTING_ENABLED <- TRUE
TIER_CREDITING_PERIOD_YEARS <- 8  # Alberta TIER offset crediting period

# ============================================================================
# SPATIAL COVARIATES - GRASSLAND ECOSYSTEMS
# ============================================================================

# Replace marine covariates with grassland-relevant environmental variables

# CLIMATE COVARIATES (high importance for grassland SOC)
CLIMATE_COVARIATES <- c(
  "growing_degree_days",            # Annual GDD (base 5°C)
  "precipitation_annual_mm",        # Total annual precipitation
  "precipitation_growing_season_mm", # Apr-Sep precipitation
  "aridity_index",                  # Ratio precip/potential ET
  "frost_free_days",                # Length of growing season
  "winter_snow_depth_cm"            # Snow cover (insulation)
)

# SOIL COVARIATES (critical for SOC prediction)
SOIL_COVARIATES <- c(
  "clay_content_pct",               # % clay (SOC protection)
  "soil_pH",                        # Soil pH
  "cation_exchange_capacity",       # CEC (nutrient retention)
  "available_water_capacity",       # AWC (moisture storage)
  "soil_depth_cm",                  # Soil depth to bedrock
  "parent_material"                 # Glacial till, lacustrine, etc.
)

# TOPOGRAPHIC COVARIATES
TOPOGRAPHIC_COVARIATES <- c(
  "elevation_m",                    # Elevation above sea level
  "slope_percent",                  # Slope gradient
  "aspect_degrees",                 # Slope aspect
  "topographic_wetness_index",      # TWI (moisture accumulation)
  "topographic_position_index",     # TPI (landscape position)
  "solar_radiation_annual"          # Annual solar radiation
)

# LAND USE COVARIATES (management history)
LAND_USE_COVARIATES <- c(
  "years_since_conversion",         # Time since cropland → grassland
  "land_use_intensity_index",       # Composite management intensity
  "distance_to_water_m",            # Distance to nearest water body
  "distance_to_road_m"              # Distance to roads (disturbance proxy)
)

# VEGETATION COVARIATES (remote sensing)
VEGETATION_COVARIATES <- c(
  "NDVI_median",                    # Normalized Difference Vegetation Index
  "NDVI_max",                       # Peak greenness
  "NDVI_std",                       # Temporal variability
  "EVI_median",                     # Enhanced Vegetation Index
  "NBR_median",                     # Normalized Burn Ratio
  "SAVI_median",                    # Soil-Adjusted Vegetation Index
  "NDVI_integral",                  # Annual productivity proxy
  "greenup_day",                    # Start of growing season
  "senescence_day"                  # End of growing season
)

# MINIMUM REQUIRED COVARIATES (for basic modeling)
MINIMUM_COVARIATES <- c(
  "NDVI_median",
  "elevation_m",
  "precipitation_annual_mm",
  "growing_degree_days",
  "clay_content_pct"
)

# ============================================================================
# TEMPORAL MONITORING & ADDITIONALITY PARAMETERS
# ============================================================================

# Valid scenario types for Grassland Carbon Accounting
# Core scenarios:
# - BASELINE: Pre-project or current conventional management (t0)
# - DEGRADED: Heavily degraded grassland (lower bound)
# - NATIVE: Native prairie reference (upper bound target)
# - CONTROL: No-intervention control site
# Grassland management scenarios:
# - PROJECT_IMPROVED: Improved grazing management
# - PROJECT_RESTORED: Cropland to grassland restoration
# - PROJECT_CONSERVED: Avoided conversion to cropland
# - CROPLAND: Cropland baseline (for restoration projects)
VALID_SCENARIOS <- c("BASELINE", "DEGRADED", "NATIVE", "CONTROL",
                     "PROJECT", "PROJECT_IMPROVED", "PROJECT_RESTORED",
                     "PROJECT_CONSERVED", "CROPLAND", "CUSTOM")

# Scenario hierarchy for modeling (relative carbon stock levels)
# Based on Canadian grassland literature
SCENARIO_CARBON_LEVELS <- c(
  CROPLAND = 1.0,           # Lowest SOC (30-40 Mg C/ha 0-30cm)
  DEGRADED = 2.0,           # Degraded grassland (35-45 Mg C/ha)
  BASELINE = 3.0,           # Conventional pasture (40-50 Mg C/ha)
  PROJECT_CONSERVED = 4.0,  # Avoided conversion (45-55 Mg C/ha)
  PROJECT_IMPROVED = 5.0,   # Improved management (50-60 Mg C/ha)
  PROJECT_RESTORED = 6.0,   # Restored grassland (55-65 Mg C/ha)
  NATIVE = 7.0              # Native prairie reference (60-80 Mg C/ha)
)

# Minimum monitoring frequency (years)
GRASSLAND_MONITORING_FREQUENCY <- 5  # VM0026/VM0032 typically 5 years

# Minimum years for temporal change analysis
MIN_YEARS_FOR_CHANGE <- 3

# Additionality test confidence level
ADDITIONALITY_CONFIDENCE <- 0.95  # 95% CI

# Conservative approach for additionality calculations
ADDITIONALITY_METHOD <- "lower_bound"  # VM0026/VM0032/VM0042 recommended

# ============================================================================
# SCENARIO MODELING PARAMETERS
# ============================================================================

SCENARIO_MODELING_ENABLED <- TRUE

# Canadian grassland literature database
CANADIAN_GRASSLAND_LITERATURE_DB <- "canadian_grassland_parameters.csv"

# Scenario modeling configuration
SCENARIO_CONFIG_FILE <- "grassland_scenario_config.csv"

# Recovery model for grassland restoration
# Grassland SOC recovery is typically slow (10-50 years)
RECOVERY_MODEL_TYPE <- "exponential"  # Slow asymptotic approach to native prairie

# Uncertainty inflation for modeled scenarios
MODELING_UNCERTAINTY_BUFFER <- 15  # percent (higher than marine due to management variability)

# ============================================================================
# BAYESIAN PRIOR PARAMETERS (Optional)
# ============================================================================

USE_BAYESIAN <- FALSE

# GEE Data Sources (Canadian Grassland)
# SoilGrids 250m
GEE_SOILGRIDS_ASSET <- "projects/soilgrids-isric/soc_mean"
GEE_SOILGRIDS_UNCERTAINTY <- "projects/soilgrids-isric/soc_uncertainty"

# Canadian Soil Carbon Database (if available as GEE asset)
GEE_CANSIS_SOC <- ""  # User to provide if available

# AAFC Annual Crop Inventory (land use)
GEE_AAFC_CROP_INVENTORY <- "projects/sat-io/open-datasets/AAFC/annual_crop_inventory"

# ============================================================================
# DEPTH HARMONIZATION PARAMETERS
# ============================================================================

INTERPOLATION_METHOD <- "equal_area_spline"

# Spline smoothing parameters
SPLINE_SPAR_GRASSLAND <- 0.4    # Moderate smoothing for grassland profiles
SPLINE_SPAR_AUTO <- NULL

# Monotonicity parameters (grassland soils typically decrease with depth)
ALLOW_DEPTH_INCREASES <- FALSE  # Grassland SOC typically decreases monotonically
MAX_INCREASE_THRESHOLD <- 10    # Maximum % increase allowed (conservative)

# ============================================================================
# UNCERTAINTY PARAMETERS
# ============================================================================

CONFIDENCE_LEVEL <- 0.95

# Bootstrap parameters
BOOTSTRAP_ITERATIONS <- 100
BOOTSTRAP_SEED <- 42

# Cross-validation parameters
CV_FOLDS <- 5           # Higher folds for grassland (often larger sample sizes)
CV_SEED <- 42

# ============================================================================
# SPATIAL MODELING PARAMETERS
# ============================================================================

# Prediction resolution (meters) - grassland typically larger areas
KRIGING_CELL_SIZE <- 30  # Coarser than marine (grasslands more homogeneous)
RF_CELL_SIZE <- 30

# Kriging parameters
KRIGING_MAX_DISTANCE <- 10000  # Larger than marine (prairie landscapes)
KRIGING_CUTOFF <- NULL
KRIGING_WIDTH <- 500           # Larger lag width

# Random Forest parameters
RF_NTREE <- 500
RF_MTRY <- NULL
RF_MIN_NODE_SIZE <- 5
RF_IMPORTANCE <- "permutation"

# ============================================================================
# AREA OF APPLICABILITY (AOA) PARAMETERS
# ============================================================================

ENABLE_AOA <- TRUE
AOA_THRESHOLD <- "default"

# ============================================================================
# REPORT GENERATION PARAMETERS
# ============================================================================

FIGURE_WIDTH <- 10
FIGURE_HEIGHT <- 6
FIGURE_DPI <- 300

TABLE_DIGITS <- 2

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

#' Convert between carbon stock units
#'
#' @param value Numeric value to convert
#' @param from Source unit (kg_m2, Mg_ha, g_kg, pct)
#' @param to Target unit
#' @return Converted value
#' @examples
#' convert_units(1, "kg_m2", "Mg_ha")  # Returns 10
#' convert_units(10, "Mg_ha", "kg_m2") # Returns 1
convert_units <- function(value, from, to) {
  conversions <- list(
    "kg_m2_to_Mg_ha" = 10,
    "Mg_ha_to_kg_m2" = 0.1,
    "g_kg_to_pct" = 0.1,
    "pct_to_g_kg" = 10
  )

  key <- paste(from, "to", to, sep = "_")
  if (key %in% names(conversions)) {
    return(value * conversions[[key]])
  } else {
    stop(sprintf("Unknown conversion: %s to %s", from, to))
  }
}

# ============================================================================
# SESSION TRACKING
# ============================================================================

SESSION_START <- Sys.time()
SESSION_ID <- format(SESSION_START, "%Y%m%d_%H%M%S")

# ============================================================================
# END OF CONFIGURATION
# ============================================================================

# Print confirmation when loaded
if (interactive()) {
  cat("Canadian Grassland Carbon configuration loaded ✓\n")
  cat(sprintf("  Project: %s\n", PROJECT_NAME))
  cat(sprintf("  Location: %s\n", PROJECT_LOCATION))
  cat(sprintf("  Scenario: %s\n", PROJECT_SCENARIO))
  cat(sprintf("  Monitoring year: %d\n", MONITORING_YEAR))
  cat(sprintf("  Session ID: %s\n", SESSION_ID))
  cat("  Standards: VM0026, VM0032, VM0042, Alberta TIER\n")
}
