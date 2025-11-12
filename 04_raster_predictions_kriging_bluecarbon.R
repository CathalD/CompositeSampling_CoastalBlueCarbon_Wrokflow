# ============================================================================
# MODULE 04: BLUE CARBON STRATIFIED KRIGING PREDICTIONS
# ============================================================================
# PURPOSE: Spatial interpolation of SOC using stratified kriging by ecosystem type
# INPUTS:
#   - data_processed/cores_harmonized_spline_bluecarbon.rds (from Module 03)
#   - covariates/*.tif (optional, for covariate-assisted kriging)
# OUTPUTS:
#   - outputs/predictions/kriging/*.tif (SOC prediction rasters by stratum)
#   - outputs/predictions/uncertainty/*.tif (prediction variance)
#   - outputs/models/kriging/*.rds (variogram models)
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

# Initialize logging
log_file <- file.path("logs", paste0("kriging_", Sys.Date(), ".log"))

log_message <- function(msg, level = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  log_entry <- sprintf("[%s] %s: %s", timestamp, level, msg)
  cat(log_entry, "\n")
  cat(log_entry, "\n", file = log_file, append = TRUE)
}

log_message("=== MODULE 04: STRATIFIED KRIGING ===")

# Load packages
suppressPackageStartupMessages({
  library(dplyr)
  library(sf)
  library(terra)
  library(gstat)
})

# Check for automap (optional)
has_automap <- requireNamespace("automap", quietly = TRUE)
if (has_automap) {
  library(automap)
  log_message("automap package available - using automatic fitting")
} else {
  log_message("automap not available - using manual fitting", "WARNING")
}

log_message("Packages loaded successfully")

# Create output directories
dir.create("outputs/predictions/kriging", recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/predictions/uncertainty", recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/models/kriging", recursive = TRUE, showWarnings = FALSE)
dir.create("diagnostics/variograms", recursive = TRUE, showWarnings = FALSE)
dir.create("diagnostics/crossvalidation", recursive = TRUE, showWarnings = FALSE)

# ============================================================================
# LOAD DATA
# ============================================================================

log_message("Loading harmonized data...")

# Check if spline harmonization has been run
if (!file.exists("data_processed/cores_harmonized_spline_bluecarbon.rds")) {
  stop("Spline-harmonized data not found. Run Module 03 first.")
}

cores_harmonized <- readRDS("data_processed/cores_harmonized_spline_bluecarbon.rds")

log_message(sprintf("Loaded: %d predictions from %d cores",
                    nrow(cores_harmonized),
                    n_distinct(cores_harmonized$core_id)))

# Filter to standard depths only
cores_standard <- cores_harmonized %>%
  filter(depth_cm %in% STANDARD_DEPTHS)

log_message(sprintf("Standard depths: %d predictions", nrow(cores_standard)))

# Check for required columns
required_cols <- c("core_id", "longitude", "latitude", "stratum", 
                   "depth_cm", "soc_spline")
missing <- setdiff(required_cols, names(cores_standard))
if (length(missing) > 0) {
  stop(sprintf("Missing required columns: %s", paste(missing, collapse = ", ")))
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

#' Fit variogram with automatic or manual model selection
#' @param sp_data Spatial data
#' @param formula Formula for kriging
#' @param cutoff Maximum distance for variogram
#' @return Best variogram model
fit_variogram_auto <- function(sp_data, formula, cutoff = NULL) {
  
  tryCatch({
    # Calculate empirical variogram
    vgm_emp <- variogram(formula, sp_data, cutoff = cutoff, width = KRIGING_WIDTH)
    
    # Use automap if available, otherwise manual fitting
    if (has_automap) {
      # Automatic model fitting with automap
      vgm_fit <- automap::autofitVariogram(
        formula = formula,
        input_data = sp_data,
        model = c("Sph", "Exp", "Gau"),
        cutoff = cutoff,
        width = KRIGING_WIDTH,
        verbose = FALSE
      )
      
      return(list(
        empirical = vgm_emp,
        model = vgm_fit$var_model,
        sserr = vgm_fit$sserr
      ))
      
    } else {
      # Manual variogram fitting (fallback)
      log_message("  Using manual variogram fitting", "INFO")
      
      # Get initial parameter estimates
      max_semivar <- max(vgm_emp$gamma, na.rm = TRUE)
      max_dist <- max(vgm_emp$dist, na.rm = TRUE)
      
      # Try multiple models
      models_to_try <- c("Sph", "Exp", "Gau")
      best_model <- NULL
      best_sse <- Inf
      
      for (model_name in models_to_try) {
        # Initial parameters
        init_model <- vgm(
          psill = max_semivar * 0.8,
          model = model_name,
          range = max_dist / 3,
          nugget = max_semivar * 0.1
        )
        
        # Fit model
        fitted_model <- tryCatch({
          fit.variogram(vgm_emp, init_model, fit.method = 7)
        }, error = function(e) NULL)
        
        if (!is.null(fitted_model)) {
          # Calculate SSE
          sse <- attr(fitted_model, "SSErr")
          if (!is.null(sse) && sse < best_sse) {
            best_sse <- sse
            best_model <- fitted_model
          }
        }
      }
      
      if (is.null(best_model)) {
        # Last resort: simple spherical model
        best_model <- vgm(
          psill = max_semivar * 0.8,
          model = "Sph",
          range = max_dist / 3,
          nugget = max_semivar * 0.1
        )
        best_sse <- NA
      }
      
      return(list(
        empirical = vgm_emp,
        model = best_model,
        sserr = best_sse
      ))
    }
    
  }, error = function(e) {
    log_message(sprintf("Variogram fitting error: %s", e$message), "ERROR")
    return(NULL)
  })
}

#' Perform cross-validation for kriging
#' @param sp_data Spatial data
#' @param formula Formula for kriging
#' @param vgm_model Variogram model
#' @return CV results
crossvalidate_kriging <- function(sp_data, formula, vgm_model) {
  
  tryCatch({
    cv_result <- krige.cv(
      formula = formula,
      locations = sp_data,
      model = vgm_model,
      nfold = CV_FOLDS,
      verbose = FALSE
    )
    
    # Calculate metrics
    rmse <- sqrt(mean(cv_result$residual^2, na.rm = TRUE))
    mae <- mean(abs(cv_result$residual), na.rm = TRUE)
    me <- mean(cv_result$residual, na.rm = TRUE)
    
    # R² calculation
    ss_res <- sum(cv_result$residual^2, na.rm = TRUE)
    ss_tot <- sum((cv_result$observed - mean(cv_result$observed, na.rm = TRUE))^2, na.rm = TRUE)
    r2 <- 1 - (ss_res / ss_tot)
    
    return(list(
      rmse = rmse,
      mae = mae,
      me = me,
      r2 = r2,
      cv_data = cv_result
    ))
    
  }, error = function(e) {
    log_message(sprintf("Cross-validation error: %s", e$message), "ERROR")
    return(NULL)
  })
}

#' Plot variogram with model fit
#' @param vgm_emp Empirical variogram
#' @param vgm_model Fitted model
#' @param stratum_name Stratum name
#' @param depth_cm Depth
plot_variogram <- function(vgm_emp, vgm_model, stratum_name, depth_cm) {
  
  tryCatch({
    png(file.path("diagnostics/variograms", 
                  sprintf("variogram_%s_%dcm.png", 
                          gsub(" ", "_", stratum_name), depth_cm)),
        width = 8, height = 6, units = "in", res = 300)
    
    plot(vgm_emp, vgm_model, 
         main = sprintf("Variogram: %s at %d cm", stratum_name, depth_cm),
         xlab = "Distance (m)",
         ylab = "Semivariance")
    
    dev.off()
    
  }, error = function(e) {
    log_message(sprintf("Variogram plot error: %s", e$message), "WARNING")
  })
}

# ============================================================================
# STRATIFIED KRIGING BY DEPTH
# ============================================================================

log_message("Starting stratified kriging by depth and stratum...")

# Initialize results storage
kriging_results <- list()
cv_results_all <- data.frame()
variogram_models <- list()

# Get unique strata
strata <- unique(cores_standard$stratum)
log_message(sprintf("Processing %d strata: %s", 
                    length(strata), paste(strata, collapse = ", ")))

# Process each depth
for (depth in STANDARD_DEPTHS) {
  
  log_message(sprintf("\n=== Processing depth: %d cm ===", depth))
  
  # Filter to this depth
  cores_depth <- cores_standard %>%
    filter(depth_cm == depth)
  
  log_message(sprintf("Samples at %d cm: %d from %d cores",
                      depth, nrow(cores_depth), n_distinct(cores_depth$core_id)))
  
  # Process each stratum
  for (stratum_name in strata) {
    
    log_message(sprintf("Processing: %s at %d cm", stratum_name, depth))
    
    # Filter to this stratum
    cores_stratum <- cores_depth %>%
      filter(stratum == stratum_name)
    
    n_samples <- nrow(cores_stratum)
    
    if (n_samples < 5) {
      log_message(sprintf("Skipping %s (n=%d, need ≥5)", stratum_name, n_samples), "WARNING")
      next
    }
    
    log_message(sprintf("  Samples: %d", n_samples))
    
    # Convert to spatial object
    cores_sf <- st_as_sf(cores_stratum,
                         coords = c("longitude", "latitude"),
                         crs = INPUT_CRS)
    
    # Transform to processing CRS
    cores_sf <- st_transform(cores_sf, PROCESSING_CRS)
    
    # Convert to sp object (required by gstat)
    cores_sp <- as(cores_sf, "Spatial")
    
    # ========================================================================
    # FIT VARIOGRAM
    # ========================================================================
    
    log_message("  Fitting variogram...")
    
    # Determine cutoff (max 1/3 of study area extent)
    bbox <- st_bbox(cores_sf)
    max_dist <- sqrt((bbox$xmax - bbox$xmin)^2 + (bbox$ymax - bbox$ymin)^2)
    cutoff <- min(max_dist / 3, KRIGING_MAX_DISTANCE)
    
    # Fit variogram
    vgm_result <- fit_variogram_auto(
      sp_data = cores_sp,
      formula = soc_spline ~ 1,
      cutoff = cutoff
    )
    
    if (is.null(vgm_result)) {
      log_message("  Variogram fitting failed - skipping", "ERROR")
      next
    }
    
    log_message(sprintf("  Model: %s, SSErr: %.2f", 
                       vgm_result$model$model[2], vgm_result$sserr))
    
    # Plot variogram
    plot_variogram(vgm_result$empirical, vgm_result$model, 
                   stratum_name, depth)
    
    # Store variogram model
    model_key <- sprintf("%s_%dcm", gsub(" ", "_", stratum_name), depth)
    variogram_models[[model_key]] <- vgm_result$model
    
    # ========================================================================
    # CROSS-VALIDATION
    # ========================================================================
    
    log_message("  Performing cross-validation...")
    
    cv_result <- crossvalidate_kriging(
      sp_data = cores_sp,
      formula = soc_spline ~ 1,
      vgm_model = vgm_result$model
    )
    
    if (!is.null(cv_result)) {
      log_message(sprintf("  CV RMSE: %.2f, R²: %.3f", 
                         cv_result$rmse, cv_result$r2))
      
      # Store CV results
      cv_results_all <- rbind(cv_results_all, data.frame(
        stratum = stratum_name,
        depth_cm = depth,
        n_samples = n_samples,
        cv_rmse = cv_result$rmse,
        cv_mae = cv_result$mae,
        cv_me = cv_result$me,
        cv_r2 = cv_result$r2,
        model_type = vgm_result$model$model[2],
        sserr = vgm_result$sserr
      ))
    }
    
    # ========================================================================
    # CREATE PREDICTION GRID
    # ========================================================================
    
    log_message("  Creating prediction grid...")
    
    # Create grid covering stratum extent with buffer
    buffer_dist <- 500  # 500m buffer
    bbox_buffered <- st_buffer(st_as_sfc(bbox), buffer_dist)
    
    # Create raster template
    extent_vec <- st_bbox(bbox_buffered)
    
    # Calculate grid dimensions
    x_range <- extent_vec["xmax"] - extent_vec["xmin"]
    y_range <- extent_vec["ymax"] - extent_vec["ymin"]
    ncols <- ceiling(x_range / KRIGING_CELL_SIZE)
    nrows <- ceiling(y_range / KRIGING_CELL_SIZE)
    
    # Create prediction grid
    pred_grid <- st_as_sf(
      expand.grid(
        x = seq(extent_vec["xmin"], extent_vec["xmax"], length.out = ncols),
        y = seq(extent_vec["ymin"], extent_vec["ymax"], length.out = nrows)
      ),
      coords = c("x", "y"),
      crs = PROCESSING_CRS
    )
    
    # Convert to sp
    pred_grid_sp <- as(pred_grid, "Spatial")
    
    log_message(sprintf("  Prediction grid: %d cells (%d x %d)",
                       length(pred_grid_sp), ncols, nrows))
    
    # ========================================================================
    # PERFORM KRIGING
    # ========================================================================
    
    log_message("  Performing kriging...")
    
    krige_result <- tryCatch({
      krige(
        formula = soc_spline ~ 1,
        locations = cores_sp,
        newdata = pred_grid_sp,
        model = vgm_result$model
      )
    }, error = function(e) {
      log_message(sprintf("  Kriging failed: %s", e$message), "ERROR")
      NULL
    })
    
    if (is.null(krige_result)) {
      next
    }
    
    # ========================================================================
    # SAVE RESULTS
    # ========================================================================
    
    log_message("  Saving predictions...")
    
    # Convert kriging results to raster
    # First convert to SpatVector, then rasterize
    krige_vect <- vect(krige_result)
    
    # Create empty raster template
    template_rast <- rast(
      extent = ext(krige_vect),
      resolution = KRIGING_CELL_SIZE,
      crs = sprintf("EPSG:%d", PROCESSING_CRS)
    )
    
    # Rasterize predictions
    pred_raster <- rasterize(
      x = krige_vect,
      y = template_rast,
      field = "var1.pred",
      fun = "mean"
    )
    
    # Rasterize variance
    var_raster <- rasterize(
      x = krige_vect,
      y = template_rast,
      field = "var1.var",
      fun = "mean"
    )
    
    # Save prediction raster
    pred_file <- file.path("outputs/predictions/kriging",
                          sprintf("soc_%s_%dcm.tif", 
                                  gsub(" ", "_", stratum_name), depth))
    writeRaster(pred_raster, pred_file, overwrite = TRUE)
    
    # Save variance raster
    var_file <- file.path("outputs/predictions/uncertainty",
                         sprintf("variance_%s_%dcm.tif",
                                 gsub(" ", "_", stratum_name), depth))
    writeRaster(var_raster, var_file, overwrite = TRUE)
    
    # Calculate standard error (for 95% CI)
    se_raster <- sqrt(var_raster)
    se_file <- file.path("outputs/predictions/uncertainty",
                        sprintf("se_%s_%dcm.tif",
                                gsub(" ", "_", stratum_name), depth))
    writeRaster(se_raster, se_file, overwrite = TRUE)
    
    # Store result
    result_key <- sprintf("%s_%dcm", gsub(" ", "_", stratum_name), depth)
    kriging_results[[result_key]] <- list(
      stratum = stratum_name,
      depth_cm = depth,
      n_samples = n_samples,
      prediction_file = pred_file,
      variance_file = var_file,
      se_file = se_file,
      mean_prediction = mean(values(pred_raster), na.rm = TRUE),
      sd_prediction = sd(values(pred_raster), na.rm = TRUE)
    )
    
    log_message(sprintf("  Mean prediction: %.2f ± %.2f g/kg", 
                       kriging_results[[result_key]]$mean_prediction,
                       kriging_results[[result_key]]$sd_prediction))
  }
}

# ============================================================================
# SAVE VARIOGRAM MODELS AND CV RESULTS
# ============================================================================

log_message("Saving variogram models and CV results...")

# Save variogram models
saveRDS(variogram_models, "outputs/models/kriging/variogram_models.rds")

# Save CV results
write.csv(cv_results_all, "diagnostics/crossvalidation/kriging_cv_results.csv", 
          row.names = FALSE)
saveRDS(cv_results_all, "diagnostics/crossvalidation/kriging_cv_results.rds")

# Save kriging results summary
saveRDS(kriging_results, "outputs/models/kriging/kriging_results_summary.rds")

log_message("Saved models and diagnostics")

# ============================================================================
# CREATE CV SUMMARY PLOTS
# ============================================================================

if (nrow(cv_results_all) > 0) {
  
  log_message("Creating CV summary plots...")
  
  suppressPackageStartupMessages(library(ggplot2))
  
  # CV RMSE by stratum and depth
  p_cv_rmse <- ggplot(cv_results_all, aes(x = factor(depth_cm), y = cv_rmse, 
                                           fill = stratum)) +
    geom_col(position = "dodge", alpha = 0.7) +
    scale_fill_manual(values = STRATUM_COLORS) +
    labs(
      title = "Kriging Cross-Validation RMSE",
      subtitle = "By stratum and depth",
      x = "Depth (cm)",
      y = "CV RMSE (g/kg)",
      fill = "Stratum"
    ) +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  
  ggsave("diagnostics/crossvalidation/cv_rmse_by_stratum_depth.png",
         p_cv_rmse, width = 10, height = 6, dpi = 300)
  
  # CV R² by stratum and depth
  p_cv_r2 <- ggplot(cv_results_all, aes(x = factor(depth_cm), y = cv_r2, 
                                         fill = stratum)) +
    geom_col(position = "dodge", alpha = 0.7) +
    geom_hline(yintercept = 0.7, linetype = "dashed", color = "red") +
    scale_fill_manual(values = STRATUM_COLORS) +
    labs(
      title = "Kriging Cross-Validation R²",
      subtitle = "By stratum and depth (red line = 0.7 threshold)",
      x = "Depth (cm)",
      y = "CV R²",
      fill = "Stratum"
    ) +
    ylim(0, 1) +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  
  ggsave("diagnostics/crossvalidation/cv_r2_by_stratum_depth.png",
         p_cv_r2, width = 10, height = 6, dpi = 300)
  
  log_message("Saved CV plots")
}

# ============================================================================
# FINAL SUMMARY
# ============================================================================

cat("\n========================================\n")
cat("MODULE 04 COMPLETE\n")
cat("========================================\n\n")

cat("Kriging Summary:\n")
cat("----------------------------------------\n")
cat(sprintf("Depths processed: %d\n", length(STANDARD_DEPTHS)))
cat(sprintf("Strata processed: %d\n", length(strata)))
cat(sprintf("Total predictions created: %d\n", length(kriging_results)))
cat(sprintf("Variogram models saved: %d\n", length(variogram_models)))

if (nrow(cv_results_all) > 0) {
  cat("\nCross-Validation Performance:\n")
  cat("----------------------------------------\n")
  
  cv_summary <- cv_results_all %>%
    group_by(stratum) %>%
    summarise(
      mean_rmse = mean(cv_rmse),
      mean_r2 = mean(cv_r2),
      .groups = "drop"
    )
  
  for (i in 1:nrow(cv_summary)) {
    cat(sprintf("%s: RMSE=%.2f, R²=%.3f\n",
                cv_summary$stratum[i],
                cv_summary$mean_rmse[i],
                cv_summary$mean_r2[i]))
  }
}

cat("\nOutputs:\n")
cat("  Predictions: outputs/predictions/kriging/\n")
cat("  Uncertainty: outputs/predictions/uncertainty/\n")
cat("  Models: outputs/models/kriging/\n")
cat("  Diagnostics: diagnostics/variograms/ and diagnostics/crossvalidation/\n")

cat("\nNext steps:\n")
cat("  1. Review variogram plots in diagnostics/variograms/\n")
cat("  2. Check CV results in diagnostics/crossvalidation/\n")
cat("  3. Run: source('05_raster_predictions_rf_bluecarbon.R')\n\n")

log_message("=== MODULE 04 COMPLETE ===")
