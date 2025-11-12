# ============================================================================
# MODULE 01: BLUE CARBON DATA PREPARATION
# ============================================================================
# PURPOSE: Load, clean, validate, and structure core data for MMRV
# INPUTS: 
#   - data_raw/core_locations.csv (GPS + stratum assignments)
#   - data_raw/core_samples.csv (depth profiles + SOC)
# OUTPUTS: 
#   - data_processed/cores_clean_bluecarbon.rds
#   - data_processed/cores_summary_by_stratum.csv
# ============================================================================

# ============================================================================
# SETUP
# ============================================================================

# Load configuration
if (file.exists("blue_carbon_config.R")) {
  source("blue_carbon_config.R")
} else {
  stop("Configuration file not found. Run 00_setup_bluecarbon.R first.")
}

# Initialize logging
log_file <- file.path("logs", paste0("data_prep_", Sys.Date(), ".log"))
if (!dir.exists("logs")) dir.create("logs")

log_message <- function(msg, level = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  log_entry <- sprintf("[%s] %s: %s", timestamp, level, msg)
  cat(log_entry, "\n")
  cat(log_entry, "\n", file = log_file, append = TRUE)
}

log_message("=== MODULE 01: BLUE CARBON DATA PREPARATION ===")

# Load packages
suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(sf)
})

log_message("Packages loaded successfully")

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

#' Validate stratum names against valid list
validate_strata <- function(strata_vector, valid_strata = VALID_STRATA) {
  invalid <- setdiff(unique(strata_vector), valid_strata)
  if (length(invalid) > 0) {
    warning(sprintf("Invalid strata detected: %s", paste(invalid, collapse = ", ")))
    cat("\nValid strata options:\n")
    for (s in valid_strata) {
      cat("  -", s, "\n")
    }
    return(FALSE)
  }
  return(TRUE)
}

#' Calculate SOC stock for a depth increment
calculate_soc_stock <- function(soc_g_kg, bd_g_cm3, depth_top_cm, depth_bottom_cm) {
  # SOC stock (Mg/ha) = SOC (g/kg) / 1000 × BD (g/cm³) × depth (cm) × 100
  soc_prop <- soc_g_kg / 1000
  depth_increment <- depth_bottom_cm - depth_top_cm
  soc_stock <- soc_prop * bd_g_cm3 * depth_increment * 100
  return(soc_stock)
}

#' Assign bulk density defaults by stratum if missing
assign_bd_defaults <- function(df, bd_col = "bulk_density_g_cm3", 
                               stratum_col = "stratum") {
  df[[bd_col]] <- ifelse(
    is.na(df[[bd_col]]),
    sapply(df[[stratum_col]], function(s) {
      if (s %in% names(BD_DEFAULTS)) {
        BD_DEFAULTS[[s]]
      } else {
        1.0  # Generic default
      }
    }),
    df[[bd_col]]
  )
  return(df)
}

# ============================================================================
# LOAD CORE LOCATIONS
# ============================================================================

log_message("Loading core locations...")

locations_file <- "data_raw/core_locations.csv"

if (!file.exists(locations_file)) {
  stop(paste("Core locations file not found:", locations_file))
}

# Load with column name standardization
locations <- read_csv(locations_file, show_col_types = FALSE) %>%
  rename_with(tolower)

log_message(sprintf("Loaded %d core locations", nrow(locations)))

# Check required columns
required_cols_locations <- c("core_id", "longitude", "latitude", "stratum")
missing_cols <- setdiff(required_cols_locations, names(locations))

if (length(missing_cols) > 0) {
  stop(sprintf("Missing required columns in locations: %s", 
               paste(missing_cols, collapse = ", ")))
}

# Validate coordinates
locations <- locations %>%
  filter(!is.na(longitude) & !is.na(latitude)) %>%
  filter(longitude >= -180 & longitude <= 180) %>%
  filter(latitude >= -90 & latitude <= 90)

log_message(sprintf("After coordinate validation: %d cores", nrow(locations)))

# Validate strata
if (!validate_strata(locations$stratum)) {
  stop("Invalid stratum names detected. Please fix in source data.")
}

# Add VM0033 metadata if not present
if (!"scenario_type" %in% names(locations)) {
  locations$scenario_type <- PROJECT_SCENARIO
  log_message("Added scenario_type from config")
}

if (!"monitoring_year" %in% names(locations)) {
  locations$monitoring_year <- MONITORING_YEAR
  log_message("Added monitoring_year from config")
}

# Ensure core_type exists
if (!"core_type" %in% names(locations)) {
  locations$core_type <- "unknown"
  log_message("core_type not specified, set to 'unknown'", "WARNING")
}

# Convert to spatial object
locations_sf <- st_as_sf(locations, 
                         coords = c("longitude", "latitude"),
                         crs = INPUT_CRS,
                         remove = FALSE)

# Transform to processing CRS
locations_sf <- st_transform(locations_sf, PROCESSING_CRS)

log_message(sprintf("Created spatial object with CRS %d", PROCESSING_CRS))

# ============================================================================
# LOAD CORE SAMPLES
# ============================================================================

log_message("Loading core samples...")

samples_file <- "data_raw/core_samples.csv"

if (!file.exists(samples_file)) {
  stop(paste("Core samples file not found:", samples_file))
}

# Load with column name standardization
samples <- read_csv(samples_file, show_col_types = FALSE) %>%
  rename_with(tolower)

log_message(sprintf("Loaded %d samples", nrow(samples)))

# Check required columns
required_cols_samples <- c("core_id", "depth_top_cm", "depth_bottom_cm", "soc_g_kg")
missing_cols <- setdiff(required_cols_samples, names(samples))

if (length(missing_cols) > 0) {
  stop(sprintf("Missing required columns in samples: %s", 
               paste(missing_cols, collapse = ", ")))
}

# Calculate depth midpoint
samples <- samples %>%
  mutate(
    depth_cm = (depth_top_cm + depth_bottom_cm) / 2,
    interval_thickness_cm = depth_bottom_cm - depth_top_cm
  )

log_message("Calculated depth midpoints and interval thickness")

# ============================================================================
# DATA QUALITY CHECKS
# ============================================================================

log_message("Running quality checks...")

# Initialize QA flags
samples <- samples %>%
  mutate(
    qa_depth_valid = depth_top_cm >= 0 & 
                     depth_top_cm < depth_bottom_cm &
                     depth_bottom_cm <= MAX_CORE_DEPTH,
    
    qa_soc_valid = !is.na(soc_g_kg) & 
                   soc_g_kg >= QC_SOC_MIN & 
                   soc_g_kg <= QC_SOC_MAX
  )

# Check bulk density if present
if ("bulk_density_g_cm3" %in% names(samples)) {
  samples <- samples %>%
    mutate(
      qa_bd_valid = is.na(bulk_density_g_cm3) | 
                    (bulk_density_g_cm3 >= QC_BD_MIN & 
                     bulk_density_g_cm3 <= QC_BD_MAX),
      bd_measured = !is.na(bulk_density_g_cm3)
    )
} else {
  log_message("No bulk_density_g_cm3 column - will use defaults", "WARNING")
  samples$bulk_density_g_cm3 <- NA
  samples$qa_bd_valid <- TRUE
  samples$bd_measured <- FALSE
}

# Report QA results
n_depth_invalid <- sum(!samples$qa_depth_valid)
n_soc_invalid <- sum(!samples$qa_soc_valid)
n_bd_invalid <- sum(!samples$qa_bd_valid)

if (n_depth_invalid > 0) {
  log_message(sprintf("Invalid depths: %d samples", n_depth_invalid), "WARNING")
}
if (n_soc_invalid > 0) {
  log_message(sprintf("Invalid SOC values: %d samples", n_soc_invalid), "WARNING")
}
if (n_bd_invalid > 0) {
  log_message(sprintf("Invalid BD values: %d samples", n_bd_invalid), "WARNING")
}

# Filter to valid samples only
samples_clean <- samples %>%
  filter(qa_depth_valid & qa_soc_valid & qa_bd_valid)

log_message(sprintf("After QA: %d samples retained from %d cores",
                    nrow(samples_clean),
                    n_distinct(samples_clean$core_id)))

# ============================================================================
# MERGE LOCATIONS WITH SAMPLES
# ============================================================================

log_message("Merging locations with samples...")

# Drop geometry for merging (we'll add it back)
locations_df <- locations_sf %>%
  st_drop_geometry()

# Merge
cores_merged <- samples_clean %>%
  left_join(locations_df, by = "core_id")

# Check for cores without locations
cores_no_location <- samples_clean %>%
  anti_join(locations_df, by = "core_id") %>%
  pull(core_id) %>%
  unique()

if (length(cores_no_location) > 0) {
  log_message(sprintf("Warning: %d cores have samples but no location", 
                      length(cores_no_location)), "WARNING")
  log_message(sprintf("Missing cores: %s", 
                      paste(head(cores_no_location, 5), collapse = ", ")))
}

# Check for locations without samples
cores_no_samples <- locations_df %>%
  anti_join(samples_clean, by = "core_id") %>%
  pull(core_id) %>%
  unique()

if (length(cores_no_samples) > 0) {
  log_message(sprintf("Warning: %d cores have location but no samples",
                      length(cores_no_samples)), "WARNING")
}

# Filter to complete cases only
cores_complete <- cores_merged %>%
  filter(!is.na(longitude) & !is.na(latitude) & !is.na(stratum))

log_message(sprintf("Complete dataset: %d samples from %d cores",
                    nrow(cores_complete),
                    n_distinct(cores_complete$core_id)))

# ============================================================================
# STRATUM VALIDATION AND STATISTICS
# ============================================================================

log_message("Validating stratum assignments...")

# Validate all strata
if (!validate_strata(cores_complete$stratum)) {
  stop("Invalid stratum assignments in merged data")
}

# Calculate stratum statistics
stratum_stats <- cores_complete %>%
  group_by(stratum) %>%
  summarise(
    n_cores = n_distinct(core_id),
    n_samples = n(),
    mean_depth = mean(depth_cm),
    max_depth = max(depth_cm),
    mean_soc = mean(soc_g_kg, na.rm = TRUE),
    sd_soc = sd(soc_g_kg, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(n_cores))

log_message("Stratum summary:")
print(stratum_stats)

# Save stratum summary
write_csv(stratum_stats, "data_processed/cores_summary_by_stratum.csv")
log_message("Saved stratum summary")

# ============================================================================
# BULK DENSITY HANDLING
# ============================================================================

log_message("Handling bulk density...")

n_bd_missing <- sum(is.na(cores_complete$bulk_density_g_cm3))
n_bd_measured <- sum(!is.na(cores_complete$bulk_density_g_cm3))

log_message(sprintf("BD measured: %d samples", n_bd_measured))
log_message(sprintf("BD missing: %d samples", n_bd_missing))

if (n_bd_missing > 0) {
  log_message("Applying stratum-specific BD defaults to missing values")
  
  # Show defaults being applied
  cat("\nBulk density defaults by stratum:\n")
  for (s in names(BD_DEFAULTS)) {
    cat(sprintf("  %s: %.2f g/cm³\n", s, BD_DEFAULTS[[s]]))
  }
  
  cores_complete <- assign_bd_defaults(cores_complete)
  
  # Flag which samples have estimated BD
  cores_complete <- cores_complete %>%
    mutate(bd_estimated = !bd_measured)
}

# ============================================================================
# CALCULATE CARBON STOCKS
# ============================================================================

log_message("Calculating carbon stocks...")

cores_complete <- cores_complete %>%
  mutate(
    # Carbon stock per sample (Mg C/ha)
    carbon_stock_mg_ha = calculate_soc_stock(
      soc_g_kg, 
      bulk_density_g_cm3, 
      depth_top_cm, 
      depth_bottom_cm
    )
  )

# Calculate total stocks per core
core_totals <- cores_complete %>%
  group_by(core_id, stratum) %>%
  summarise(
    total_carbon_stock = sum(carbon_stock_mg_ha, na.rm = TRUE),
    max_depth_sampled = max(depth_bottom_cm),
    n_samples = n(),
    .groups = "drop"
  )

log_message(sprintf("Calculated carbon stocks for %d cores", nrow(core_totals)))

# Summary by stratum
carbon_by_stratum <- core_totals %>%
  group_by(stratum) %>%
  summarise(
    n_cores = n(),
    mean_stock = mean(total_carbon_stock),
    sd_stock = sd(total_carbon_stock),
    min_stock = min(total_carbon_stock),
    max_stock = max(total_carbon_stock),
    .groups = "drop"
  )

log_message("Carbon stock summary by stratum:")
print(carbon_by_stratum)

# ============================================================================
# ADD FINAL QA FLAGS
# ============================================================================

log_message("Adding final QA flags...")

cores_complete <- cores_complete %>%
  mutate(
    # Spatial validity
    qa_spatial_valid = !is.na(longitude) & !is.na(latitude),
    
    # Stratum validity
    qa_stratum_valid = stratum %in% VALID_STRATA,
    
    # Overall QA pass
    qa_pass = qa_spatial_valid & qa_depth_valid & qa_soc_valid & 
              qa_bd_valid & qa_stratum_valid,
    
    # Sample ID
    sample_id = paste0(core_id, "_", sprintf("%03d", row_number()))
  )

n_pass <- sum(cores_complete$qa_pass)
n_fail <- sum(!cores_complete$qa_pass)

log_message(sprintf("Final QA: %d samples passed, %d failed", n_pass, n_fail))

# ============================================================================
# EXPORT CLEANED DATA
# ============================================================================

log_message("Exporting cleaned data...")

# Save as RDS (preserves data types)
saveRDS(cores_complete, "data_processed/cores_clean_bluecarbon.rds")
log_message("Saved: cores_clean_bluecarbon.rds")

# Save as CSV (portable)
write_csv(cores_complete, "data_processed/cores_clean_bluecarbon.csv")
log_message("Saved: cores_clean_bluecarbon.csv")

# Save core totals
saveRDS(core_totals, "data_processed/core_totals.rds")
write_csv(core_totals, "data_processed/core_totals.csv")
log_message("Saved: core_totals")

# Save carbon by stratum summary
write_csv(carbon_by_stratum, "data_processed/carbon_by_stratum_summary.csv")
log_message("Saved: carbon_by_stratum_summary.csv")

# ============================================================================
# GENERATE QA REPORT
# ============================================================================

log_message("Generating QA report...")

qa_report <- list(
  # Overall statistics
  total_cores = n_distinct(cores_complete$core_id),
  total_samples = nrow(cores_complete),
  samples_passed_qa = n_pass,
  samples_failed_qa = n_fail,
  
  # By stratum
  cores_by_stratum = stratum_stats,
  carbon_by_stratum = carbon_by_stratum,
  
  # Bulk density
  bd_measured = n_bd_measured,
  bd_estimated = n_bd_missing,
  
  # QA flags
  qa_issues = list(
    invalid_depths = n_depth_invalid,
    invalid_soc = n_soc_invalid,
    invalid_bd = n_bd_invalid,
    cores_no_location = length(cores_no_location),
    cores_no_samples = length(cores_no_samples)
  ),
  
  # Metadata
  processing_date = Sys.Date(),
  project_name = PROJECT_NAME,
  scenario_type = PROJECT_SCENARIO,
  monitoring_year = MONITORING_YEAR
)

saveRDS(qa_report, "data_processed/qa_report.rds")
log_message("Saved: qa_report.rds")

# ============================================================================
# FINAL SUMMARY
# ============================================================================

cat("\n========================================\n")
cat("MODULE 01 COMPLETE\n")
cat("========================================\n\n")

cat("Data Summary:\n")
cat("----------------------------------------\n")
cat(sprintf("Cores processed: %d\n", n_distinct(cores_complete$core_id)))
cat(sprintf("Samples processed: %d\n", nrow(cores_complete)))
cat(sprintf("QA pass rate: %.1f%%\n", 100 * n_pass / nrow(cores_complete)))
cat(sprintf("\nStrata represented: %d\n", n_distinct(cores_complete$stratum)))

cat("\nSamples by stratum:\n")
for (i in 1:nrow(stratum_stats)) {
  cat(sprintf("  %s: %d cores, %d samples\n", 
              stratum_stats$stratum[i],
              stratum_stats$n_cores[i],
              stratum_stats$n_samples[i]))
}

cat("\nBulk density:\n")
cat(sprintf("  Measured: %d samples\n", n_bd_measured))
cat(sprintf("  Estimated: %d samples\n", n_bd_missing))

cat("\nOutputs saved to data_processed/\n")
cat("  - cores_clean_bluecarbon.rds\n")
cat("  - cores_clean_bluecarbon.csv\n")
cat("  - cores_summary_by_stratum.csv\n")
cat("  - carbon_by_stratum_summary.csv\n")
cat("  - qa_report.rds\n")

cat("\nNext steps:\n")
cat("  1. Review QA report and stratum summaries\n")
cat("  2. Run: source('02_exploratory_analysis_bluecarbon.R')\n\n")

log_message("=== MODULE 01 COMPLETE ===")
