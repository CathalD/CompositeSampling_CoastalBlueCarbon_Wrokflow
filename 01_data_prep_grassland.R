# ============================================================================
# MODULE 01: GRASSLAND CARBON DATA PREPARATION
# ============================================================================
# PURPOSE: Load, clean, validate, and structure core data for Canadian grassland MMRV
# INPUTS:
#   - data_raw/core_locations.csv (GPS + stratum assignments + grassland metadata)
#   - data_raw/core_samples.csv (depth profiles + SOC)
# OUTPUTS:
#   - data_processed/cores_clean_grassland.rds
#   - data_processed/cores_summary_by_stratum.csv
# ============================================================================

# ============================================================================
# SETUP
# ============================================================================

# Load configuration
if (file.exists("grassland_carbon_config.R")) {
  source("grassland_carbon_config.R")
} else {
  stop("Grassland configuration file not found. Create grassland_carbon_config.R first.")
}

# Initialize logging
log_file <- file.path("logs", paste0("data_prep_grassland_", Sys.Date(), ".log"))
if (!dir.exists("logs")) dir.create("logs")

log_message <- function(msg, level = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  log_entry <- sprintf("[%s] %s: %s", timestamp, level, msg)
  cat(log_entry, "\n")
  cat(log_entry, "\n", file = log_file, append = TRUE)
}

log_message("=== MODULE 01: GRASSLAND CARBON DATA PREPARATION ===")

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

#' Validate stratum names against valid grassland types
validate_strata <- function(strata_vector, valid_strata = VALID_STRATA) {
  invalid <- setdiff(unique(strata_vector), valid_strata)
  if (length(invalid) > 0) {
    warning(sprintf("Invalid grassland strata detected: %s", paste(invalid, collapse = ", ")))
    cat("\nValid Canadian grassland strata options:\n")
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

#' Assign bulk density defaults by grassland stratum if missing
assign_bd_defaults <- function(df, bd_col = "bulk_density_g_cm3",
                               stratum_col = "stratum") {
  df[[bd_col]] <- ifelse(
    is.na(df[[bd_col]]),
    sapply(df[[stratum_col]], function(s) {
      if (s %in% names(BD_DEFAULTS)) {
        BD_DEFAULTS[[s]]
      } else {
        1.15  # Generic grassland default
      }
    }),
    df[[bd_col]]
  )
  return(df)
}

#' Calculate required sample size for AAFC compliance
#' Based on: n = (z * CV / target_precision)^2
calculate_required_n <- function(cv, target_precision = AAFC_TARGET_PRECISION,
                                confidence = CONFIDENCE_LEVEL) {
  z <- qnorm(1 - (1 - confidence) / 2)  # 1.96 for 95% CI
  n <- ceiling((z * cv / target_precision)^2)
  return(max(n, AAFC_MIN_CORES))  # Ensure at least minimum
}

#' Calculate achieved precision from sample size and CV
calculate_achieved_precision <- function(n, cv, confidence = CONFIDENCE_LEVEL) {
  if (n < 2) return(NA)
  z <- qnorm(1 - (1 - confidence) / 2)
  precision <- (z * cv) / sqrt(n)
  return(precision)
}

#' Calculate depth profile completeness (0-100%)
calculate_profile_completeness <- function(depth_top, depth_bottom, max_depth = MAX_CORE_DEPTH) {
  # Calculate total depth sampled
  total_sampled <- sum(depth_bottom - depth_top, na.rm = TRUE)
  completeness_pct <- (total_sampled / max_depth) * 100
  return(min(completeness_pct, 100))  # Cap at 100%
}

# ============================================================================
# LOAD CORE LOCATIONS
# ============================================================================

log_message("Loading grassland core locations...")

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

# Validate coordinates (Canadian prairie range)
locations <- locations %>%
  filter(!is.na(longitude) & !is.na(latitude)) %>%
  filter(longitude >= QC_LON_MIN & longitude <= QC_LON_MAX) %>%
  filter(latitude >= QC_LAT_MIN & latitude <= QC_LAT_MAX)

log_message(sprintf("After coordinate validation: %d cores", nrow(locations)))

# Validate grassland strata
if (!validate_strata(locations$stratum)) {
  stop("Invalid grassland stratum names detected. Please fix in source data.")
}

# Add AAFC metadata if not present
if (!"scenario_type" %in% names(locations)) {
  locations$scenario_type <- PROJECT_SCENARIO
  log_message("Added scenario_type from config")
}

if (!"monitoring_year" %in% names(locations)) {
  locations$monitoring_year <- MONITORING_YEAR
  log_message("Added monitoring_year from config")
}

# Add grassland-specific fields if not present
if (!"grazing_history" %in% names(locations)) {
  locations$grazing_history <- "Unknown"
  log_message("grazing_history not specified, set to 'Unknown'", "WARNING")
}

if (!"fire_history" %in% names(locations)) {
  locations$fire_history <- "Unknown"
  log_message("fire_history not specified, set to 'Unknown'", "WARNING")
}

if (!"grass_type" %in% names(locations)) {
  locations$grass_type <- "Unknown"
  log_message("grass_type (native/seeded) not specified, set to 'Unknown'", "WARNING")
}

if (!"land_use" %in% names(locations)) {
  locations$land_use <- "Rangeland"
  log_message("land_use not specified, set to 'Rangeland'")
}

if (!"ecoregion" %in% names(locations)) {
  locations$ecoregion <- "Unknown"
  log_message("ecoregion not specified, set to 'Unknown'", "WARNING")
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

# Transform to Canada Albers Equal Area processing CRS
locations_sf <- st_transform(locations_sf, PROCESSING_CRS)

log_message(sprintf("Created spatial object with CRS %d (Canada Albers)", PROCESSING_CRS))

# ============================================================================
# LOAD CORE SAMPLES
# ============================================================================

log_message("Loading grassland core samples...")

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

# Check for grassland-specific optional field: root_biomass
if ("root_biomass_g_m2" %in% names(samples)) {
  log_message("Root biomass data detected")
  has_root_biomass <- TRUE
} else {
  log_message("No root biomass data provided (optional)", "INFO")
  has_root_biomass <- FALSE
}

log_message("Calculated depth midpoints and interval thickness")

# ============================================================================
# DATA QUALITY CHECKS (GRASSLAND THRESHOLDS)
# ============================================================================

log_message("Running quality checks with grassland-specific thresholds...")

# Initialize QA flags
samples <- samples %>%
  mutate(
    qa_depth_valid = depth_top_cm >= 0 &
                     depth_top_cm < depth_bottom_cm &
                     depth_bottom_cm <= MAX_CORE_DEPTH,

    qa_soc_valid = !is.na(soc_g_kg) &
                   soc_g_kg >= QC_SOC_MIN &
                   soc_g_kg <= QC_SOC_MAX  # 0-150 g/kg for grasslands
  )

# Check bulk density if present
if ("bulk_density_g_cm3" %in% names(samples)) {
  samples <- samples %>%
    mutate(
      qa_bd_valid = is.na(bulk_density_g_cm3) |
                    (bulk_density_g_cm3 >= QC_BD_MIN &
                     bulk_density_g_cm3 <= QC_BD_MAX),  # 0.5-2.0 for grasslands
      bd_measured = !is.na(bulk_density_g_cm3)
    )
} else {
  log_message("No bulk_density_g_cm3 column - will use grassland defaults", "WARNING")
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
  log_message(sprintf("Invalid SOC values (outside 0-150 g/kg): %d samples", n_soc_invalid), "WARNING")
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
# GRASSLAND STRATUM VALIDATION AND STATISTICS
# ============================================================================

log_message("Validating grassland stratum assignments...")

# Validate all strata
if (!validate_strata(cores_complete$stratum)) {
  stop("Invalid stratum assignments in merged data")
}

# Calculate stratum statistics with uncertainty metrics
stratum_stats <- cores_complete %>%
  group_by(stratum) %>%
  summarise(
    n_cores = n_distinct(core_id),
    n_samples = n(),
    mean_depth = mean(depth_cm),
    max_depth = max(depth_cm),
    mean_soc = mean(soc_g_kg, na.rm = TRUE),
    sd_soc = sd(soc_g_kg, na.rm = TRUE),
    cv_soc = (sd(soc_g_kg, na.rm = TRUE) / mean(soc_g_kg, na.rm = TRUE)) * 100,
    se_soc = sd(soc_g_kg, na.rm = TRUE) / sqrt(n()),
    .groups = "drop"
  ) %>%
  arrange(desc(n_cores))

log_message("Grassland stratum summary with uncertainty metrics:")
print(stratum_stats)

# Save stratum summary
write_csv(stratum_stats, "data_processed/cores_summary_by_stratum_grassland.csv")
log_message("Saved grassland stratum summary")

# ============================================================================
# AAFC SAMPLE SIZE VALIDATION & STATISTICAL POWER
# ============================================================================

log_message("Validating AAFC/Canadian protocol sample size requirements...")

# Calculate power analysis for each grassland stratum
aafc_compliance <- stratum_stats %>%
  mutate(
    # Check minimum sample size
    meets_min_n = n_cores >= AAFC_MIN_CORES,

    # Calculate required N for target precision
    required_n_20pct = mapply(calculate_required_n, cv_soc, 20, CONFIDENCE_LEVEL),
    required_n_15pct = mapply(calculate_required_n, cv_soc, 15, CONFIDENCE_LEVEL),
    required_n_10pct = mapply(calculate_required_n, cv_soc, 10, CONFIDENCE_LEVEL),

    # Calculate achieved precision with current n
    achieved_precision_pct = mapply(calculate_achieved_precision, n_cores, cv_soc, CONFIDENCE_LEVEL),

    # Additional cores needed for different precision targets
    additional_for_20pct = pmax(0, required_n_20pct - n_cores),
    additional_for_15pct = pmax(0, required_n_15pct - n_cores),
    additional_for_10pct = pmax(0, required_n_10pct - n_cores),

    # AAFC compliance flags
    meets_20pct_precision = achieved_precision_pct <= 20,
    meets_15pct_precision = achieved_precision_pct <= 15,
    meets_10pct_precision = achieved_precision_pct <= 10,

    # Overall compliance (min 3 cores AND ≤20% precision)
    aafc_compliant = meets_min_n & meets_20pct_precision,

    # Status assessment
    status = case_when(
      !meets_min_n ~ "INSUFFICIENT (< 3 cores)",
      achieved_precision_pct <= 10 ~ "EXCELLENT (≤10%)",
      achieved_precision_pct <= 15 ~ "GOOD (≤15%)",
      achieved_precision_pct <= 20 ~ "ACCEPTABLE (≤20%)",
      achieved_precision_pct <= 30 ~ "MARGINAL (>20%, <30%)",
      TRUE ~ "POOR (≥30%)"
    )
  )

cat("\n========================================\n")
cat("AAFC SAMPLE SIZE COMPLIANCE (Canadian Grasslands)\n")
cat("========================================\n\n")

# Print compliance by stratum
for (i in 1:nrow(aafc_compliance)) {
  cat(sprintf("Stratum: %s\n", aafc_compliance$stratum[i]))
  cat(sprintf("  Current samples: %d cores\n", aafc_compliance$n_cores[i]))
  cat(sprintf("  CV: %.1f%%\n", aafc_compliance$cv_soc[i]))
  cat(sprintf("  Achieved precision: %.1f%% (at 95%% CI)\n",
              aafc_compliance$achieved_precision_pct[i]))
  cat(sprintf("  Status: %s\n", aafc_compliance$status[i]))
  cat(sprintf("  AAFC Compliant: %s\n",
              ifelse(aafc_compliance$aafc_compliant[i], "✓ YES", "✗ NO")))

  # Recommendations
  if (!aafc_compliance$aafc_compliant[i]) {
    cat("\n  Recommendations:\n")
    if (!aafc_compliance$meets_min_n[i]) {
      cat(sprintf("    • Add %d cores to meet minimum requirement\n",
                  AAFC_MIN_CORES - aafc_compliance$n_cores[i]))
    }
    if (aafc_compliance$additional_for_20pct[i] > 0) {
      cat(sprintf("    • Add %d cores to achieve 20%% precision\n",
                  aafc_compliance$additional_for_20pct[i]))
    }
  }
  cat("\n")
}

# Overall project status
n_compliant <- sum(aafc_compliance$aafc_compliant)
n_total <- nrow(aafc_compliance)

cat(sprintf("Overall: %d/%d grassland strata meet AAFC requirements\n\n",
            n_compliant, n_total))

if (n_compliant < n_total) {
  log_message(sprintf("WARNING: %d grassland strata do not meet AAFC requirements",
                      n_total - n_compliant), "WARNING")
}

# Save AAFC compliance report
write_csv(aafc_compliance, "data_processed/aafc_compliance_report_grassland.csv")
log_message("Saved AAFC compliance report")

# ============================================================================
# BULK DENSITY HANDLING (GRASSLAND DEFAULTS)
# ============================================================================

log_message("Handling bulk density with grassland-specific defaults...")

n_bd_missing <- sum(is.na(cores_complete$bulk_density_g_cm3))
n_bd_measured <- sum(!is.na(cores_complete$bulk_density_g_cm3))

log_message(sprintf("BD measured: %d samples", n_bd_measured))
log_message(sprintf("BD missing: %d samples", n_bd_missing))

if (n_bd_missing > 0) {
  log_message("Applying grassland stratum-specific BD defaults to missing values")

  # Show grassland defaults being applied
  cat("\nBulk density defaults by grassland stratum:\n")
  for (s in names(BD_DEFAULTS)) {
    cat(sprintf("  %s: %.2f g/cm³\n", s, BD_DEFAULTS[[s]]))
  }

  cores_complete <- assign_bd_defaults(cores_complete)

  # Flag which samples have estimated BD
  cores_complete <- cores_complete %>%
    mutate(bd_estimated = !bd_measured)
}

# ============================================================================
# BULK DENSITY TRANSPARENCY REPORT
# ============================================================================

log_message("Generating bulk density transparency report...")

# Calculate BD statistics by stratum
bd_transparency <- cores_complete %>%
  group_by(stratum) %>%
  summarise(
    n_samples = n(),
    n_measured = sum(bd_measured),
    n_estimated = sum(!bd_measured),
    pct_measured = (sum(bd_measured) / n()) * 100,
    pct_estimated = (sum(!bd_measured) / n()) * 100,

    # Measured BD stats (where available)
    mean_bd_measured = ifelse(sum(bd_measured) > 0,
                               mean(bulk_density_g_cm3[bd_measured], na.rm = TRUE),
                               NA),
    sd_bd_measured = ifelse(sum(bd_measured) > 1,
                            sd(bulk_density_g_cm3[bd_measured], na.rm = TRUE),
                            NA),

    # Estimated BD (from defaults)
    mean_bd_estimated = ifelse(sum(!bd_measured) > 0,
                                mean(bulk_density_g_cm3[!bd_measured], na.rm = TRUE),
                                NA),

    # Overall BD
    mean_bd_all = mean(bulk_density_g_cm3, na.rm = TRUE),

    .groups = "drop"
  )

cat("\n========================================\n")
cat("BULK DENSITY TRANSPARENCY REPORT (Grassland Soils)\n")
cat("========================================\n\n")

cat(sprintf("Total samples: %d\n", nrow(cores_complete)))
cat(sprintf("  Measured BD: %d (%.1f%%)\n",
            sum(cores_complete$bd_measured),
            100 * sum(cores_complete$bd_measured) / nrow(cores_complete)))
cat(sprintf("  Estimated BD: %d (%.1f%%)\n\n",
            sum(!cores_complete$bd_measured),
            100 * sum(!cores_complete$bd_measured) / nrow(cores_complete)))

cat("By grassland stratum:\n")
for (i in 1:nrow(bd_transparency)) {
  cat(sprintf("\n%s:\n", bd_transparency$stratum[i]))
  cat(sprintf("  Measured: %d/%d (%.1f%%)\n",
              bd_transparency$n_measured[i],
              bd_transparency$n_samples[i],
              bd_transparency$pct_measured[i]))

  if (!is.na(bd_transparency$mean_bd_measured[i])) {
    cat(sprintf("  Mean measured BD: %.2f ± %.2f g/cm³\n",
                bd_transparency$mean_bd_measured[i],
                ifelse(is.na(bd_transparency$sd_bd_measured[i]), 0,
                       bd_transparency$sd_bd_measured[i])))
  }

  if (bd_transparency$n_estimated[i] > 0) {
    cat(sprintf("  Estimated BD (default): %.2f g/cm³\n",
                bd_transparency$mean_bd_estimated[i]))
  }

  cat(sprintf("  Overall mean BD: %.2f g/cm³\n",
              bd_transparency$mean_bd_all[i]))
}

cat("\n📝 Note: Estimated BD values are based on Canadian grassland literature defaults.\n")
cat("   Carbon stock uncertainty will be higher for samples with estimated BD.\n")
cat("   AAFC recommends measuring BD for all cores when possible.\n\n")

# Save BD transparency report
write_csv(bd_transparency, "data_processed/bd_transparency_report_grassland.csv")
log_message("Saved BD transparency report")

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

log_message("Carbon stock summary by grassland stratum:")
print(carbon_by_stratum)

# ============================================================================
# DEPTH PROFILE COMPLETENESS
# ============================================================================

log_message("Calculating depth profile completeness...")

# Calculate completeness per core
core_depth_completeness <- cores_complete %>%
  group_by(core_id, stratum, core_type) %>%
  summarise(
    n_samples = n(),
    min_depth = min(depth_top_cm),
    max_depth = max(depth_bottom_cm),
    depth_range = max(depth_bottom_cm) - min(depth_top_cm),
    total_sampled = sum(depth_bottom_cm - depth_top_cm),
    completeness_pct = calculate_profile_completeness(depth_top_cm, depth_bottom_cm, MAX_CORE_DEPTH),

    # Check for depth gaps
    has_gaps = any(diff(sort(c(depth_top_cm, depth_bottom_cm))) > 5),

    # Classification
    profile_quality = case_when(
      completeness_pct >= 90 ~ "Complete (≥90%)",
      completeness_pct >= 70 ~ "Good (70-89%)",
      completeness_pct >= 50 ~ "Moderate (50-69%)",
      TRUE ~ "Incomplete (<50%)"
    ),

    .groups = "drop"
  )

# Summary by stratum
depth_completeness_summary <- core_depth_completeness %>%
  group_by(stratum) %>%
  summarise(
    n_cores = n(),
    mean_completeness = mean(completeness_pct),
    sd_completeness = sd(completeness_pct),
    min_completeness = min(completeness_pct),
    max_completeness = max(completeness_pct),
    n_complete = sum(completeness_pct >= 90),
    n_good = sum(completeness_pct >= 70 & completeness_pct < 90),
    n_moderate = sum(completeness_pct >= 50 & completeness_pct < 70),
    n_incomplete = sum(completeness_pct < 50),
    .groups = "drop"
  )

cat("\n========================================\n")
cat("DEPTH PROFILE COMPLETENESS (Grassland Soils to 100 cm)\n")
cat("========================================\n\n")

for (i in 1:nrow(depth_completeness_summary)) {
  cat(sprintf("%s:\n", depth_completeness_summary$stratum[i]))
  cat(sprintf("  Mean completeness: %.1f%% ± %.1f%%\n",
              depth_completeness_summary$mean_completeness[i],
              depth_completeness_summary$sd_completeness[i]))
  cat(sprintf("  Range: %.1f%% - %.1f%%\n",
              depth_completeness_summary$min_completeness[i],
              depth_completeness_summary$max_completeness[i]))
  cat(sprintf("  Complete profiles (≥90%%): %d/%d\n",
              depth_completeness_summary$n_complete[i],
              depth_completeness_summary$n_cores[i]))
  cat(sprintf("  Good profiles (70-89%%): %d/%d\n",
              depth_completeness_summary$n_good[i],
              depth_completeness_summary$n_cores[i]))
  if (depth_completeness_summary$n_incomplete[i] > 0) {
    cat(sprintf("  ⚠ Incomplete profiles (<50%%): %d\n",
                depth_completeness_summary$n_incomplete[i]))
  }
  cat("\n")
}

# Save depth completeness report
write_csv(core_depth_completeness, "data_processed/core_depth_completeness_grassland.csv")
write_csv(depth_completeness_summary, "data_processed/depth_completeness_summary_grassland.csv")
log_message("Saved depth completeness reports")

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

log_message("Exporting cleaned grassland data...")

# Save as RDS (preserves data types)
saveRDS(cores_complete, "data_processed/cores_clean_grassland.rds")
log_message("Saved: cores_clean_grassland.rds")

# Save as CSV (portable)
write_csv(cores_complete, "data_processed/cores_clean_grassland.csv")
log_message("Saved: cores_clean_grassland.csv")

# Save core totals
saveRDS(core_totals, "data_processed/core_totals_grassland.rds")
write_csv(core_totals, "data_processed/core_totals_grassland.csv")
log_message("Saved: core_totals_grassland")

# Save carbon by stratum summary
write_csv(carbon_by_stratum, "data_processed/carbon_by_stratum_summary_grassland.csv")
log_message("Saved: carbon_by_stratum_summary_grassland.csv")

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

  # AAFC compliance
  aafc_compliance = aafc_compliance,
  n_compliant_strata = sum(aafc_compliance$aafc_compliant),
  n_total_strata = nrow(aafc_compliance),

  # Bulk density
  bd_measured = n_bd_measured,
  bd_estimated = n_bd_missing,
  bd_transparency = bd_transparency,

  # Depth profile completeness
  depth_completeness_summary = depth_completeness_summary,

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
  monitoring_year = MONITORING_YEAR,
  ecosystem_type = "Canadian Grassland"
)

saveRDS(qa_report, "data_processed/qa_report_grassland.rds")
log_message("Saved: qa_report_grassland.rds")

# ============================================================================
# FINAL SUMMARY
# ============================================================================

cat("\n========================================\n")
cat("MODULE 01 COMPLETE - CANADIAN GRASSLANDS\n")
cat("========================================\n\n")

cat("Data Summary:\n")
cat("----------------------------------------\n")
cat(sprintf("Cores processed: %d\n", n_distinct(cores_complete$core_id)))
cat(sprintf("Samples processed: %d\n", nrow(cores_complete)))
cat(sprintf("QA pass rate: %.1f%%\n", 100 * n_pass / nrow(cores_complete)))
cat(sprintf("\nGrassland strata represented: %d\n", n_distinct(cores_complete$stratum)))

cat("\nSamples by grassland stratum:\n")
for (i in 1:nrow(stratum_stats)) {
  cat(sprintf("  %s: %d cores, %d samples\n",
              stratum_stats$stratum[i],
              stratum_stats$n_cores[i],
              stratum_stats$n_samples[i]))
}

cat("\nBulk density:\n")
cat(sprintf("  Measured: %d samples (%.1f%%)\n", n_bd_measured,
            100 * n_bd_measured / nrow(cores_complete)))
cat(sprintf("  Estimated: %d samples (%.1f%%)\n", n_bd_missing,
            100 * n_bd_missing / nrow(cores_complete)))

cat("\nAAFC Compliance:\n")
cat(sprintf("  Compliant strata: %d/%d\n",
            sum(aafc_compliance$aafc_compliant),
            nrow(aafc_compliance)))
if (sum(aafc_compliance$aafc_compliant) < nrow(aafc_compliance)) {
  cat("  ⚠ Review aafc_compliance_report_grassland.csv for details\n")
}

cat("\nOutputs saved to data_processed/:\n")
cat("  Core Data:\n")
cat("    - cores_clean_grassland.rds\n")
cat("    - cores_clean_grassland.csv\n")
cat("    - core_totals_grassland.csv\n")
cat("  Summaries:\n")
cat("    - cores_summary_by_stratum_grassland.csv\n")
cat("    - carbon_by_stratum_summary_grassland.csv\n")
cat("  AAFC Compliance:\n")
cat("    - aafc_compliance_report_grassland.csv\n")
cat("  Bulk Density:\n")
cat("    - bd_transparency_report_grassland.csv\n")
cat("  Depth Profiles:\n")
cat("    - core_depth_completeness_grassland.csv\n")
cat("    - depth_completeness_summary_grassland.csv\n")
cat("  QA Report:\n")
cat("    - qa_report_grassland.rds\n")

cat("\nNext steps:\n")
cat("  1. Review AAFC compliance report\n")
cat("  2. Check BD transparency and depth completeness\n")
cat("  3. If needed, collect additional samples for non-compliant strata\n")
cat("  4. Run: source('02_exploratory_analysis_grassland.R')\n\n")

log_message("=== MODULE 01 COMPLETE - GRASSLAND ===")
