# ============================================================================
# MODULE 05: BLUE CARBON RANDOM FOREST PREDICTIONS
# ============================================================================
# PURPOSE: Predict SOC using Random Forest with stratum-aware training
# INPUTS:
#   - data_processed/cores_harmonized_spline_bluecarbon.rds
#   - covariates/*.tif (from GEE)
# OUTPUTS:
#   - outputs/predictions/rf/soc_rf_*cm.tif
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

if (dir.exists(gee_strata_dir)) {

  # Expected GEE export file patterns and their numeric codes
  stratum_mapping <- data.frame(
    stratum_name = c("Upper Marsh", "Mid Marsh", "Lower Marsh", "Underwater Vegetation", "Open Water"),
    file_name = c("upper_marsh.tif", "mid_marsh.tif", "lower_marsh.tif", "underwater_vegetation.tif", "open_water.tif"),
    stratum_code = 1:5
  )

  stratum_layers <- list()

  for (i in 1:nrow(stratum_mapping)) {
    file_path <- file.path(gee_strata_dir, stratum_mapping$file_name[i])

    if (file.exists(file_path)) {
      mask_rast <- tryCatch({
        r <- rast(file_path)

        # Set to stratum code where mask = 1, NA elsewhere
        r[r == 0] <- NA
        r[r == 1] <- stratum_mapping$stratum_code[i]

        r
      }, error = function(e) {
        log_message(sprintf("  Failed to load %s: %s",
                           stratum_mapping$stratum_name[i], e$message), "WARNING")
        NULL
      })

      if (!is.null(mask_rast)) {
        stratum_layers[[stratum_mapping$stratum_name[i]]] <- mask_rast
        log_message(sprintf("  Loaded: %s (code %d)",
                           stratum_mapping$stratum_name[i],
                           stratum_mapping$stratum_code[i]))
      }
    }
  }

  if (length(stratum_layers) > 0) {
    # Mosaic all stratum layers into single raster
    # Where they overlap, last one wins (shouldn't overlap in practice)
    stratum_raster <- do.call(mosaic, c(stratum_layers, list(fun = "max")))

    # Make categorical
    stratum_raster <- as.factor(stratum_raster)

    # Set category labels
    active_codes <- sort(unique(values(stratum_raster, na.rm = TRUE)))
    labels_df <- data.frame(
      value = active_codes,
      label = stratum_mapping$stratum_name[match(active_codes, stratum_mapping$stratum_code)]
    )
    levels(stratum_raster) <- labels_df

    log_message(sprintf("Created stratum raster with %d categories", length(active_codes)))

    # Save for later use
    dir.create("data_processed", recursive = TRUE, showWarnings = FALSE)
    writeRaster(stratum_raster, "data_processed/stratum_raster.tif", overwrite = TRUE)
    log_message("Saved stratum raster to data_processed/stratum_raster.tif")

  } else {
    log_message("No GEE stratum masks found - RF will not use stratum information", "WARNING")
  }
} else {
  log_message(sprintf("GEE strata directory not found: %s", gee_strata_dir), "WARNING")
  log_message("RF will proceed without stratum covariate", "WARNING")
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
  
  # Prepare predictors
  response <- depth_data$soc_harmonized
  
  # Predictors WITHOUT stratum (for spatial prediction)
  predictors_no_stratum <- depth_data %>%
    select(all_of(covariate_names)) %>%
    as.data.frame()
  
  # Predictors WITH stratum (for CV - captures ecosystem differences)
  predictors_with_stratum <- predictors_no_stratum
  predictors_with_stratum$stratum <- as.factor(depth_data$stratum)
  
  # ========================================================================
  # TRAIN RF MODEL (without stratum for spatial prediction)
  # ========================================================================
  
  log_message("  Training RF model for spatial prediction...")
  
  set.seed(CV_SEED)
  
  # Determine mtry (based on covariates only, not including stratum)
  mtry <- if (is.null(RF_MTRY)) {
    floor(sqrt(ncol(predictors_no_stratum)))
  } else {
    RF_MTRY
  }
  
  # Main model WITHOUT stratum (for spatial prediction)
  rf_model <- randomForest(
    x = predictors_no_stratum,
    y = response,
    ntree = RF_NTREE,
    mtry = mtry,
    nodesize = RF_MIN_NODE_SIZE,
    importance = TRUE,
    na.action = na.omit
  )
  
  oob_r2 <- 1 - rf_model$mse[RF_NTREE] / var(response)
  log_message(sprintf("  RF trained: OOB R² = %.3f, OOB RMSE = %.2f",
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
      # Perform CV - use model WITHOUT stratum for consistency
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
        
        # Train fold model (without stratum for consistency with spatial prediction)
        rf_fold <- randomForest(
          x = predictors_no_stratum[train_idx, ],
          y = response[train_idx],
          ntree = RF_NTREE,
          mtry = mtry,
          nodesize = RF_MIN_NODE_SIZE,
          na.action = na.omit
        )
        
        # Predict on test fold
        cv_predictions[test_idx] <- predict(rf_fold, predictors_no_stratum[test_idx, ])
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
  
  # Save prediction
  pred_file <- file.path("outputs/predictions/rf",
                        sprintf("soc_rf_%.0fcm.tif", depth))
  writeRaster(pred_raster, pred_file, overwrite = TRUE)
  
  log_message(sprintf("  Saved: %s", basename(pred_file)))
  
  # ========================================================================
  # AREA OF APPLICABILITY (if CAST available)
  # ========================================================================
  
  if (has_CAST && ENABLE_AOA) {
    log_message("  Calculating Area of Applicability...")
    
    tryCatch({
      aoa_result <- aoa(
        train = predictors_no_stratum,
        predictors = covariate_stack,
        variables = covariate_names
      )
      
      # Save AOA
      aoa_file <- file.path("outputs/predictions/rf",
                           sprintf("aoa_%.0fcm.tif", depth))
      writeRaster(aoa_result$AOA, aoa_file, overwrite = TRUE)

      # Save DI
      di_file <- file.path("outputs/predictions/rf",
                          sprintf("di_%.0fcm.tif", depth))
      writeRaster(aoa_result$DI, di_file, overwrite = TRUE)
      
      log_message("  AOA calculated and saved")
      
    }, error = function(e) {
      log_message(sprintf("  AOA failed: %s", e$message), "WARNING")
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
  
  # Variable importance for surface layer
  if ("0" %in% names(rf_models)) {
    var_imp_0cm <- rf_models[["0"]]$var_importance %>%
      head(15)
    
    p_var_imp <- ggplot(var_imp_0cm, 
                        aes(x = reorder(variable, importance), y = importance)) +
      geom_col(fill = "#D32F2F", alpha = 0.7) +
      coord_flip() +
      labs(
        title = "Variable Importance at 0 cm",
        subtitle = "Top 15 variables",
        x = "",
        y = "Importance (%IncMSE)"
      ) +
      theme_minimal()
    
    ggsave("diagnostics/crossvalidation/rf_variable_importance_0cm.png",
           p_var_imp, width = 8, height = 10, dpi = 300)
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
    cat(sprintf("Depth %d cm: RMSE=%.2f, R²=%.3f (n=%d)\n",
                cv_results_all$depth_cm[i],
                cv_results_all$cv_rmse[i],
                cv_results_all$cv_r2[i],
                cv_results_all$n_samples[i]))
  }
  
  cat(sprintf("\nMean CV R²: %.3f\n", mean(cv_results_all$cv_r2, na.rm = TRUE)))
  cat(sprintf("Mean CV RMSE: %.2f g/kg\n", mean(cv_results_all$cv_rmse, na.rm = TRUE)))
}

cat("\nOutputs:\n")
cat("  Predictions: outputs/predictions/rf/soc_rf_*cm.tif\n")

if (has_CAST && ENABLE_AOA) {
  cat("  AOA: outputs/predictions/rf/aoa_*cm.tif\n")
  cat("  DI: outputs/predictions/rf/di_*cm.tif\n")
}

cat("  Models: outputs/models/rf/rf_models_all_depths.rds\n")
cat("  CV results: diagnostics/crossvalidation/rf_cv_results.csv\n")

cat("\nNext steps:\n")
cat("  1. Review CV plots in diagnostics/crossvalidation/\n")
cat("  2. Check variable importance\n")
cat("  3. Compare with kriging predictions (Module 04)\n")
cat("  4. Review AOA to identify extrapolation areas\n\n")

log_message("=== MODULE 05 COMPLETE ===")
