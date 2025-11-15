# ============================================================================
# MODULE 05: BLUE CARBON RANDOM FOREST PREDICTIONS
# ============================================================================
# PURPOSE: Predict carbon stocks (kg/m²) using Random Forest with
#          stratum-aware training and spatial covariates
# INPUTS:
#   - data_processed/cores_harmonized_bluecarbon.rds (from Module 03)
#   - covariates/*.tif (from GEE)
# OUTPUTS:
#   - outputs/predictions/rf/carbon_stock_rf_*cm.tif (kg/m²)
#   - outputs/models/rf/rf_models_all_depths.rds
#   - diagnostics/crossvalidation/rf_cv_results.csv
# ============================================================================

# ============================================================================
# SETUP
# ============================================================================

# Load configuration
if (file.exists("blue_carbon_config.R")) {
  source("blue_carbon_config.R")
} else {
  stop("Configuration file not found. Run 00b_setup_directories.R first.")
}

# Create log file
log_file <- file.path("logs", paste0("rf_predictions_", Sys.Date(), ".log"))

log_message <- function(msg, level = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  log_entry <- sprintf("[%s] %s: %s", timestamp, level, msg)
  cat(log_entry, "\n")
  cat(log_entry, "\n", file = log_file, append = TRUE)
}

log_message("=== MODULE 05: RANDOM FOREST PREDICTIONS ===")

# Load required packages
suppressPackageStartupMessages({
  library(dplyr)
  library(sf)
  library(terra)
  library(randomForest)
  library(caret)
})

# Check for optional packages
has_CAST <- requireNamespace("CAST", quietly = TRUE)
if (has_CAST) {
  library(CAST)
  log_message("CAST package available - AOA enabled")
} else {
  log_message("CAST not available - AOA disabled", "WARNING")
}

# Create output directories
dir.create("outputs/predictions/rf", recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/models/rf", recursive = TRUE, showWarnings = FALSE)
dir.create("diagnostics/crossvalidation", recursive = TRUE, showWarnings = FALSE)

# ============================================================================
# LOAD HARMONIZED DATA
# ============================================================================

log_message("Loading harmonized data...")

if (!file.exists("data_processed/cores_harmonized_bluecarbon.rds")) {
  stop("Harmonized data not found. Run Module 03 first.")
}

cores_harmonized <- readRDS("data_processed/cores_harmonized_bluecarbon.rds")

# Filter to standard depths and valid QA
cores_standard <- cores_harmonized %>%
  filter(depth_cm %in% STANDARD_DEPTHS) %>%
  filter(qa_realistic)

log_message(sprintf("Loaded: %d predictions from %d cores",
                    nrow(cores_standard), n_distinct(cores_standard$core_id)))

# Load harmonization metadata
harmonization_metadata <- NULL
if (file.exists("data_processed/harmonization_metadata.rds")) {
  harmonization_metadata <- readRDS("data_processed/harmonization_metadata.rds")
  log_message(sprintf("Harmonization method: %s", harmonization_metadata$method))
}

# Load Module 01 QA data
vm0033_compliance <- NULL
if (file.exists("data_processed/vm0033_compliance.rds")) {
  vm0033_compliance <- readRDS("data_processed/vm0033_compliance.rds")
  log_message("Loaded VM0033 compliance data")
}

# Standardize core type names if present
if ("core_type" %in% names(cores_standard) || "core_type_clean" %in% names(cores_standard)) {
  if (!"core_type_clean" %in% names(cores_standard)) {
    cores_standard <- cores_standard %>%
      mutate(
        core_type_clean = case_when(
          tolower(core_type) %in% c("hr", "high-res", "high resolution", "high res") ~ "HR",
          tolower(core_type) %in% c("paired composite", "paired comp", "paired") ~ "Paired Composite",
          tolower(core_type) %in% c("unpaired composite", "unpaired comp", "unpaired", "composite", "comp") ~ "Unpaired Composite",
          TRUE ~ ifelse(is.na(core_type), "Unknown", core_type)
        )
      )
  }

  log_message("Core type distribution:")
  core_type_summary <- cores_standard %>%
    distinct(core_id, core_type_clean) %>%
    count(core_type_clean)
  for (i in 1:nrow(core_type_summary)) {
    log_message(sprintf("  %s: %d cores",
                       core_type_summary$core_type_clean[i],
                       core_type_summary$n[i]))
  }
}

# ============================================================================
# CREATE STRATUM RASTER FROM GEE MASKS
# ============================================================================

log_message("Creating stratum raster covariate from GEE masks...")

stratum_raster <- NULL
gee_strata_dir <- "data_raw/gee_strata"

# Check if GEE strata directory exists
if (!dir.exists(gee_strata_dir)) {
  log_message(sprintf("GEE strata directory not found: %s", gee_strata_dir), "WARNING")
  log_message("RF will proceed without stratum covariate", "WARNING")
} else {

  # ============================================================================
  # OPTION 1: Check for CSV configuration first
  # ============================================================================

  stratum_config_file <- "stratum_definitions.csv"
  stratum_mapping <- NULL

  if (file.exists(stratum_config_file)) {
    log_message(sprintf("Found %s - using custom stratum configuration", stratum_config_file))

    stratum_mapping <- read.csv(stratum_config_file, stringsAsFactors = FALSE)

    # Validate required columns
    required_cols <- c("stratum_name", "gee_file", "stratum_code")
    missing_cols <- setdiff(required_cols, names(stratum_mapping))

    if (length(missing_cols) > 0) {
      stop(sprintf("stratum_definitions.csv missing required columns: %s\nRequired: %s",
                  paste(missing_cols, collapse=", "),
                  paste(required_cols, collapse=", ")))
    }

    # Optional columns (add with NA if missing)
    optional_cols <- c("description", "restoration_type", "baseline_vs_project", "age_years")
    for (col in optional_cols) {
      if (!col %in% names(stratum_mapping)) {
        stratum_mapping[[col]] <- NA
      }
    }

    log_message(sprintf("Loaded %d strata from CSV configuration", nrow(stratum_mapping)))

  } else {
    # ============================================================================
    # OPTION 2: Auto-detect from VALID_STRATA in config
    # ============================================================================

    log_message("No stratum_definitions.csv found - auto-detecting from blue_carbon_config.R")

    if (!exists("VALID_STRATA") || length(VALID_STRATA) == 0) {
      stop("No VALID_STRATA defined in blue_carbon_config.R and no stratum_definitions.csv found!\nPlease define strata in config or create stratum_definitions.csv")
    }

    # Auto-generate file names from stratum names
    # Convention: "Upper Marsh" -> "upper_marsh.tif"
    stratum_mapping <- data.frame(
      stratum_name = VALID_STRATA,
      gee_file = paste0(tolower(gsub(" ", "_", VALID_STRATA)), ".tif"),
      stratum_code = 1:length(VALID_STRATA),
      description = NA,
      restoration_type = NA,
      baseline_vs_project = NA,
      age_years = NA,
      stringsAsFactors = FALSE
    )

    log_message(sprintf("Auto-detected %d strata from VALID_STRATA", nrow(stratum_mapping)))
  }

  # ============================================================================
  # VALIDATE THAT GEE FILES EXIST
  # ============================================================================

  log_message("\nValidating GEE export files...")

  stratum_mapping$file_exists <- FALSE
  stratum_mapping$file_path <- NA

  for (i in 1:nrow(stratum_mapping)) {
    file_path <- file.path(gee_strata_dir, stratum_mapping$gee_file[i])

    if (file.exists(file_path)) {
      stratum_mapping$file_exists[i] <- TRUE
      stratum_mapping$file_path[i] <- file_path
      log_message(sprintf("  ✓ Found: %s (%s)",
                         stratum_mapping$stratum_name[i],
                         stratum_mapping$gee_file[i]))
    } else {
      log_message(sprintf("  ⚠ Missing: %s (expected: %s)",
                         stratum_mapping$stratum_name[i],
                         stratum_mapping$gee_file[i]), "WARNING")
    }
  }

  # Filter to only strata with available files
  available_strata <- stratum_mapping[stratum_mapping$file_exists, ]

  if (nrow(available_strata) == 0) {
    log_message(sprintf("No GEE stratum files found in %s!", gee_strata_dir), "WARNING")
    log_message(sprintf("Expected files: %s",
                       paste(stratum_mapping$gee_file, collapse=", ")), "WARNING")
    log_message("RF will proceed without stratum covariate", "WARNING")
  } else {

    # Warn about missing strata but continue with available ones
    if (nrow(available_strata) < nrow(stratum_mapping)) {
      missing_strata <- stratum_mapping[!stratum_mapping$file_exists, ]
      log_message(sprintf("\n⚠ WARNING: %d strata missing GEE files (will skip these):",
                         nrow(missing_strata)), "WARNING")
      for (i in 1:nrow(missing_strata)) {
        log_message(sprintf("    - %s", missing_strata$stratum_name[i]), "WARNING")
      }
    }

    log_message(sprintf("\nProceeding with %d available strata: %s",
                       nrow(available_strata),
                       paste(available_strata$stratum_name, collapse=", ")))

    # ============================================================================
    # LOAD STRATUM RASTERS
    # ============================================================================

    log_message("\nLoading stratum raster layers...")

    stratum_layers <- list()

    for (i in 1:nrow(available_strata)) {
      stratum_name <- available_strata$stratum_name[i]
      file_path <- available_strata$file_path[i]
      stratum_code <- available_strata$stratum_code[i]

      mask_rast <- tryCatch({
        log_message(sprintf("  Loading: %s", stratum_name))

        r <- rast(file_path)

        # Ensure binary (0/1) or presence/absence
        # GEE exports typically have 1 where stratum is present
        r[r > 0] <- 1
        r[is.na(r)] <- 0

        # Set to stratum code where mask = 1, NA elsewhere
        r[r == 0] <- NA
        r[r == 1] <- stratum_code

        r
      }, error = function(e) {
        log_message(sprintf("  Failed to load %s: %s", stratum_name, e$message), "WARNING")
        NULL
      })

      if (!is.null(mask_rast)) {
        stratum_layers[[as.character(stratum_code)]] <- mask_rast
      }
    }

    log_message(sprintf("Successfully loaded %d stratum layers", length(stratum_layers)))

    # ============================================================================
    # MOSAIC ALL STRATUM LAYERS INTO SINGLE CATEGORICAL RASTER
    # ============================================================================

    log_message("\nCreating unified stratum raster...")

    if (length(stratum_layers) == 1) {
      # Only one stratum - use directly
      stratum_raster <- stratum_layers[[1]]

    } else {
      # Multiple strata - mosaic with max function
      # Higher codes take precedence where overlap occurs
      stratum_raster <- do.call(mosaic, c(stratum_layers, list(fun = "max")))
    }

    # Convert to categorical factor
    stratum_raster <- as.factor(stratum_raster)

    # Create labels data frame
    active_codes <- sort(unique(values(stratum_raster, na.rm = TRUE)))
    labels_df <- data.frame(
      value = active_codes,
      label = available_strata$stratum_name[match(active_codes, available_strata$stratum_code)]
    )

    # Set levels
    levels(stratum_raster) <- labels_df

    log_message(sprintf("Created categorical stratum raster with %d levels:", nrow(labels_df)))
    for (i in 1:nrow(labels_df)) {
      log_message(sprintf("  %d: %s", labels_df$value[i], labels_df$label[i]))
    }

    # Save stratum raster for use in Module 06
    dir.create("data_processed", recursive = TRUE, showWarnings = FALSE)
    writeRaster(stratum_raster, "data_processed/stratum_raster.tif", overwrite = TRUE)
    log_message("\nSaved unified stratum raster: data_processed/stratum_raster.tif")

    # Save stratum mapping for reference
    write.csv(available_strata, "data_processed/stratum_mapping_used.csv", row.names = FALSE)
    log_message("Saved stratum mapping reference: data_processed/stratum_mapping_used.csv")
  }
}

# ============================================================================
# LOAD COVARIATES
# ============================================================================

log_message("Loading covariate rasters...")

if (!dir.exists("covariates")) {
  stop("Covariates directory not found. Please add GEE covariate exports.")
}

# Find all TIF files
covariate_files <- list.files("covariates", pattern = "\\.tif$", 
                              full.names = TRUE, recursive = TRUE)

if (length(covariate_files) == 0) {
  log_message("ERROR: No covariate files found in covariates/", "ERROR")
  stop("No covariate files found. Please add GEE exports to covariates/")
}

log_message(sprintf("Found %d covariate files", length(covariate_files)))
for (i in 1:min(5, length(covariate_files))) {
  log_message(sprintf("  %s", basename(covariate_files[i])))
}
if (length(covariate_files) > 5) {
  log_message(sprintf("  ... and %d more", length(covariate_files) - 5))
}

# Load covariate stack
log_message("Loading rasters into stack...")

covariate_stack <- tryCatch({
  rast(covariate_files)
}, error = function(e) {
  log_message(sprintf("ERROR loading covariates: %s", e$message), "ERROR")
  stop("Failed to load covariate rasters")
})

log_message(sprintf("Loaded %d covariate layers", nlyr(covariate_stack)))

# Clean names
clean_names <- tools::file_path_sans_ext(basename(covariate_files))
clean_names <- make.names(clean_names)
names(covariate_stack) <- clean_names
covariate_names <- clean_names

log_message("Covariate names cleaned:")
for (i in 1:min(5, length(clean_names))) {
  log_message(sprintf("  %s", clean_names[i]))
}

# Check data coverage
for (i in 1:nlyr(covariate_stack)) {
  vals <- values(covariate_stack[[i]], mat = FALSE)
  n_valid <- sum(!is.na(vals))
  pct_valid <- 100 * n_valid / length(vals)
  
  if (pct_valid < 50) {
    log_message(sprintf("WARNING: %s has only %.1f%% valid data", 
                       names(covariate_stack)[i], pct_valid), "WARNING")
  }
}

# Add stratum raster to covariate stack if available
if (!is.null(stratum_raster)) {
  log_message("Adding stratum raster to covariate stack...")

  # Resample stratum raster to match covariate stack resolution and extent
  stratum_resampled <- resample(stratum_raster, covariate_stack[[1]], method = "near")

  # Add to stack
  covariate_stack <- c(covariate_stack, stratum_resampled)
  names(covariate_stack)[nlyr(covariate_stack)] <- "stratum"

  # Update covariate names
  covariate_names <- c(covariate_names, "stratum")

  log_message(sprintf("Added stratum covariate (total: %d covariates)", nlyr(covariate_stack)))
} else {
  log_message("Stratum raster not available - proceeding without stratum covariate", "WARNING")
}

# ============================================================================
# EXTRACT COVARIATES AT SAMPLE LOCATIONS
# ============================================================================

log_message("Extracting covariate values at sample locations...")

# Get CRS info
cov_crs <- crs(covariate_stack)
log_message(sprintf("Covariate CRS: %s", cov_crs))

# Convert cores to sf
cores_sf <- st_as_sf(cores_standard,
                     coords = c("longitude", "latitude"),
                     crs = INPUT_CRS)

log_message(sprintf("Core locations CRS: EPSG:%d (WGS84)", INPUT_CRS))

# Transform to match covariate CRS
cores_sf <- st_transform(cores_sf, cov_crs)

log_message("Cores transformed to match covariate CRS")

# Convert to SpatVector for terra
cores_vect <- vect(cores_sf)

# Extract values
log_message("Extracting covariate values...")

covariate_values <- extract(covariate_stack, cores_vect)

# Check extraction
n_extracted <- sum(complete.cases(covariate_values))
log_message(sprintf("Extracted covariates: %d/%d locations with complete data",
                    n_extracted, nrow(covariate_values)))

if (n_extracted == 0) {
  log_message("ERROR: No covariate values extracted!", "ERROR")
  stop("Covariate extraction failed - see log for details")
}

# Combine with core data
training_data <- cores_standard %>%
  bind_cols(covariate_values[, -1])  # Remove ID column

# Remove rows with NA covariates
n_before <- nrow(training_data)
training_data <- training_data %>%
  filter(if_all(all_of(covariate_names), ~ !is.na(.)))

n_after <- nrow(training_data)

log_message(sprintf("Complete cases: %d samples from %d cores (removed %d with NA)",
                    n_after, n_distinct(training_data$core_id), n_before - n_after))

# ============================================================================
# SPATIAL CROSS-VALIDATION FUNCTIONS
# ============================================================================

create_spatial_folds <- function(data, n_folds = CV_FOLDS) {
  # Create spatial folds using k-means clustering on coordinates
  
  coords <- data %>%
    select(longitude, latitude) %>%
    as.matrix()
  
  n_samples <- nrow(coords)
  
  # Handle edge cases
  if (n_samples < 2) {
    return(rep(1, n_samples))
  }
  
  # Adjust folds if insufficient samples
  actual_folds <- min(n_folds, n_samples)
  
  if (actual_folds < 2) {
    return(rep(1, n_samples))
  }
  
  if (actual_folds < n_folds) {
    log_message(sprintf("  Reducing folds from %d to %d (limited samples)", 
                       n_folds, actual_folds), "WARNING")
  }
  
  # Spatial clustering
  set.seed(CV_SEED)
  
  folds <- tryCatch({
    clusters <- kmeans(coords, centers = actual_folds, iter.max = 100, nstart = 1)
    clusters$cluster
  }, error = function(e) {
    log_message(sprintf("  k-means failed: %s", e$message), "WARNING")
    rep(1:actual_folds, length.out = n_samples)
  })
  
  return(folds)
}

spatial_cv_stratified <- function(data, n_folds = CV_FOLDS) {
  # Create folds within each stratum
  
  folds <- rep(NA, nrow(data))
  
  for (stratum_name in unique(data$stratum)) {
    stratum_rows <- which(data$stratum == stratum_name)
    n_stratum <- length(stratum_rows)
    
    if (n_stratum >= n_folds) {
      stratum_data <- data[stratum_rows, ]
      stratum_folds <- create_spatial_folds(stratum_data, n_folds)
      folds[stratum_rows] <- stratum_folds
    } else if (n_stratum >= 3) {
      stratum_data <- data[stratum_rows, ]
      stratum_folds <- create_spatial_folds(stratum_data, n_stratum - 1)
      folds[stratum_rows] <- stratum_folds
    } else {
      folds[stratum_rows] <- 1
      log_message(sprintf("  Stratum '%s': n=%d too small for CV", 
                         stratum_name, n_stratum), "WARNING")
    }
  }
  
  return(folds)
}

# ============================================================================
# TRAIN RF MODELS BY DEPTH
# ============================================================================

log_message("Starting RF training by depth...")

rf_models <- list()
cv_results_all <- data.frame()

for (depth in STANDARD_DEPTHS) {
  
  log_message(sprintf("\n=== Processing depth: %.1f cm ===", depth))
  
  # Filter to this depth
  depth_data <- training_data %>%
    filter(depth_cm == depth)
  
  if (nrow(depth_data) < 20) {
    log_message(sprintf("Skipping depth %d cm (n=%d, need ≥20)", 
                       depth, nrow(depth_data)), "WARNING")
    next
  }
  
  log_message(sprintf("Training samples: %d from %d cores across %d strata",
                      nrow(depth_data),
                      n_distinct(depth_data$core_id),
                      n_distinct(depth_data$stratum)))
  
  # Prepare response and predictors
  # Response: carbon stocks in kg/m² (from Module 03 harmonization)
  response <- depth_data$carbon_stock_kg_m2

  # All predictors (including stratum if available as raster covariate)
  predictors <- depth_data %>%
    select(all_of(covariate_names)) %>%
    as.data.frame()

  # Convert stratum to factor if it's included
  if ("stratum" %in% names(predictors)) {
    predictors$stratum <- as.factor(predictors$stratum)
    log_message(sprintf("  Stratum covariate included (%d categories)",
                       length(unique(predictors$stratum))))
  }

  # Check for Module 03 uncertainties
  # Note: Carbon stock uncertainties would need SOC and BD uncertainty propagation
  # For now, using RF prediction variance as primary uncertainty measure
  has_uncertainties <- "is_interpolated" %in% names(depth_data)

  if (has_uncertainties) {
    n_interpolated <- sum(depth_data$is_interpolated, na.rm = TRUE)
    n_measured <- sum(!depth_data$is_interpolated, na.rm = TRUE)
    log_message(sprintf("  Module 03 metadata: %d measured, %d interpolated depths",
                       n_measured, n_interpolated))
  }

  harmonization_var_mean <- 0  # Using RF variance as primary uncertainty

  # ========================================================================
  # TRAIN RF MODEL
  # ========================================================================

  log_message("  Training RF model...")

  set.seed(CV_SEED)

  # Determine mtry
  mtry <- if (is.null(RF_MTRY)) {
    floor(sqrt(ncol(predictors)))
  } else {
    RF_MTRY
  }

  # Main RF model
  rf_model <- randomForest(
    x = predictors,
    y = response,
    ntree = RF_NTREE,
    mtry = mtry,
    nodesize = RF_MIN_NODE_SIZE,
    importance = TRUE,
    na.action = na.omit
  )
  
  oob_r2 <- 1 - rf_model$mse[RF_NTREE] / var(response)
  log_message(sprintf("  RF trained: OOB R² = %.3f, OOB RMSE = %.2f kg/m²",
                      oob_r2, sqrt(rf_model$mse[RF_NTREE])))
  
  # ========================================================================
  # SPATIAL CROSS-VALIDATION
  # ========================================================================
  
  # Check if we have enough data for CV
  if (nrow(depth_data) < (CV_FOLDS * 3)) {
    log_message(sprintf("  Skipping CV (n=%d too small for %d folds)", 
                       nrow(depth_data), CV_FOLDS), "WARNING")
    cv_rmse <- NA
    cv_mae <- NA
    cv_me <- NA
    cv_r2 <- NA
  } else {
    log_message("  Performing spatial cross-validation...")
    
    # Create spatial folds
    spatial_folds <- tryCatch({
      spatial_cv_stratified(depth_data, n_folds = CV_FOLDS)
    }, error = function(e) {
      log_message(sprintf("  Fold creation failed: %s", e$message), "ERROR")
      rep(1:min(CV_FOLDS, nrow(depth_data)), length.out = nrow(depth_data))
    })
    
    n_unique_folds <- length(unique(spatial_folds[!is.na(spatial_folds)]))
    log_message(sprintf("  Created %d folds", n_unique_folds))
    
    if (n_unique_folds < 2) {
      log_message("  Insufficient folds for CV", "WARNING")
      cv_rmse <- NA
      cv_mae <- NA
      cv_me <- NA
      cv_r2 <- NA
    } else {
      # Perform CV with full predictor set
      cv_predictions <- numeric(nrow(depth_data))

      for (fold in 1:n_unique_folds) {
        test_idx <- which(spatial_folds == fold)
        train_idx <- which(spatial_folds != fold)

        if (length(test_idx) == 0 || length(train_idx) < 10) {
          log_message(sprintf("  Fold %d: skipping (insufficient samples)", fold), "WARNING")
          next
        }

        log_message(sprintf("  Fold %d: train=%d, test=%d",
                           fold, length(train_idx), length(test_idx)))

        # Train fold model
        rf_fold <- randomForest(
          x = predictors[train_idx, ],
          y = response[train_idx],
          ntree = RF_NTREE,
          mtry = mtry,
          nodesize = RF_MIN_NODE_SIZE,
          na.action = na.omit
        )

        # Predict on test fold
        cv_predictions[test_idx] <- predict(rf_fold, predictors[test_idx, ])
      }
      
      # Calculate CV metrics
      predicted_idx <- which(cv_predictions > 0)
      
      if (length(predicted_idx) < 5) {
        log_message("  CV failed (too few predictions)", "WARNING")
        cv_rmse <- NA
        cv_mae <- NA
        cv_me <- NA
        cv_r2 <- NA
      } else {
        cv_residuals <- response[predicted_idx] - cv_predictions[predicted_idx]
        cv_rmse <- sqrt(mean(cv_residuals^2, na.rm = TRUE))
        cv_mae <- mean(abs(cv_residuals), na.rm = TRUE)
        cv_me <- mean(cv_residuals, na.rm = TRUE)
        cv_r2 <- 1 - sum(cv_residuals^2, na.rm = TRUE) / 
                 sum((response[predicted_idx] - mean(response[predicted_idx], na.rm = TRUE))^2, na.rm = TRUE)
        
        log_message(sprintf("  CV: RMSE=%.2f, R²=%.3f, MAE=%.2f",
                           cv_rmse, cv_r2, cv_mae))
      }
    }
  }
  
  # Store CV results
  cv_results_all <- rbind(cv_results_all, data.frame(
    depth_cm = depth,
    n_samples = nrow(depth_data),
    n_cores = n_distinct(depth_data$core_id),
    n_strata = n_distinct(depth_data$stratum),
    cv_rmse = cv_rmse,
    cv_mae = cv_mae,
    cv_me = cv_me,
    cv_r2 = cv_r2,
    oob_rmse = sqrt(rf_model$mse[RF_NTREE]),
    oob_r2 = oob_r2
  ))
  
  # ========================================================================
  # VARIABLE IMPORTANCE
  # ========================================================================
  
  var_imp <- importance(rf_model, type = 1)  # %IncMSE
  var_imp_df <- data.frame(
    variable = rownames(var_imp),
    importance = var_imp[, 1]
  ) %>%
    arrange(desc(importance))
  
  log_message("  Top 5 important variables:")
  for (i in 1:min(5, nrow(var_imp_df))) {
    log_message(sprintf("    %d. %s: %.2f", 
                       i, var_imp_df$variable[i], var_imp_df$importance[i]))
  }
  
  # ========================================================================
  # PREDICT ACROSS STUDY AREA
  # ========================================================================
  
  log_message("  Predicting across study area...")
  
  # Predict using covariates only (no stratum for spatial prediction)
  # Note: stratum needs to be handled separately or use dominant stratum per pixel
  pred_raster <- predict(
    covariate_stack,
    rf_model,
    na.rm = TRUE
  )
  
  # Save prediction (carbon stock in kg/m²)
  pred_file <- file.path("outputs/predictions/rf",
                        sprintf("carbon_stock_rf_%.0fcm.tif", depth))
  writeRaster(pred_raster, pred_file, overwrite = TRUE)

  log_message(sprintf("  Saved: %s", basename(pred_file)))

  # ========================================================================
  # PREDICTION UNCERTAINTY
  # ========================================================================

  log_message("  Calculating prediction uncertainty...")

  # Get predictions from all trees for uncertainty quantification
  # predict.all gives us predictions from each tree
  all_tree_preds <- predict(rf_model, predictors, predict.all = TRUE)$individual

  # Calculate variance across trees as RF uncertainty
  rf_var <- apply(all_tree_preds, 1, var)
  rf_se_mean <- mean(sqrt(rf_var), na.rm = TRUE)

  log_message(sprintf("  Mean RF SE: %.2f kg/m²", rf_se_mean))

  # For spatial prediction, calculate pixel-wise uncertainty
  # This requires predicting with all trees across the raster
  log_message("  Calculating spatial uncertainty (this may take a while)...")

  # Get all tree predictions for the raster
  # Note: With terra rasters, predict.all returns the raster directly (not a list with $individual)
  all_tree_pred_raster <- predict(covariate_stack, rf_model, predict.all = TRUE, na.rm = TRUE)

  # Calculate variance raster
  rf_var_raster <- app(all_tree_pred_raster, var, na.rm = TRUE)
  rf_se_raster <- sqrt(rf_var_raster)

  # Combine with Module 03 harmonization uncertainty (if available)
  if (has_uncertainties && harmonization_var_mean > 0) {
    # Combined variance = RF variance + harmonization variance
    combined_var_raster <- rf_var_raster + harmonization_var_mean
    combined_se_raster <- sqrt(combined_var_raster)

    log_message(sprintf("  Combined uncertainty: RF + harmonization (mean SE = %.2f kg/m²)",
                       mean(values(combined_se_raster), na.rm = TRUE)))
  } else {
    combined_var_raster <- rf_var_raster
    combined_se_raster <- rf_se_raster
  }

  # Save RF-only SE
  se_rf_file <- file.path("outputs/predictions/rf",
                          sprintf("se_rf_%.0fcm.tif", depth))
  writeRaster(rf_se_raster, se_rf_file, overwrite = TRUE)

  # Save combined SE (recommended for VM0033)
  se_combined_file <- file.path("outputs/predictions/rf",
                                sprintf("se_combined_%.0fcm.tif", depth))
  writeRaster(combined_se_raster, se_combined_file, overwrite = TRUE)

  log_message("  Saved uncertainty rasters")

  # ========================================================================
  # AREA OF APPLICABILITY (if CAST available)
  # ========================================================================
  
  if (has_CAST && ENABLE_AOA) {
    log_message("  Calculating Area of Applicability...")

    tryCatch({
      # AOA identifies areas where predictions are reliable based on training data
      # Uses dissimilarity index (DI) to flag extrapolation
      # Passing the RF model enables variable importance weighting for more accurate AOA
      aoa_result <- aoa(
        newdata = covariate_stack,  # Raster stack for prediction
        train = predictors,          # Training data (dataframe)
        variables = covariate_names, # Variables to use
        model = rf_model             # RF model for variable importance weighting
      )

      # Save AOA (binary mask: 1 = inside AOA, 0 = outside AOA)
      aoa_file <- file.path("outputs/predictions/rf",
                           sprintf("aoa_%.0fcm.tif", depth))
      writeRaster(aoa_result$AOA, aoa_file, overwrite = TRUE)

      # Save DI (dissimilarity index: continuous measure of extrapolation)
      di_file <- file.path("outputs/predictions/rf",
                          sprintf("di_%.0fcm.tif", depth))
      writeRaster(aoa_result$DI, di_file, overwrite = TRUE)

      # Calculate AOA statistics
      aoa_pct <- mean(values(aoa_result$AOA), na.rm = TRUE) * 100
      log_message(sprintf("  AOA calculated: %.1f%% of prediction area inside AOA", aoa_pct))

    }, error = function(e) {
      log_message(sprintf("  AOA failed: %s", e$message), "WARNING")
      log_message("  Possible causes: insufficient training data or covariate mismatch", "WARNING")
    })
  }
  
  # Store model
  rf_models[[as.character(depth)]] <- list(
    model = rf_model,
    var_importance = var_imp_df,
    cv_metrics = cv_results_all[nrow(cv_results_all), ]
  )
}

# ============================================================================
# VM0033 LAYER AGGREGATION: CARBON STOCK AGGREGATION
# ============================================================================

log_message("\n=== VM0033 Layer Aggregation ===")
log_message("Note: Carbon stocks already calculated in kg/m² from Module 03")

# Create output directory for stocks
dir.create("outputs/predictions/stocks", recursive = TRUE, showWarnings = FALSE)

# Initialize stock layers
stock_layers <- list()

# Process each VM0033 layer
for (i in 1:nrow(VM0033_DEPTH_INTERVALS)) {

  depth_top <- VM0033_DEPTH_INTERVALS$depth_top[i]
  depth_bottom <- VM0033_DEPTH_INTERVALS$depth_bottom[i]
  depth_midpoint <- VM0033_DEPTH_INTERVALS$depth_midpoint[i]
  thickness_cm <- VM0033_DEPTH_INTERVALS$thickness_cm[i]

  log_message(sprintf("Layer %d: %d-%d cm (midpoint %.0f cm, thickness %d cm)",
                     i, depth_top, depth_bottom, depth_midpoint, thickness_cm))

  # Load carbon stock prediction raster for this depth midpoint (kg/m²)
  stock_file_kgm2 <- file.path("outputs/predictions/rf",
                                sprintf("carbon_stock_rf_%.0fcm.tif", depth_midpoint))

  if (!file.exists(stock_file_kgm2)) {
    log_message(sprintf("  Carbon stock file not found: %s - skipping",
                       basename(stock_file_kgm2)), "WARNING")
    next
  }

  stock_raster_kgm2 <- rast(stock_file_kgm2)

  # Convert carbon stock from kg/m² to Mg C/ha for VM0033 reporting
  # Conversion: 1 kg/m² = 10 Mg/ha
  stock_raster <- stock_raster_kgm2 * 10

  # Save layer stock
  stock_file <- file.path("outputs/predictions/stocks",
                         sprintf("stock_rf_layer%d_%d-%dcm.tif",
                                i, depth_top, depth_bottom))
  writeRaster(stock_raster, stock_file, overwrite = TRUE)

  stock_layers[[paste0("layer_", i)]] <- stock_raster

  mean_stock <- mean(values(stock_raster), na.rm = TRUE)
  log_message(sprintf("  Mean stock: %.2f Mg C/ha", mean_stock))

  # Propagate uncertainty to stock (Mg C/ha)
  # Carbon stock SE in kg/m² from RF predictions
  se_file_kgm2 <- file.path("outputs/predictions/rf",
                            sprintf("se_combined_%.0fcm.tif", depth_midpoint))

  if (file.exists(se_file_kgm2)) {
    se_raster_kgm2 <- rast(se_file_kgm2)

    # Convert SE from kg/m² to Mg C/ha: multiply by 10
    stock_se_raster <- se_raster_kgm2 * 10

    # Save stock SE
    stock_se_file <- file.path("outputs/predictions/stocks",
                              sprintf("stock_rf_se_layer%d_%d-%dcm.tif",
                                     i, depth_top, depth_bottom))
    writeRaster(stock_se_raster, stock_se_file, overwrite = TRUE)

    mean_stock_se <- mean(values(stock_se_raster), na.rm = TRUE)
    log_message(sprintf("  Mean stock SE: %.2f Mg C/ha", mean_stock_se))
  }
}

# Calculate cumulative stocks if we have all layers
if (length(stock_layers) > 0) {

  # Total stock to 1m depth (sum of all layers)
  if (length(stock_layers) == 4) {
    total_stock <- Reduce(`+`, stock_layers)

    total_file <- file.path("outputs/predictions/stocks",
                           "stock_rf_total_0-100cm.tif")
    writeRaster(total_stock, total_file, overwrite = TRUE)

    mean_total <- mean(values(total_stock), na.rm = TRUE)
    log_message(sprintf("Total stock (0-100 cm): %.2f Mg C/ha", mean_total))
  }

  # Cumulative stocks for common reporting depths
  # 0-30 cm (top 2 layers)
  if (length(stock_layers) >= 2) {
    stock_0_30 <- stock_layers[[1]] + stock_layers[[2]]

    stock_file <- file.path("outputs/predictions/stocks",
                           "stock_rf_cumulative_0-30cm.tif")
    writeRaster(stock_0_30, stock_file, overwrite = TRUE)

    mean_030 <- mean(values(stock_0_30), na.rm = TRUE)
    log_message(sprintf("Cumulative stock (0-30 cm): %.2f Mg C/ha", mean_030))
  }

  # 0-50 cm (top 3 layers)
  if (length(stock_layers) >= 3) {
    stock_0_50 <- stock_layers[[1]] + stock_layers[[2]] + stock_layers[[3]]

    stock_file <- file.path("outputs/predictions/stocks",
                           "stock_rf_cumulative_0-50cm.tif")
    writeRaster(stock_0_50, stock_file, overwrite = TRUE)

    mean_050 <- mean(values(stock_0_50), na.rm = TRUE)
    log_message(sprintf("Cumulative stock (0-50 cm): %.2f Mg C/ha", mean_050))
  }
}

log_message("\nVM0033 layer aggregation complete")

# ============================================================================
# SAVE MODELS AND RESULTS
# ============================================================================

log_message("Saving models and results...")

saveRDS(rf_models, "outputs/models/rf/rf_models_all_depths.rds")

write.csv(cv_results_all, "diagnostics/crossvalidation/rf_cv_results.csv",
          row.names = FALSE)

log_message("Saved models and diagnostics")

# ============================================================================
# CREATE SUMMARY PLOTS
# ============================================================================

if (nrow(cv_results_all) > 0) {
  
  log_message("Creating summary plots...")
  
  suppressPackageStartupMessages(library(ggplot2))
  
  # CV RMSE by depth
  p_rmse <- ggplot(cv_results_all, aes(x = factor(depth_cm), y = cv_rmse)) +
    geom_col(fill = "#1976D2", alpha = 0.7) +
    geom_text(aes(label = sprintf("%.1f", cv_rmse)), 
              vjust = -0.5, size = 3) +
    labs(
      title = "Random Forest Cross-Validation RMSE",
      x = "Depth (cm)",
      y = "CV RMSE (g/kg)"
    ) +
    theme_minimal()
  
  ggsave("diagnostics/crossvalidation/rf_cv_rmse.png",
         p_rmse, width = 10, height = 6, dpi = 300)
  
  # CV R² by depth
  p_r2 <- ggplot(cv_results_all, aes(x = factor(depth_cm), y = cv_r2)) +
    geom_col(fill = "#388E3C", alpha = 0.7) +
    geom_hline(yintercept = 0.7, linetype = "dashed", color = "red") +
    geom_text(aes(label = sprintf("%.2f", cv_r2)), 
              vjust = -0.5, size = 3) +
    labs(
      title = "Random Forest Cross-Validation R²",
      subtitle = "Red line = 0.7 threshold",
      x = "Depth (cm)",
      y = "CV R²"
    ) +
    ylim(0, 1) +
    theme_minimal()
  
  ggsave("diagnostics/crossvalidation/rf_cv_r2.png",
         p_r2, width = 10, height = 6, dpi = 300)

  # ======================================================================
  # VARIABLE IMPORTANCE PLOTS FOR ALL DEPTHS
  # ======================================================================

  log_message("Creating variable importance plots for all depths...")

  dir.create("diagnostics/variable_importance", recursive = TRUE, showWarnings = FALSE)

  for (depth_name in names(rf_models)) {
    depth_val <- as.numeric(depth_name)

    var_imp_df <- rf_models[[depth_name]]$var_importance %>%
      head(15)

    p_var_imp <- ggplot(var_imp_df,
                        aes(x = reorder(variable, importance), y = importance)) +
      geom_col(fill = "#D32F2F", alpha = 0.7) +
      coord_flip() +
      labs(
        title = sprintf("Variable Importance at %.1f cm", depth_val),
        subtitle = "Top 15 variables (%IncMSE)",
        x = "",
        y = "Importance (%IncMSE)"
      ) +
      theme_minimal()

    ggsave(sprintf("diagnostics/variable_importance/rf_var_imp_%.0fcm.png", depth_val),
           p_var_imp, width = 8, height = 10, dpi = 300)
  }

  # Combined variable importance across all depths
  if (length(rf_models) > 0) {
    all_var_imp <- data.frame()

    for (depth_name in names(rf_models)) {
      depth_val <- as.numeric(depth_name)
      var_imp_df <- rf_models[[depth_name]]$var_importance
      var_imp_df$depth_cm <- depth_val
      all_var_imp <- rbind(all_var_imp, var_imp_df)
    }

    # Get top variables overall
    top_vars <- all_var_imp %>%
      group_by(variable) %>%
      summarise(mean_importance = mean(importance), .groups = "drop") %>%
      arrange(desc(mean_importance)) %>%
      head(10) %>%
      pull(variable)

    # Plot importance across depths for top variables
    top_var_data <- all_var_imp %>%
      filter(variable %in% top_vars)

    p_var_depth <- ggplot(top_var_data,
                          aes(x = factor(depth_cm), y = importance,
                              fill = variable)) +
      geom_col(position = "dodge") +
      labs(
        title = "Top 10 Variables: Importance Across Depths",
        x = "Depth (cm)",
        y = "Importance (%IncMSE)",
        fill = "Variable"
      ) +
      theme_minimal() +
      theme(legend.position = "right")

    ggsave("diagnostics/variable_importance/rf_var_imp_by_depth.png",
           p_var_depth, width = 12, height = 8, dpi = 300)
  }

  log_message("Saved summary plots")
}

# ============================================================================
# FINAL SUMMARY
# ============================================================================

cat("\n========================================\n")
cat("MODULE 05 COMPLETE\n")
cat("========================================\n\n")

cat("Random Forest Summary:\n")
cat("----------------------------------------\n")
cat(sprintf("Depths processed: %d\n", nrow(cv_results_all)))
cat(sprintf("Total training samples: %d\n", 
            sum(cv_results_all$n_samples, na.rm = TRUE)))

if (nrow(cv_results_all) > 0) {
  cat("\nCross-Validation Performance:\n")
  cat("----------------------------------------\n")
  
  for (i in 1:nrow(cv_results_all)) {
    cat(sprintf("Depth %.1f cm: RMSE=%.2f, R²=%.3f (n=%d)\n",
                cv_results_all$depth_cm[i],
                cv_results_all$cv_rmse[i],
                cv_results_all$cv_r2[i],
                cv_results_all$n_samples[i]))
  }
  
  cat(sprintf("\nMean CV R²: %.3f\n", mean(cv_results_all$cv_r2, na.rm = TRUE)))
  cat(sprintf("Mean CV RMSE: %.2f kg/m²\n", mean(cv_results_all$cv_rmse, na.rm = TRUE)))
}

cat("\nOutputs:\n")
cat("  Carbon Stock Predictions (kg/m²): outputs/predictions/rf/carbon_stock_rf_*cm.tif\n")
cat("  Prediction Uncertainty:\n")
cat("    - RF-only SE: outputs/predictions/rf/se_rf_*cm.tif\n")
cat("    - Combined SE: outputs/predictions/rf/se_combined_*cm.tif\n")
cat("  VM0033 Stocks (Mg C/ha): outputs/predictions/stocks/\n")
cat("    - Layer stocks: stock_rf_layer*_*-*cm.tif\n")
cat("    - Cumulative stocks: stock_rf_cumulative_0-*cm.tif\n")
cat("    - Total stock: stock_rf_total_0-100cm.tif\n")
cat("    - Stock SE: stock_rf_se_layer*_*-*cm.tif\n")

if (has_CAST && ENABLE_AOA) {
  cat("  Area of Applicability:\n")
  cat("    - AOA masks: outputs/predictions/rf/aoa_*cm.tif (1 = inside AOA, 0 = extrapolation)\n")
  cat("    - Dissimilarity Index: outputs/predictions/rf/di_*cm.tif (continuous measure)\n")
}

cat("  Models: outputs/models/rf/rf_models_all_depths.rds\n")
cat("  Diagnostics:\n")
cat("    - CV results: diagnostics/crossvalidation/rf_cv_results.csv\n")
cat("    - CV plots: diagnostics/crossvalidation/rf_cv_*.png\n")
cat("    - Variable importance: diagnostics/variable_importance/rf_var_imp_*.png\n")

cat("\nKey Changes:\n")
cat("  ✓ Modeling carbon stocks (kg/m²) directly from Module 03 harmonization\n")
cat("  ✓ No SOC→stock conversion needed (stocks pre-calculated from SOC + BD)\n")
cat("  ✓ VM0033 reporting stocks converted to Mg C/ha (multiply by 10)\n")
cat("  ✓ Fixed AOA calculation (correct parameter names for CAST::aoa)\n")
cat("  ✓ AOA now includes percentage of area inside applicability threshold\n")

cat("\nKey Features:\n")
cat("  - Stratum as categorical covariate (if GEE masks available)\n")
cat("  - Prediction uncertainty quantification (RF variance)\n")
cat("  - VM0033 layer aggregation for carbon credit reporting\n")
cat("  - Variable importance analysis for all depths\n")
cat("  - Area of Applicability identifies extrapolation zones\n")

cat("\nNext steps:\n")
cat("  1. Review CV plots in diagnostics/crossvalidation/\n")
cat("  2. Check variable importance plots for all depths\n")
cat("  3. Compare RF vs kriging predictions (Module 04)\n")
cat("  4. Review AOA masks to identify extrapolation areas (0 values)\n")
cat("  5. Validate stock calculations against field measurements\n\n")

log_message("=== MODULE 05 COMPLETE ===")
