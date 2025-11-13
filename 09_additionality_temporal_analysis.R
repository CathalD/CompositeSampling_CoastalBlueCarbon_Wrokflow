# ============================================================================
# MODULE 09: ADDITIONALITY & TEMPORAL CHANGE ANALYSIS
# ============================================================================
# PURPOSE: Calculate project vs baseline differences and temporal trends
# INPUTS:
#   - data_temporal/carbon_stocks_aligned.rds (from Module 08)
# OUTPUTS:
#   - outputs/additionality/*.csv, *.tif
#   - outputs/temporal_change/*.csv, *.tif, *.png
# ============================================================================
# IMPORTANT: Run Module 08 FIRST to harmonize temporal datasets
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
required_vars <- c("ADDITIONALITY_CONFIDENCE", "ADDITIONALITY_METHOD",
                   "MIN_YEARS_FOR_CHANGE", "VALID_SCENARIOS")
missing_vars <- required_vars[!sapply(required_vars, exists)]
if (length(missing_vars) > 0) {
  stop(sprintf("Configuration error: Missing required variables: %s\nPlease check blue_carbon_config.R",
               paste(missing_vars, collapse=", ")))
}

# Initialize logging
log_file <- file.path("logs", paste0("additionality_temporal_", Sys.Date(), ".log"))
if (!dir.exists("logs")) dir.create("logs")

log_message <- function(msg, level = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  log_entry <- sprintf("[%s] %s: %s", timestamp, level, msg)
  cat(log_entry, "\n")
  cat(log_entry, "\n", file = log_file, append = TRUE)
}

log_message("=== MODULE 09: ADDITIONALITY & TEMPORAL CHANGE ANALYSIS ===")

# Load packages
suppressPackageStartupMessages({
  library(terra)
  library(dplyr)
  library(readr)
  library(tidyr)
  library(ggplot2)
  library(stringr)
})

log_message("Packages loaded successfully")

# Create output directories
dir.create("outputs/additionality", recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/temporal_change", recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/temporal_change/plots", recursive = TRUE, showWarnings = FALSE)

# ============================================================================
# LOAD HARMONIZED TEMPORAL DATA
# ============================================================================

log_message("Loading harmonized temporal dataset...")

temporal_data_file <- "data_temporal/carbon_stocks_aligned.rds"

if (!file.exists(temporal_data_file)) {
  stop(sprintf("Temporal data file not found: %s\nPlease run Module 08 first.",
               temporal_data_file))
}

temporal_data <- readRDS(temporal_data_file)

metadata <- temporal_data$metadata
carbon_stocks <- temporal_data$carbon_stocks
stratum_coverage <- temporal_data$stratum_coverage
rasters <- temporal_data$rasters

log_message(sprintf("Loaded %d datasets:", nrow(metadata)))
for (i in 1:nrow(metadata)) {
  log_message(sprintf("  - %s (%d)", metadata$scenario[i], metadata$year[i]))
}

# ============================================================================
# ANALYZE WHAT COMPARISONS ARE POSSIBLE
# ============================================================================

log_message("\nDetermining possible analyses...")

has_baseline <- "BASELINE" %in% metadata$scenario
has_project <- "PROJECT" %in% metadata$scenario
n_years <- length(unique(metadata$year))

run_additionality <- has_baseline && has_project
run_temporal_change <- n_years >= 2

if (!run_additionality && !run_temporal_change) {
  stop("Insufficient data for any temporal analysis.\nNeed either: (1) BASELINE + PROJECT scenarios, or (2) Multiple years")
}

cat("\n========================================\n")
cat("ANALYSIS PLAN\n")
cat("========================================\n\n")

if (run_additionality) {
  cat("✓ Additionality Analysis (PROJECT - BASELINE)\n")
} else {
  cat("✗ Additionality Analysis (requires BASELINE and PROJECT)\n")
}

if (run_temporal_change) {
  cat(sprintf("✓ Temporal Change Analysis (%d time points)\n", n_years))
} else {
  cat("✗ Temporal Change Analysis (requires >= 2 years)\n")
}
cat("\n")

# ============================================================================
# PART A: ADDITIONALITY ANALYSIS (PROJECT - BASELINE)
# ============================================================================

if (run_additionality) {

  log_message("\n=== ADDITIONALITY ANALYSIS ===")

  # Get baseline and project data
  baseline_data <- carbon_stocks %>%
    filter(scenario == "BASELINE") %>%
    group_by(stratum) %>%
    summarise(
      baseline_year = first(year),
      baseline_surface_mean = mean(carbon_stock_surface_mean_Mg_ha, na.rm = TRUE),
      baseline_deep_mean = mean(carbon_stock_deep_mean_Mg_ha, na.rm = TRUE),
      baseline_total_mean = mean(carbon_stock_total_mean_Mg_ha, na.rm = TRUE),
      baseline_surface_se = mean(carbon_stock_surface_se_Mg_ha, na.rm = TRUE),
      baseline_total_se = mean(carbon_stock_total_se_Mg_ha, na.rm = TRUE),
      .groups = "drop"
    )

  project_data <- carbon_stocks %>%
    filter(scenario == "PROJECT") %>%
    group_by(stratum) %>%
    summarise(
      project_year = first(year),
      project_surface_mean = mean(carbon_stock_surface_mean_Mg_ha, na.rm = TRUE),
      project_deep_mean = mean(carbon_stock_deep_mean_Mg_ha, na.rm = TRUE),
      project_total_mean = mean(carbon_stock_total_mean_Mg_ha, na.rm = TRUE),
      project_surface_se = mean(carbon_stock_surface_se_Mg_ha, na.rm = TRUE),
      project_total_se = mean(carbon_stock_total_se_Mg_ha, na.rm = TRUE),
      .groups = "drop"
    )

  # Merge and calculate differences
  additionality <- inner_join(baseline_data, project_data, by = "stratum") %>%
    mutate(
      # Calculate differences (PROJECT - BASELINE)
      delta_surface_mean = project_surface_mean - baseline_surface_mean,
      delta_deep_mean = project_deep_mean - baseline_deep_mean,
      delta_total_mean = project_total_mean - baseline_total_mean,

      # Propagate uncertainty (add variances)
      delta_surface_var = baseline_surface_se^2 + project_surface_se^2,
      delta_total_var = baseline_total_se^2 + project_total_se^2,
      delta_surface_se = sqrt(delta_surface_var),
      delta_total_se = sqrt(delta_total_var),

      # Calculate 95% CI
      delta_surface_ci_lower = delta_surface_mean - 1.96 * delta_surface_se,
      delta_surface_ci_upper = delta_surface_mean + 1.96 * delta_surface_se,
      delta_total_ci_lower = delta_total_mean - 1.96 * delta_total_se,
      delta_total_ci_upper = delta_total_mean + 1.96 * delta_total_se,

      # Conservative estimate for VM0033 (95% CI lower bound)
      delta_surface_conservative = pmax(0, delta_surface_ci_lower),
      delta_total_conservative = pmax(0, delta_total_ci_lower),

      # Percent change
      pct_change_surface = 100 * delta_surface_mean / baseline_surface_mean,
      pct_change_total = 100 * delta_total_mean / baseline_total_mean,

      # T-test for significance
      t_stat_surface = delta_surface_mean / delta_surface_se,
      t_stat_total = delta_total_mean / delta_total_se,
      p_value_surface = 2 * pt(-abs(t_stat_surface), df = Inf),  # Z-test approximation
      p_value_total = 2 * pt(-abs(t_stat_total), df = Inf),

      # Significance flags
      significant_surface = p_value_surface < (1 - ADDITIONALITY_CONFIDENCE),
      significant_total = p_value_total < (1 - ADDITIONALITY_CONFIDENCE),

      # Effect size (Cohen's d)
      pooled_se_surface = sqrt((baseline_surface_se^2 + project_surface_se^2) / 2),
      cohens_d_surface = delta_surface_mean / pooled_se_surface,

      # Additionality assessment
      additionality_status = case_when(
        !significant_total ~ "Not Significant",
        delta_total_conservative <= 0 ~ "No Net Gain (conservative)",
        delta_total_conservative > 0 & delta_total_conservative < 5 ~ "Marginal (<5 Mg/ha)",
        delta_total_conservative >= 5 & delta_total_conservative < 20 ~ "Moderate (5-20 Mg/ha)",
        delta_total_conservative >= 20 ~ "Substantial (>20 Mg/ha)",
        TRUE ~ "Unknown"
      )
    )

  cat("\n========================================\n")
  cat("ADDITIONALITY BY STRATUM\n")
  cat("========================================\n\n")

  for (i in 1:nrow(additionality)) {
    cat(sprintf("Stratum: %s\n", additionality$stratum[i]))
    cat(sprintf("  Baseline (0-100 cm): %.2f ± %.2f Mg C/ha\n",
                additionality$baseline_total_mean[i],
                additionality$baseline_total_se[i]))
    cat(sprintf("  Project (0-100 cm):  %.2f ± %.2f Mg C/ha\n",
                additionality$project_total_mean[i],
                additionality$project_total_se[i]))
    cat(sprintf("  Difference (mean):   %.2f ± %.2f Mg C/ha (%.1f%%)\n",
                additionality$delta_total_mean[i],
                additionality$delta_total_se[i],
                additionality$pct_change_total[i]))
    cat(sprintf("  95%% CI: [%.2f, %.2f] Mg C/ha\n",
                additionality$delta_total_ci_lower[i],
                additionality$delta_total_ci_upper[i]))
    cat(sprintf("  Conservative estimate: %.2f Mg C/ha\n",
                additionality$delta_total_conservative[i]))
    cat(sprintf("  Significance: %s (p = %.4f)\n",
                ifelse(additionality$significant_total[i], "YES", "NO"),
                additionality$p_value_total[i]))
    cat(sprintf("  Status: %s\n", additionality$additionality_status[i]))
    cat("\n")
  }

  # Save additionality results
  write_csv(additionality, "outputs/additionality/additionality_by_stratum.csv")
  log_message("Saved: outputs/additionality/additionality_by_stratum.csv")

  # Calculate project-wide additionality (area-weighted if area data available)
  project_wide <- additionality %>%
    summarise(
      n_strata = n(),
      mean_delta_total = mean(delta_total_mean, na.rm = TRUE),
      mean_delta_conservative = mean(delta_total_conservative, na.rm = TRUE),
      total_significant = sum(significant_total, na.rm = TRUE)
    )

  cat("========================================\n")
  cat("PROJECT-WIDE SUMMARY\n")
  cat("========================================\n\n")
  cat(sprintf("Strata analyzed: %d\n", project_wide$n_strata))
  cat(sprintf("Mean additionality: %.2f Mg C/ha\n", project_wide$mean_delta_total))
  cat(sprintf("Conservative estimate: %.2f Mg C/ha\n", project_wide$mean_delta_conservative))
  cat(sprintf("Significant strata: %d / %d\n\n", project_wide$total_significant, project_wide$n_strata))

  # ========================================================================
  # ADDITIONALITY RASTER MAPS
  # ========================================================================

  if (!is.null(rasters)) {
    log_message("\nCreating additionality raster maps...")

    # Find baseline and project rasters
    baseline_id <- sprintf("BASELINE_%d", unique(baseline_data$baseline_year))
    project_id <- sprintf("PROJECT_%d", unique(project_data$project_year))

    if (baseline_id %in% names(rasters) && project_id %in% names(rasters)) {

      # Calculate difference rasters for each depth
      for (depth_type in c("surface_mean", "total_mean", "surface_conservative", "total_conservative")) {

        if (depth_type %in% names(rasters[[baseline_id]]) &&
            depth_type %in% names(rasters[[project_id]])) {

          baseline_raster <- rasters[[baseline_id]][[depth_type]]
          project_raster <- rasters[[project_id]][[depth_type]]

          # Calculate difference
          diff_raster <- project_raster - baseline_raster

          # Save difference raster
          output_file <- file.path("outputs/additionality",
                                   sprintf("additionality_%s.tif", depth_type))
          writeRaster(diff_raster, output_file, overwrite = TRUE)
          log_message(sprintf("  Saved: additionality_%s.tif", depth_type))

          # Create significance map (where difference > 0)
          sig_raster <- ifel(diff_raster > 0, 1, 0)
          sig_file <- file.path("outputs/additionality",
                               sprintf("significance_%s.tif", depth_type))
          writeRaster(sig_raster, sig_file, overwrite = TRUE)
        }
      }

      log_message("Additionality raster maps created")
    } else {
      log_message("WARNING: Could not find baseline/project rasters for mapping", "WARNING")
    }
  }

} # End additionality analysis

# ============================================================================
# PART B: TEMPORAL CHANGE ANALYSIS (MULTI-PERIOD)
# ============================================================================

if (run_temporal_change) {

  log_message("\n=== TEMPORAL CHANGE ANALYSIS ===")

  # Calculate change over time for each stratum
  temporal_change <- carbon_stocks %>%
    arrange(stratum, year) %>%
    group_by(stratum) %>%
    mutate(
      n_years = n(),
      year_span = max(year) - min(year)
    ) %>%
    ungroup()

  # Calculate year-to-year changes
  temporal_trends <- carbon_stocks %>%
    arrange(stratum, scenario, year) %>%
    group_by(stratum, scenario) %>%
    summarise(
      n_timepoints = n(),
      years = paste(year, collapse = ", "),
      first_year = min(year),
      last_year = max(year),
      year_span = max(year) - min(year),

      # Carbon stocks at first and last timepoint
      carbon_t0 = first(carbon_stock_total_mean_Mg_ha),
      carbon_tn = last(carbon_stock_total_mean_Mg_ha),

      # Total change
      total_change = carbon_tn - carbon_t0,

      # Annualized rate (Mg C/ha/year)
      rate_Mg_ha_yr = ifelse(year_span > 0, total_change / year_span, NA),

      # Percent change
      pct_change = 100 * total_change / carbon_t0,

      .groups = "drop"
    )

  cat("\n========================================\n")
  cat("TEMPORAL TRENDS BY STRATUM\n")
  cat("========================================\n\n")

  for (i in 1:nrow(temporal_trends)) {
    cat(sprintf("Stratum: %s (%s)\n", temporal_trends$stratum[i], temporal_trends$scenario[i]))
    cat(sprintf("  Time span: %d years (%d - %d)\n",
                temporal_trends$year_span[i],
                temporal_trends$first_year[i],
                temporal_trends$last_year[i]))
    cat(sprintf("  Carbon at t0:  %.2f Mg C/ha\n", temporal_trends$carbon_t0[i]))
    cat(sprintf("  Carbon at tn:  %.2f Mg C/ha\n", temporal_trends$carbon_tn[i]))
    cat(sprintf("  Total change:  %.2f Mg C/ha (%.1f%%)\n",
                temporal_trends$total_change[i],
                temporal_trends$pct_change[i]))
    cat(sprintf("  Sequestration rate: %.3f Mg C/ha/yr\n",
                temporal_trends$rate_Mg_ha_yr[i]))
    cat("\n")
  }

  # Save temporal trends
  write_csv(temporal_trends, "outputs/temporal_change/temporal_trends_by_stratum.csv")
  log_message("Saved: outputs/temporal_change/temporal_trends_by_stratum.csv")

  # Create time series plot
  log_message("\nCreating time series plots...")

  for (stratum_name in unique(carbon_stocks$stratum)) {
    stratum_data <- carbon_stocks %>%
      filter(stratum == stratum_name)

    p <- ggplot(stratum_data, aes(x = year, y = carbon_stock_total_mean_Mg_ha, color = scenario)) +
      geom_line(size = 1) +
      geom_point(size = 3) +
      geom_errorbar(aes(ymin = carbon_stock_total_mean_Mg_ha - carbon_stock_total_se_Mg_ha,
                        ymax = carbon_stock_total_mean_Mg_ha + carbon_stock_total_se_Mg_ha),
                    width = 0.5) +
      labs(
        title = sprintf("Carbon Stock Trajectory: %s", stratum_name),
        x = "Year",
        y = "Total Carbon Stock (Mg C/ha)",
        color = "Scenario"
      ) +
      theme_bw() +
      theme(
        plot.title = element_text(size = 14, face = "bold"),
        axis.text = element_text(size = 10),
        legend.position = "bottom"
      )

    plot_file <- file.path("outputs/temporal_change/plots",
                          sprintf("trajectory_%s.png", gsub(" ", "_", tolower(stratum_name))))
    ggsave(plot_file, p, width = 8, height = 6, dpi = 300)
    log_message(sprintf("  Saved plot: %s", basename(plot_file)))
  }

} # End temporal change analysis

# ============================================================================
# SUMMARY REPORT
# ============================================================================

cat("\n========================================\n")
cat("ANALYSIS COMPLETE\n")
cat("========================================\n\n")

cat("Outputs created:\n")

if (run_additionality) {
  cat("  Additionality:\n")
  cat("    - outputs/additionality/additionality_by_stratum.csv\n")
  cat("    - outputs/additionality/additionality_*.tif (raster maps)\n")
}

if (run_temporal_change) {
  cat("  Temporal Change:\n")
  cat("    - outputs/temporal_change/temporal_trends_by_stratum.csv\n")
  cat("    - outputs/temporal_change/plots/*.png (time series)\n")
}

cat("\n")
cat("Next step: Generate final VM0033 verification package (Module 11)\n")
cat("\n")

log_message("=== MODULE 09 COMPLETE ===")
