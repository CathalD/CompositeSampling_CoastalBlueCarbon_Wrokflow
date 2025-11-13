# ============================================================================
# MODULE 08: TEMPORAL DATA HARMONIZATION
# ============================================================================
# PURPOSE: Load and align carbon stock outputs from multiple scenarios/years
# INPUTS:
#   - outputs/carbon_stocks/carbon_stocks_by_stratum.csv (from multiple runs)
#   - outputs/carbon_stocks/maps/*.tif (from multiple runs)
# OUTPUTS:
#   - data_temporal/carbon_stocks_aligned.rds
#   - data_temporal/temporal_metadata.csv
#   - data_temporal/stratum_coverage.csv
# ============================================================================
# IMPORTANT: This is PART 3 of the workflow
# Run Module 01-07 separately for each scenario/year BEFORE running this module
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

# Verify required config variables
required_vars <- c("VALID_SCENARIOS", "MIN_YEARS_FOR_CHANGE",
                   "ADDITIONALITY_CONFIDENCE", "PROCESSING_CRS")
missing_vars <- required_vars[!sapply(required_vars, exists)]
if (length(missing_vars) > 0) {
  stop(sprintf("Configuration error: Missing required variables: %s\nPlease check blue_carbon_config.R",
               paste(missing_vars, collapse=", ")))
}

# Initialize logging
log_file <- file.path("logs", paste0("temporal_harmonization_", Sys.Date(), ".log"))
if (!dir.exists("logs")) dir.create("logs")

log_message <- function(msg, level = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  log_entry <- sprintf("[%s] %s: %s", timestamp, level, msg)
  cat(log_entry, "\n")
  cat(log_entry, "\n", file = log_file, append = TRUE)
}

log_message("=== MODULE 08: TEMPORAL DATA HARMONIZATION ===")

# Load packages
suppressPackageStartupMessages({
  library(terra)
  library(dplyr)
  library(readr)
  library(tidyr)
  library(stringr)
})

log_message("Packages loaded successfully")

# Create output directory
dir.create("data_temporal", recursive = TRUE, showWarnings = FALSE)

# ============================================================================
# DISCOVER AVAILABLE SCENARIOS AND YEARS
# ============================================================================

log_message("Scanning for available carbon stock datasets...")

# Look for carbon_stocks_by_stratum.csv files in outputs/carbon_stocks/
carbon_stock_dir <- "outputs/carbon_stocks"

if (!dir.exists(carbon_stock_dir)) {
  stop(sprintf("Carbon stocks directory not found: %s\nPlease run Module 01-07 first to generate carbon stock outputs.",
               carbon_stock_dir))
}

# Find all carbon stock CSV files
csv_files <- list.files(carbon_stock_dir,
                        pattern = "carbon_stocks_by_stratum\\.csv$",
                        full.names = TRUE,
                        recursive = FALSE)

if (length(csv_files) == 0) {
  stop(sprintf("No carbon stock files found in %s\nPlease run Module 01-07 to generate carbon stocks.",
               carbon_stock_dir))
}

log_message(sprintf("Found %d carbon stock dataset(s):", length(csv_files)))
for (f in csv_files) {
  log_message(sprintf("  - %s", basename(f)))
}

# ============================================================================
# INTERACTIVE SCENARIO SPECIFICATION
# ============================================================================

cat("\n========================================\n")
cat("TEMPORAL DATASET CONFIGURATION\n")
cat("========================================\n\n")

cat("Please specify which scenarios/years to compare.\n")
cat("You can either:\n")
cat("  1. Use file naming convention (recommended)\n")
cat("  2. Manually specify scenario labels\n\n")

# Check if files follow naming convention: carbon_stocks_by_stratum_SCENARIO_YEAR.csv
has_naming_convention <- any(grepl("carbon_stocks_by_stratum_[A-Z]+_[0-9]{4}\\.csv$", csv_files))

if (has_naming_convention) {
  cat("Detected naming convention! Extracting scenario/year from filenames...\n\n")

  # Extract scenario and year from filename
  temporal_metadata <- data.frame(
    file_path = csv_files,
    file_name = basename(csv_files)
  ) %>%
    mutate(
      # Extract scenario and year from filename pattern
      scenario = str_extract(file_name, "(?<=_)[A-Z]+(?=_[0-9]{4})"),
      year = as.integer(str_extract(file_name, "[0-9]{4}(?=\\.csv$)"))
    )

  # Handle files without convention
  no_convention_idx <- is.na(temporal_metadata$scenario) | is.na(temporal_metadata$year)

  if (any(no_convention_idx)) {
    log_message("WARNING: Some files don't follow naming convention:", "WARNING")
    for (i in which(no_convention_idx)) {
      log_message(sprintf("  - %s", temporal_metadata$file_name[i]), "WARNING")
    }
    log_message("  These files will use default scenario/year from config", "WARNING")

    # Use defaults from config for files without convention
    temporal_metadata$scenario[no_convention_idx] <- PROJECT_SCENARIO
    temporal_metadata$year[no_convention_idx] <- MONITORING_YEAR
  }

} else {
  # Manual specification required
  cat("No naming convention detected.\n")
  cat("Using default scenario/year from config for all files.\n\n")

  temporal_metadata <- data.frame(
    file_path = csv_files,
    file_name = basename(csv_files),
    scenario = PROJECT_SCENARIO,
    year = MONITORING_YEAR
  )
}

# Display detected scenarios
cat("\nDetected scenarios and years:\n")
print(temporal_metadata %>% select(file_name, scenario, year))
cat("\n")

# Validate scenarios
invalid_scenarios <- setdiff(unique(temporal_metadata$scenario), VALID_SCENARIOS)
if (length(invalid_scenarios) > 0) {
  stop(sprintf("Invalid scenario types detected: %s\nValid options: %s",
               paste(invalid_scenarios, collapse = ", "),
               paste(VALID_SCENARIOS, collapse = ", ")))
}

# ============================================================================
# LOAD AND MERGE CARBON STOCK DATA
# ============================================================================

log_message("Loading carbon stock datasets...")

carbon_stocks_all <- list()

for (i in 1:nrow(temporal_metadata)) {
  scenario <- temporal_metadata$scenario[i]
  year <- temporal_metadata$year[i]
  file_path <- temporal_metadata$file_path[i]

  log_message(sprintf("  Loading: %s (%d)", scenario, year))

  # Load CSV
  carbon_stocks <- read_csv(file_path, show_col_types = FALSE) %>%
    mutate(
      scenario = scenario,
      year = year,
      dataset_id = sprintf("%s_%d", scenario, year)
    )

  carbon_stocks_all[[i]] <- carbon_stocks
}

# Combine all datasets
carbon_stocks_combined <- bind_rows(carbon_stocks_all)

log_message(sprintf("Loaded %d datasets with %d total rows",
                   length(carbon_stocks_all),
                   nrow(carbon_stocks_combined)))

# ============================================================================
# VALIDATE STRATUM COVERAGE
# ============================================================================

log_message("Validating stratum coverage across scenarios...")

stratum_coverage <- carbon_stocks_combined %>%
  group_by(scenario, year, stratum) %>%
  summarise(
    has_data = n() > 0,
    .groups = "drop"
  ) %>%
  pivot_wider(
    names_from = c(scenario, year),
    values_from = has_data,
    values_fill = FALSE
  )

cat("\n========================================\n")
cat("STRATUM COVERAGE MATRIX\n")
cat("========================================\n\n")
print(as.data.frame(stratum_coverage))
cat("\n")

# Check for overlapping strata across scenarios
all_combos <- temporal_metadata %>%
  select(scenario, year) %>%
  distinct()

if (nrow(all_combos) > 1) {
  for (i in 1:(nrow(all_combos) - 1)) {
    for (j in (i + 1):nrow(all_combos)) {
      scenario1 <- all_combos$scenario[i]
      year1 <- all_combos$year[i]
      scenario2 <- all_combos$scenario[j]
      year2 <- all_combos$year[j]

      strata1 <- carbon_stocks_combined %>%
        filter(scenario == scenario1, year == year1) %>%
        pull(stratum) %>%
        unique()

      strata2 <- carbon_stocks_combined %>%
        filter(scenario == scenario2, year == year2) %>%
        pull(stratum) %>%
        unique()

      overlap <- intersect(strata1, strata2)

      if (length(overlap) > 0) {
        log_message(sprintf("✓ %s_%d vs %s_%d: %d overlapping strata",
                           scenario1, year1, scenario2, year2, length(overlap)))
      } else {
        log_message(sprintf("WARNING: %s_%d vs %s_%d: NO overlapping strata",
                           scenario1, year1, scenario2, year2), "WARNING")
      }
    }
  }
}

# ============================================================================
# LOAD AND ALIGN RASTER DATA
# ============================================================================

log_message("\nLoading carbon stock rasters...")

# Find all raster directories
maps_dirs <- file.path(carbon_stock_dir, "maps")

if (!dir.exists(maps_dirs)) {
  log_message("WARNING: Maps directory not found - proceeding with CSV data only", "WARNING")
  rasters_aligned <- NULL
} else {

  # For each scenario/year, load key rasters
  rasters_list <- list()

  for (i in 1:nrow(temporal_metadata)) {
    scenario <- temporal_metadata$scenario[i]
    year <- temporal_metadata$year[i]
    dataset_id <- sprintf("%s_%d", scenario, year)

    log_message(sprintf("  Loading rasters for: %s", dataset_id))

    # Key rasters to load
    raster_patterns <- c(
      surface_mean = "carbon_stock_surface_mean\\.tif$",
      deep_mean = "carbon_stock_deep_mean\\.tif$",
      total_mean = "carbon_stock_total_mean\\.tif$",
      surface_conservative = "carbon_stock_surface_conservative\\.tif$",
      total_conservative = "carbon_stock_total_conservative\\.tif$"
    )

    dataset_rasters <- list()

    for (raster_name in names(raster_patterns)) {
      pattern <- raster_patterns[raster_name]
      raster_file <- list.files(maps_dirs, pattern = pattern, full.names = TRUE)

      if (length(raster_file) > 0) {
        r <- rast(raster_file[1])
        dataset_rasters[[raster_name]] <- r
        log_message(sprintf("    Loaded: %s", raster_name))
      } else {
        log_message(sprintf("    Missing: %s", raster_name), "WARNING")
      }
    }

    rasters_list[[dataset_id]] <- dataset_rasters
  }

  # Check spatial alignment
  log_message("\nChecking spatial alignment...")

  reference_raster <- rasters_list[[1]][[1]]
  all_aligned <- TRUE

  for (i in 2:length(rasters_list)) {
    test_raster <- rasters_list[[i]][[1]]

    if (!compareGeom(reference_raster, test_raster, stopOnError = FALSE)) {
      log_message(sprintf("WARNING: Rasters for %s not aligned with reference",
                         names(rasters_list)[i]), "WARNING")
      all_aligned <- FALSE
    }
  }

  if (all_aligned) {
    log_message("✓ All rasters are spatially aligned")
    rasters_aligned <- rasters_list
  } else {
    log_message("Resampling rasters to reference grid...", "WARNING")

    # Resample all to reference
    for (i in 2:length(rasters_list)) {
      for (raster_name in names(rasters_list[[i]])) {
        rasters_list[[i]][[raster_name]] <- resample(
          rasters_list[[i]][[raster_name]],
          reference_raster,
          method = "bilinear"
        )
      }
    }

    log_message("✓ Resampling complete")
    rasters_aligned <- rasters_list
  }
}

# ============================================================================
# SAVE HARMONIZED TEMPORAL DATASET
# ============================================================================

log_message("\nSaving harmonized temporal dataset...")

# Create combined temporal data structure
temporal_data <- list(
  metadata = temporal_metadata,
  carbon_stocks = carbon_stocks_combined,
  stratum_coverage = stratum_coverage,
  rasters = rasters_aligned
)

# Save as RDS
saveRDS(temporal_data, "data_temporal/carbon_stocks_aligned.rds")
log_message("Saved: data_temporal/carbon_stocks_aligned.rds")

# Save metadata CSV
write_csv(temporal_metadata, "data_temporal/temporal_metadata.csv")
log_message("Saved: data_temporal/temporal_metadata.csv")

# Save stratum coverage
write_csv(stratum_coverage, "data_temporal/stratum_coverage.csv")
log_message("Saved: data_temporal/stratum_coverage.csv")

# ============================================================================
# SUMMARY REPORT
# ============================================================================

cat("\n========================================\n")
cat("TEMPORAL HARMONIZATION COMPLETE\n")
cat("========================================\n\n")

cat(sprintf("Total datasets: %d\n", nrow(temporal_metadata)))
cat(sprintf("Scenarios: %s\n", paste(unique(temporal_metadata$scenario), collapse = ", ")))
cat(sprintf("Years: %s\n", paste(sort(unique(temporal_metadata$year)), collapse = ", ")))
cat(sprintf("Total strata: %d\n", length(unique(carbon_stocks_combined$stratum))))
cat("\n")

# Check what analyses are possible
has_baseline <- "BASELINE" %in% temporal_metadata$scenario
has_project <- "PROJECT" %in% temporal_metadata$scenario
n_years <- length(unique(temporal_metadata$year))

cat("Possible analyses:\n")
if (has_baseline && has_project) {
  cat("  ✓ Additionality analysis (baseline vs project comparison)\n")
} else {
  cat("  ✗ Additionality analysis (requires BASELINE and PROJECT scenarios)\n")
}

if (n_years >= 2) {
  cat(sprintf("  ✓ Temporal change analysis (%d time points)\n", n_years))

  if (n_years >= MIN_YEARS_FOR_CHANGE) {
    cat(sprintf("  ✓ Trend analysis (>= %d years)\n", MIN_YEARS_FOR_CHANGE))
  }
} else {
  cat("  ✗ Temporal change analysis (requires multiple years)\n")
}

cat("\n")
cat("Next step: Run Module 09 for additionality and temporal change analysis\n")
cat("\n")

log_message("=== MODULE 08 COMPLETE ===")
