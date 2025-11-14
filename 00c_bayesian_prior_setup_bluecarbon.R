# ============================================================================
# MODULE 00C: BAYESIAN PRIOR SETUP (Part 4 - Optional)
# ============================================================================
# PURPOSE: Process GEE-exported prior maps for Bayesian carbon stock estimation
#
# PREREQUISITES:
#   1. Run GEE_EXPORT_BAYESIAN_PRIORS.js in Google Earth Engine
#   2. Download exported files from Google Drive
#   3. Place files in data_prior/gee_exports/ directory
#
# INPUTS:
#   - data_prior/gee_exports/soc_prior_mean_*cm.tif (from GEE)
#   - data_prior/gee_exports/soc_prior_se_*cm.tif (from GEE)
#   - data_prior/gee_exports/uncertainty_strata.tif (from GEE)
#   - blue_carbon_config.R (configuration)
#
# OUTPUTS:
#   - data_prior/soc_prior_mean_*cm.tif (processed and aligned)
#   - data_prior/soc_prior_se_*cm.tif (processed and aligned)
#   - data_prior/uncertainty_strata.tif (for Neyman sampling)
#   - data_prior/prior_metadata.csv (source information)
#
# ============================================================================

# Clear workspace
rm(list = ls())

# Load required libraries
suppressPackageStartupMessages({
  library(terra)
  library(sf)
  library(dplyr)
  library(readr)
})

# Load configuration
source("blue_carbon_config.R")

# ============================================================================
# SETUP LOGGING
# ============================================================================

log_message <- function(msg, level = "INFO") {
  timestamp <- format(Sys.time(), "[%Y-%m-%d %H:%M:%S]")
  cat(sprintf("%s %s: %s\n", timestamp, level, msg))
}

log_message("=== MODULE 00C: BAYESIAN PRIOR SETUP ===")
log_message(sprintf("Project: %s", PROJECT_NAME))

# Check if Bayesian workflow is enabled
if (!USE_BAYESIAN) {
  stop("Bayesian workflow is disabled in config (USE_BAYESIAN = FALSE).\n",
       "Set USE_BAYESIAN <- TRUE in blue_carbon_config.R to enable Part 4.")
}

log_message("Bayesian workflow enabled ✓")

# ============================================================================
# CHECK FOR GEE EXPORTS
# ============================================================================

log_message("\nChecking for GEE exported files...")

gee_exports_dir <- file.path(BAYESIAN_PRIOR_DIR, "gee_exports")

if (!dir.exists(gee_exports_dir)) {
  stop(sprintf("GEE exports directory not found: %s\n\n",
               gee_exports_dir),
       "INSTRUCTIONS:\n",
       "1. Run GEE_EXPORT_BAYESIAN_PRIORS.js in Google Earth Engine\n",
       "2. Download exported files from Google Drive\n",
       "3. Create directory: ", gee_exports_dir, "\n",
       "4. Place all .tif files in that directory\n",
       "5. Re-run this module")
}

# Find all exported prior files
prior_files <- list.files(gee_exports_dir, pattern = "soc_prior_mean.*\\.tif$",
                          full.names = TRUE)

if (length(prior_files) == 0) {
  stop(sprintf("No prior mean files found in %s\n", gee_exports_dir),
       "Expected files like: soc_prior_mean_7_5cm.tif, soc_prior_mean_22_5cm.tif, etc.\n",
       "Please run GEE export script and download files first.")
}

log_message(sprintf("Found %d prior mean files:", length(prior_files)))
for (f in prior_files) {
  log_message(sprintf("  - %s", basename(f)))
}

# ============================================================================
# LOAD STUDY AREA BOUNDARY
# ============================================================================

log_message("\nLoading study area boundary...")

boundary_file <- "data_raw/study_area_boundary.shp"

if (!file.exists(boundary_file)) {
  # Try alternative formats
  boundary_file <- "data_raw/study_area_boundary.geojson"
  if (!file.exists(boundary_file)) {
    boundary_file <- "data_raw/study_area_boundary.gpkg"
  }
}

if (file.exists(boundary_file)) {
  study_area <- st_read(boundary_file, quiet = TRUE)
  log_message(sprintf("Loaded boundary from: %s", basename(boundary_file)))
} else {
  log_message("No boundary file found - using extent of prior rasters", "WARNING")
  study_area <- NULL
}

# ============================================================================
# PROCESS PRIOR MAPS
# ============================================================================

log_message("\nProcessing prior maps for VM0033 standard depths...")

# Create output directory
dir.create(BAYESIAN_PRIOR_DIR, recursive = TRUE, showWarnings = FALSE)

# VM0033 standard depths
vm0033_depths <- c(7.5, 22.5, 40, 75)

processed_files <- data.frame()

for (depth in vm0033_depths) {

  # Format depth for filename (7.5 → 7_5)
  depth_str <- gsub("\\.", "_", as.character(depth))

  log_message(sprintf("\n  Processing depth: %.1f cm", depth))

  # === MEAN LAYER ===
  mean_file <- file.path(gee_exports_dir,
                         sprintf("soc_prior_mean_%scm.tif", depth_str))

  if (!file.exists(mean_file)) {
    log_message(sprintf("    Mean file not found: %s", basename(mean_file)), "WARNING")
    next
  }

  # Load raster
  mean_raster <- rast(mean_file)
  log_message(sprintf("    Loaded mean: %s", basename(mean_file)))

  # Reproject to PROCESSING_CRS if needed
  if (crs(mean_raster, describe = TRUE)$code != sprintf("EPSG:%d", PROCESSING_CRS)) {
    log_message(sprintf("    Reprojecting to EPSG:%d", PROCESSING_CRS))
    mean_raster <- project(mean_raster,
                           sprintf("EPSG:%d", PROCESSING_CRS),
                           method = "bilinear")
  }

  # Clip to study area if available
  if (!is.null(study_area)) {
    study_area_reproj <- st_transform(study_area, crs(mean_raster))
    mean_raster <- crop(mean_raster, vect(study_area_reproj))
    mean_raster <- mask(mean_raster, vect(study_area_reproj))
  }

  # Resample to PREDICTION_RESOLUTION if different
  current_res <- res(mean_raster)[1]
  if (abs(current_res - PREDICTION_RESOLUTION) > 1) {
    log_message(sprintf("    Resampling from %.0fm to %.0fm resolution",
                       current_res, PREDICTION_RESOLUTION))

    template <- rast(ext(mean_raster),
                     resolution = PREDICTION_RESOLUTION,
                     crs = crs(mean_raster))

    mean_raster <- resample(mean_raster, template, method = "bilinear")
  }

  # === SE LAYER ===
  se_file <- file.path(gee_exports_dir,
                       sprintf("soc_prior_se_%scm.tif", depth_str))

  if (file.exists(se_file)) {
    se_raster <- rast(se_file)

    # Apply same transformations
    if (crs(se_raster, describe = TRUE)$code != sprintf("EPSG:%d", PROCESSING_CRS)) {
      se_raster <- project(se_raster,
                           sprintf("EPSG:%d", PROCESSING_CRS),
                           method = "bilinear")
    }

    if (!is.null(study_area)) {
      se_raster <- crop(se_raster, vect(study_area_reproj))
      se_raster <- mask(se_raster, vect(study_area_reproj))
    }

    if (abs(res(se_raster)[1] - PREDICTION_RESOLUTION) > 1) {
      se_raster <- resample(se_raster, template, method = "bilinear")
    }

    # Apply uncertainty inflation factor (conservative adjustment)
    se_raster <- se_raster * PRIOR_UNCERTAINTY_INFLATION

    log_message(sprintf("    Loaded SE (inflated by %.1fx)", PRIOR_UNCERTAINTY_INFLATION))
  } else {
    log_message("    SE file not found - using 20% of mean as default SE", "WARNING")
    se_raster <- mean_raster * 0.20
  }

  # === SAVE PROCESSED RASTERS ===
  mean_out <- file.path(BAYESIAN_PRIOR_DIR,
                        sprintf("soc_prior_mean_%.1fcm.tif", depth))
  se_out <- file.path(BAYESIAN_PRIOR_DIR,
                      sprintf("soc_prior_se_%.1fcm.tif", depth))

  writeRaster(mean_raster, mean_out, overwrite = TRUE)
  writeRaster(se_raster, se_out, overwrite = TRUE)

  log_message(sprintf("    Saved: %s", basename(mean_out)))
  log_message(sprintf("    Saved: %s", basename(se_out)))

  # Collect statistics
  mean_vals <- values(mean_raster, mat = FALSE)
  mean_vals <- mean_vals[!is.na(mean_vals)]

  se_vals <- values(se_raster, mat = FALSE)
  se_vals <- se_vals[!is.na(se_vals)]

  if (length(mean_vals) > 0) {
    processed_files <- rbind(processed_files, data.frame(
      depth_cm = depth,
      mean_file = basename(mean_out),
      se_file = basename(se_out),
      mean_soc_gkg = mean(mean_vals, na.rm = TRUE),
      sd_soc_gkg = sd(mean_vals, na.rm = TRUE),
      mean_se_gkg = mean(se_vals, na.rm = TRUE),
      cv_pct = 100 * mean(se_vals, na.rm = TRUE) / mean(mean_vals, na.rm = TRUE),
      n_pixels = length(mean_vals),
      area_ha = length(mean_vals) * (PREDICTION_RESOLUTION^2) / 10000,
      source = "SoilGrids_250m"
    ))

    log_message(sprintf("    Stats: Mean=%.1f g/kg, SE=%.1f g/kg, CV=%.1f%%",
                       mean(mean_vals), mean(se_vals),
                       100 * mean(se_vals) / mean(mean_vals)))
  }
}

# ============================================================================
# PROCESS UNCERTAINTY STRATA (FOR NEYMAN SAMPLING)
# ============================================================================

log_message("\nProcessing uncertainty strata for Neyman sampling...")

strata_file <- file.path(gee_exports_dir, "uncertainty_strata.tif")

if (file.exists(strata_file)) {

  strata_raster <- rast(strata_file)

  # Apply same transformations
  if (crs(strata_raster, describe = TRUE)$code != sprintf("EPSG:%d", PROCESSING_CRS)) {
    strata_raster <- project(strata_raster,
                             sprintf("EPSG:%d", PROCESSING_CRS),
                             method = "near")  # Use nearest neighbor for categorical
  }

  if (!is.null(study_area)) {
    strata_raster <- crop(strata_raster, vect(study_area_reproj))
    strata_raster <- mask(strata_raster, vect(study_area_reproj))
  }

  # Resample to prediction resolution
  if (abs(res(strata_raster)[1] - PREDICTION_RESOLUTION) > 1) {
    template <- rast(ext(strata_raster),
                     resolution = PREDICTION_RESOLUTION,
                     crs = crs(strata_raster))
    strata_raster <- resample(strata_raster, template, method = "near")
  }

  # Save
  strata_out <- file.path(BAYESIAN_PRIOR_DIR, "uncertainty_strata.tif")
  writeRaster(strata_raster, strata_out, overwrite = TRUE)

  log_message(sprintf("Saved: %s", basename(strata_out)))

  # Calculate area per stratum
  strata_vals <- values(strata_raster, mat = FALSE)
  strata_vals <- strata_vals[!is.na(strata_vals)]

  strata_summary <- data.frame(
    stratum = c(1, 2, 3),
    label = c("Low Uncertainty", "Medium Uncertainty", "High Uncertainty"),
    n_pixels = c(
      sum(strata_vals == 1, na.rm = TRUE),
      sum(strata_vals == 2, na.rm = TRUE),
      sum(strata_vals == 3, na.rm = TRUE)
    )
  ) %>%
    mutate(
      area_ha = n_pixels * (PREDICTION_RESOLUTION^2) / 10000,
      pct_area = 100 * area_ha / sum(area_ha)
    )

  log_message("\nUncertainty Strata Summary:")
  for (i in 1:nrow(strata_summary)) {
    log_message(sprintf("  %s: %.1f ha (%.1f%%)",
                       strata_summary$label[i],
                       strata_summary$area_ha[i],
                       strata_summary$pct_area[i]))
  }

  write_csv(strata_summary,
            file.path(BAYESIAN_PRIOR_DIR, "uncertainty_strata_summary.csv"))

} else {
  log_message("Uncertainty strata file not found - will create from CV in Module 01C", "WARNING")
}

# ============================================================================
# SAVE METADATA
# ============================================================================

log_message("\nSaving prior metadata...")

metadata <- data.frame(
  project = PROJECT_NAME,
  processing_date = Sys.Date(),
  crs = sprintf("EPSG:%d", PROCESSING_CRS),
  resolution_m = PREDICTION_RESOLUTION,
  prior_source = "SoilGrids 250m v2.0 (Poggio et al. 2021)",
  gee_export_date = "User to fill in",
  uncertainty_inflation = PRIOR_UNCERTAINTY_INFLATION,
  n_depths = nrow(processed_files),
  total_area_ha = max(processed_files$area_ha, na.rm = TRUE)
)

write_csv(metadata, file.path(BAYESIAN_PRIOR_DIR, "prior_metadata.csv"))
log_message("Saved: prior_metadata.csv")

# Save depth-specific metadata
write_csv(processed_files, file.path(BAYESIAN_PRIOR_DIR, "prior_depth_summary.csv"))
log_message("Saved: prior_depth_summary.csv")

# ============================================================================
# SUMMARY
# ============================================================================

cat("\n========================================\n")
cat("PRIOR SETUP COMPLETE\n")
cat("========================================\n\n")

cat(sprintf("Processed depths: %s\n",
            paste(processed_files$depth_cm, collapse = ", ")))
cat(sprintf("Total area: %.1f ha\n", max(processed_files$area_ha, na.rm = TRUE)))
cat(sprintf("Mean SOC (all depths): %.1f ± %.1f g/kg\n",
            mean(processed_files$mean_soc_gkg),
            mean(processed_files$mean_se_gkg)))
cat(sprintf("Mean CV: %.1f%%\n", mean(processed_files$cv_pct)))
cat("\n")

cat("Output files:\n")
cat(sprintf("  - %d prior mean rasters\n", nrow(processed_files)))
cat(sprintf("  - %d prior SE rasters\n", nrow(processed_files)))
cat("  - 1 uncertainty strata raster\n")
cat("  - 3 metadata CSV files\n")
cat("\n")

cat("NEXT STEPS:\n")
cat("1. Review prior_depth_summary.csv to check prior quality\n")
cat("2. Run Module 01C for Bayesian sampling design (Neyman allocation)\n")
cat("   OR run standard Module 01 if not using Bayesian sampling\n")
cat("3. After field sampling, run Modules 02-05 as normal\n")
cat("4. Run Module 06C for Bayesian posterior estimation\n")
cat("\n")

log_message("=== MODULE 00C COMPLETE ===")
