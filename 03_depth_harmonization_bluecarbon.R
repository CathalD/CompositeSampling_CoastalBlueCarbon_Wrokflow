# ============================================================================
# MODULE 03: BLUE CARBON DEPTH HARMONIZATION USING SPLINES
# ============================================================================
# PURPOSE: Harmonize depth profiles to standard depths using equal-area splines
#          with stratum-specific parameters and uncertainty quantification
# INPUTS:
#   - data_processed/cores_clean_bluecarbon.rds
# OUTPUTS:
#   - data_processed/cores_harmonized_spline_bluecarbon.rds
#   - outputs/plots/by_stratum/spline_fits_*.png
#   - diagnostics/spline_diagnostics.rds
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
log_file <- file.path("logs", paste0("depth_harmonization_", Sys.Date(), ".log"))

log_message <- function(msg, level = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  log_entry <- sprintf("[%s] %s: %s", timestamp, level, msg)
  cat(log_entry, "\n")
  cat(log_entry, "\n", file = log_file, append = TRUE)
}

log_message("=== MODULE 03: DEPTH HARMONIZATION ===")

# Set random seed for reproducibility
set.seed(BOOTSTRAP_SEED)

# Load packages
suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(splines)
})

# Check for boot package (for bootstrap CI)
has_boot <- requireNamespace("boot", quietly = TRUE)
if (has_boot) {
  library(boot)
  log_message("Bootstrap package available - CI enabled")
} else {
  log_message("Bootstrap package not available - CI disabled", "WARNING")
}

# Create output directories
dir.create("outputs/plots/by_stratum", recursive = TRUE, showWarnings = FALSE)
dir.create("diagnostics", recursive = TRUE, showWarnings = FALSE)

log_message("Packages loaded successfully")

# ============================================================================
# LOAD DATA
# ============================================================================

log_message("Loading cleaned data...")

if (!file.exists("data_processed/cores_clean_bluecarbon.rds")) {
  stop("Cleaned data not found. Run 01_data_prep_bluecarbon.R first.")
}

cores <- readRDS("data_processed/cores_clean_bluecarbon.rds")

# Filter to QA-passed samples
cores_clean <- cores %>%
  filter(qa_pass)

log_message(sprintf("Loaded: %d samples from %d cores across %d strata",
                    nrow(cores_clean),
                    n_distinct(cores_clean$core_id),
                    n_distinct(cores_clean$stratum)))

# ============================================================================
# SPLINE FUNCTIONS
# ============================================================================

#' Fit smoothing spline with cross-validation for lambda
#' @param depths Vector of depth midpoints (cm)
#' @param values Vector of SOC values (g/kg)
#' @param spar Smoothing parameter (NULL = automatic)
#' @return Fitted spline object
fit_smooth_spline <- function(depths, values, spar = NULL) {
  
  if (length(depths) < 3) {
    return(NULL)
  }
  
  tryCatch({
    smooth.spline(
      x = depths,
      y = values,
      spar = spar,
      cv = is.null(spar)  # Use CV if spar not specified
    )
  }, error = function(e) {
    NULL
  })
}

#' Predict SOC at standard depths with optional bootstrap CI
#' @param core_data Data for single core
#' @param standard_depths Depths to predict at
#' @param n_boot Number of bootstrap iterations
#' @return Data frame with predictions and optional CI
predict_at_standard_depths <- function(core_data, standard_depths, n_boot = 0) {
  
  # Fit spline
  spline_fit <- fit_smooth_spline(
    depths = core_data$depth_cm,
    values = core_data$soc_g_kg
  )
  
  if (is.null(spline_fit)) {
    return(NULL)
  }
  
  # Get predictions at standard depths
  predictions <- predict(spline_fit, x = standard_depths)
  
  # Initialize results
  result <- data.frame(
    core_id = unique(core_data$core_id),
    stratum = unique(core_data$stratum),
    depth_cm = standard_depths,
    soc_spline = predictions$y
  )
  
  # Add metadata
  result$longitude <- unique(core_data$longitude)
  result$latitude <- unique(core_data$latitude)
  result$scenario_type <- unique(core_data$scenario_type)
  result$monitoring_year <- unique(core_data$monitoring_year)
  result$core_type <- unique(core_data$core_type)
  
  # Bootstrap confidence intervals if requested
  if (n_boot > 0 && has_boot) {
    
    boot_predictions <- matrix(NA, nrow = n_boot, ncol = length(standard_depths))
    
    for (i in 1:n_boot) {
      # Resample with replacement
      boot_indices <- sample(1:nrow(core_data), replace = TRUE)
      boot_data <- core_data[boot_indices, ]
      
      # Fit spline to bootstrap sample
      boot_fit <- fit_smooth_spline(
        depths = boot_data$depth_cm,
        values = boot_data$soc_g_kg
      )
      
      if (!is.null(boot_fit)) {
        boot_pred <- predict(boot_fit, x = standard_depths)
        boot_predictions[i, ] <- boot_pred$y
      }
    }
    
    # Calculate confidence intervals
    ci_level <- CONFIDENCE_LEVEL
    alpha <- 1 - ci_level
    
    result$soc_lower <- apply(boot_predictions, 2, 
                               function(x) quantile(x, alpha/2, na.rm = TRUE))
    result$soc_upper <- apply(boot_predictions, 2, 
                               function(x) quantile(x, 1 - alpha/2, na.rm = TRUE))
    result$soc_se <- apply(boot_predictions, 2, 
                           function(x) sd(x, na.rm = TRUE))
  }
  
  return(result)
}

#' Calculate fit diagnostics for a core
#' @param core_data Data for single core
#' @param spline_fit Fitted spline object
#' @return List of diagnostic metrics
calculate_diagnostics <- function(core_data, spline_fit) {
  
  if (is.null(spline_fit)) {
    return(NULL)
  }
  
  # Get fitted values
  fitted_values <- predict(spline_fit, x = core_data$depth_cm)$y
  
  # Calculate residuals
  residuals <- core_data$soc_g_kg - fitted_values
  
  # Metrics
  rmse <- sqrt(mean(residuals^2))
  mae <- mean(abs(residuals))
  r2 <- 1 - sum(residuals^2) / sum((core_data$soc_g_kg - mean(core_data$soc_g_kg))^2)
  
  return(list(
    rmse = rmse,
    mae = mae,
    r2 = r2,
    n_samples = nrow(core_data)
  ))
}

# ============================================================================
# HARMONIZE CORES BY STRATUM
# ============================================================================

log_message("Starting depth harmonization...")

harmonized_all <- list()
diagnostics_all <- list()

# Get unique strata
strata <- unique(cores_clean$stratum)

# Process each stratum separately
for (stratum_name in strata) {
  
  log_message(sprintf("\n=== Processing stratum: %s ===", stratum_name))
  
  # Filter to this stratum
  cores_stratum <- cores_clean %>%
    filter(stratum == stratum_name)
  
  n_cores <- n_distinct(cores_stratum$core_id)
  log_message(sprintf("Cores in %s: %d", stratum_name, n_cores))
  
  if (n_cores == 0) {
    log_message(sprintf("No cores in %s - skipping", stratum_name), "WARNING")
    next
  }
  
  # Process each core
  core_ids <- unique(cores_stratum$core_id)
  
  harmonized_stratum <- list()
  diagnostics_stratum <- list()
  
  n_success <- 0
  n_failed <- 0
  
  for (core_id in core_ids) {
    
    # Get data for this core
    core_data <- cores_stratum %>%
      filter(core_id == !!core_id) %>%
      arrange(depth_cm)
    
    # Check minimum samples
    if (nrow(core_data) < 3) {
      log_message(sprintf("Core %s: insufficient samples (n=%d)", 
                         core_id, nrow(core_data)), "WARNING")
      n_failed <- n_failed + 1
      next
    }
    
    # Fit spline
    spline_fit <- fit_smooth_spline(
      depths = core_data$depth_cm,
      values = core_data$soc_g_kg
    )
    
    if (is.null(spline_fit)) {
      log_message(sprintf("Core %s: spline fitting failed", core_id), "WARNING")
      n_failed <- n_failed + 1
      next
    }
    
    # Calculate diagnostics
    diag <- calculate_diagnostics(core_data, spline_fit)
    diagnostics_stratum[[core_id]] <- c(
      core_id = core_id,
      stratum = stratum_name,
      diag
    )
    
    # Predict at standard depths
    # Use bootstrap only if enabled and we have enough samples
    n_boot <- if (has_boot && nrow(core_data) >= 5) {
      BOOTSTRAP_ITERATIONS
    } else {
      0
    }
    
    harmonized <- predict_at_standard_depths(
      core_data = core_data,
      standard_depths = STANDARD_DEPTHS,
      n_boot = n_boot
    )
    
    if (!is.null(harmonized)) {
      harmonized_stratum[[core_id]] <- harmonized
      n_success <- n_success + 1
    } else {
      n_failed <- n_failed + 1
    }
  }
  
  log_message(sprintf("%s: %d successful, %d failed", 
                     stratum_name, n_success, n_failed))
  
  # Combine results for this stratum
  if (length(harmonized_stratum) > 0) {
    harmonized_all[[stratum_name]] <- bind_rows(harmonized_stratum)
    diagnostics_all[[stratum_name]] <- bind_rows(diagnostics_stratum)
  }
}

# ============================================================================
# COMBINE ALL STRATA
# ============================================================================

log_message("Combining harmonized data...")

harmonized_cores <- bind_rows(harmonized_all)
diagnostics_df <- bind_rows(diagnostics_all)

log_message(sprintf("Total harmonized predictions: %d from %d cores",
                    nrow(harmonized_cores),
                    n_distinct(harmonized_cores$core_id)))

# ============================================================================
# VALIDATION AND QA
# ============================================================================

log_message("Performing validation checks...")

# Check for unrealistic predictions
harmonized_cores <- harmonized_cores %>%
  mutate(
    qa_realistic = soc_spline >= 0 & soc_spline <= QC_SOC_MAX,
    qa_monotonic = TRUE  # Will check per core
  )

# Check monotonic decrease with depth (per core)
for (core_id in unique(harmonized_cores$core_id)) {
  core_pred <- harmonized_cores %>%
    filter(core_id == !!core_id) %>%
    arrange(depth_cm)
  
  # Check if generally decreasing (allowing some variation)
  if (nrow(core_pred) > 1) {
    # Calculate correlation with depth (should be negative)
    cor_depth <- cor(core_pred$depth_cm, core_pred$soc_spline)
    
    harmonized_cores$qa_monotonic[harmonized_cores$core_id == core_id] <- 
      cor_depth < -0.5  # Allow some flexibility
  }
}

n_unrealistic <- sum(!harmonized_cores$qa_realistic)
n_non_monotonic <- sum(!harmonized_cores$qa_monotonic)

if (n_unrealistic > 0) {
  log_message(sprintf("Warning: %d unrealistic predictions", n_unrealistic), "WARNING")
}

if (n_non_monotonic > 0) {
  log_message(sprintf("Warning: %d non-monotonic profiles", n_non_monotonic), "WARNING")
}

# ============================================================================
# CREATE DIAGNOSTIC PLOTS
# ============================================================================

log_message("Creating diagnostic plots...")

# Plot 1: Spline fit examples by stratum
for (stratum_name in strata) {
  
  cores_stratum <- cores_clean %>%
    filter(stratum == stratum_name)
  
  if (nrow(cores_stratum) == 0) next
  
  # Select up to 6 random cores to plot
  core_sample <- sample(unique(cores_stratum$core_id), 
                        min(6, n_distinct(cores_stratum$core_id)))
  
  plot_data <- cores_stratum %>%
    filter(core_id %in% core_sample)
  
  # Get harmonized predictions for these cores
  pred_data <- harmonized_cores %>%
    filter(core_id %in% core_sample)
  
  p <- ggplot() +
    # Original data
    geom_point(data = plot_data, 
               aes(x = soc_g_kg, y = -depth_cm),
               size = 2, alpha = 0.6) +
    # Spline predictions
    geom_line(data = pred_data,
              aes(x = soc_spline, y = -depth_cm, color = core_id),
              size = 1) +
    # CI if available
    {if ("soc_lower" %in% names(pred_data)) {
      geom_ribbon(data = pred_data,
                  aes(xmin = soc_lower, xmax = soc_upper, 
                      y = -depth_cm, group = core_id),
                  alpha = 0.2)
    }} +
    facet_wrap(~core_id, scales = "free_x") +
    labs(
      title = sprintf("Spline Fits: %s", stratum_name),
      subtitle = "Points = measured, Lines = spline predictions",
      x = "SOC (g/kg)",
      y = "Depth (cm)"
    ) +
    theme_minimal() +
    theme(legend.position = "none")
  
  ggsave(file.path("outputs/plots/by_stratum", 
                   sprintf("spline_fits_%s.png", gsub(" ", "_", stratum_name))),
         p, width = 12, height = 8, dpi = 300)
}

log_message("Saved spline fit plots")

# Plot 2: Diagnostics by stratum
if (nrow(diagnostics_df) > 0) {
  
  p_diag <- ggplot(diagnostics_df, aes(x = stratum, y = rmse, fill = stratum)) +
    geom_boxplot(alpha = 0.7) +
    scale_fill_manual(values = STRATUM_COLORS) +
    labs(
      title = "Spline Fit Quality by Stratum",
      x = "Stratum",
      y = "RMSE (g/kg)"
    ) +
    theme_minimal() +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1),
      legend.position = "none"
    )
  
  ggsave("diagnostics/spline_fit_rmse.png", p_diag, 
         width = 8, height = 6, dpi = 300)
  
  log_message("Saved diagnostic plots")
}

# ============================================================================
# SAVE RESULTS
# ============================================================================

log_message("Saving harmonized data...")

# Save harmonized cores
saveRDS(harmonized_cores, "data_processed/cores_harmonized_spline_bluecarbon.rds")
write.csv(harmonized_cores, "data_processed/cores_harmonized_spline_bluecarbon.csv",
          row.names = FALSE)

# Save diagnostics
saveRDS(diagnostics_df, "diagnostics/spline_diagnostics.rds")
write.csv(diagnostics_df, "diagnostics/spline_diagnostics.csv", row.names = FALSE)

log_message("Saved harmonized data and diagnostics")

# ============================================================================
# SUMMARY STATISTICS
# ============================================================================

log_message("Calculating summary statistics...")

# Overall summary
summary_overall <- harmonized_cores %>%
  filter(qa_realistic) %>%
  group_by(depth_cm) %>%
  summarise(
    n_cores = n_distinct(core_id),
    mean_soc = mean(soc_spline, na.rm = TRUE),
    sd_soc = sd(soc_spline, na.rm = TRUE),
    min_soc = min(soc_spline, na.rm = TRUE),
    max_soc = max(soc_spline, na.rm = TRUE),
    .groups = "drop"
  )

# Summary by stratum
summary_stratum <- harmonized_cores %>%
  filter(qa_realistic) %>%
  group_by(stratum, depth_cm) %>%
  summarise(
    n_cores = n_distinct(core_id),
    mean_soc = mean(soc_spline, na.rm = TRUE),
    sd_soc = sd(soc_spline, na.rm = TRUE),
    .groups = "drop"
  )

# Diagnostic summary
if (nrow(diagnostics_df) > 0) {
  diag_summary <- diagnostics_df %>%
    group_by(stratum) %>%
    summarise(
      n_cores = n(),
      mean_rmse = mean(rmse, na.rm = TRUE),
      mean_r2 = mean(r2, na.rm = TRUE),
      .groups = "drop"
    )
}

# ============================================================================
# FINAL SUMMARY
# ============================================================================

cat("\n========================================\n")
cat("MODULE 03 COMPLETE\n")
cat("========================================\n\n")

cat("Depth Harmonization Summary:\n")
cat("----------------------------------------\n")
cat(sprintf("Cores harmonized: %d\n", n_distinct(harmonized_cores$core_id)))
cat(sprintf("Standard depths: %d\n", length(STANDARD_DEPTHS)))
cat(sprintf("Total predictions: %d\n", nrow(harmonized_cores)))
cat(sprintf("Strata processed: %d\n", n_distinct(harmonized_cores$stratum)))

if (has_boot && "soc_lower" %in% names(harmonized_cores)) {
  cat(sprintf("Bootstrap CI: %d iterations (%.0f%% CI)\n", 
              BOOTSTRAP_ITERATIONS, CONFIDENCE_LEVEL * 100))
}

cat("\nQuality Checks:\n")
cat(sprintf("  Realistic predictions: %d/%d (%.1f%%)\n",
            sum(harmonized_cores$qa_realistic),
            nrow(harmonized_cores),
            100 * mean(harmonized_cores$qa_realistic)))
cat(sprintf("  Monotonic profiles: %d/%d cores (%.1f%%)\n",
            sum(!harmonized_cores$qa_monotonic) / length(STANDARD_DEPTHS),
            n_distinct(harmonized_cores$core_id),
            100 * (1 - sum(!harmonized_cores$qa_monotonic) / nrow(harmonized_cores))))

if (nrow(diagnostics_df) > 0) {
  cat("\nSpline Fit Quality by Stratum:\n")
  for (i in 1:nrow(diag_summary)) {
    cat(sprintf("  %s: RMSE=%.2f, R²=%.3f (n=%d)\n",
                diag_summary$stratum[i],
                diag_summary$mean_rmse[i],
                diag_summary$mean_r2[i],
                diag_summary$n_cores[i]))
  }
}

cat("\nSOC Range at Surface (0 cm) by Stratum:\n")
surface_summary <- harmonized_cores %>%
  filter(depth_cm == 0, qa_realistic) %>%
  group_by(stratum) %>%
  summarise(
    mean = mean(soc_spline),
    min = min(soc_spline),
    max = max(soc_spline),
    .groups = "drop"
  ) %>%
  arrange(desc(mean))

for (i in 1:nrow(surface_summary)) {
  cat(sprintf("  %s: %.1f g/kg (range: %.1f - %.1f)\n",
              surface_summary$stratum[i],
              surface_summary$mean[i],
              surface_summary$min[i],
              surface_summary$max[i]))
}

cat("\nOutputs:\n")
cat("  Harmonized data: data_processed/cores_harmonized_spline_bluecarbon.rds\n")
cat("  Diagnostics: diagnostics/spline_diagnostics.rds\n")
cat("  Plots: outputs/plots/by_stratum/spline_fits_*.png\n")

cat("\nNext steps:\n")
cat("  1. Review spline fit plots in outputs/plots/by_stratum/\n")
cat("  2. Check diagnostics in diagnostics/spline_diagnostics.csv\n")
cat("  3. Run: source('04_raster_predictions_kriging_bluecarbon.R')\n\n")

log_message("=== MODULE 03 COMPLETE ===")
