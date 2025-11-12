# ============================================================================
# MODULE 02: BLUE CARBON EXPLORATORY DATA ANALYSIS
# ============================================================================
# PURPOSE: Visualize and explore patterns in blue carbon data by stratum
# INPUTS: 
#   - data_processed/cores_clean_bluecarbon.rds
# OUTPUTS: 
#   - outputs/plots/exploratory/ (multiple figures)
#   - data_processed/eda_summary.rds
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
log_file <- file.path("logs", paste0("exploratory_analysis_", Sys.Date(), ".log"))
if (!dir.exists("logs")) dir.create("logs")

log_message <- function(msg, level = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  log_entry <- sprintf("[%s] %s: %s", timestamp, level, msg)
  cat(log_entry, "\n")
  cat(log_entry, "\n", file = log_file, append = TRUE)
}

log_message("=== MODULE 02: EXPLORATORY DATA ANALYSIS ===")

# Load packages
suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(gridExtra)
})

# Resolve namespace conflicts
select <- dplyr::select
filter <- dplyr::filter

log_message("Packages loaded successfully")

# Set ggplot theme
theme_set(theme_minimal(base_size = 12))

# Create output directory
plot_dir <- "outputs/plots/exploratory"
if (!dir.exists(plot_dir)) {
  dir.create(plot_dir, recursive = TRUE)
}

# ============================================================================
# LOAD DATA
# ============================================================================

log_message("Loading cleaned data...")

if (!file.exists("data_processed/cores_clean_bluecarbon.rds")) {
  stop("Cleaned data not found. Run 01_data_prep_bluecarbon.R first.")
}

cores <- readRDS("data_processed/cores_clean_bluecarbon.rds")

log_message(sprintf("Loaded: %d samples from %d cores",
                    nrow(cores),
                    n_distinct(cores$core_id)))

# Filter to QA-passed samples only
cores_clean <- cores %>%
  filter(qa_pass)

log_message(sprintf("After QA filter: %d samples from %d cores",
                    nrow(cores_clean),
                    n_distinct(cores_clean$core_id)))

# ============================================================================
# SUMMARY STATISTICS
# ============================================================================

log_message("Calculating summary statistics...")

# Overall statistics
overall_stats <- cores_clean %>%
  summarise(
    n_cores = n_distinct(core_id),
    n_samples = n(),
    n_strata = n_distinct(stratum),
    mean_soc = mean(soc_g_kg, na.rm = TRUE),
    sd_soc = sd(soc_g_kg, na.rm = TRUE),
    min_soc = min(soc_g_kg, na.rm = TRUE),
    max_soc = max(soc_g_kg, na.rm = TRUE),
    mean_bd = mean(bulk_density_g_cm3, na.rm = TRUE),
    sd_bd = sd(bulk_density_g_cm3, na.rm = TRUE),
    mean_depth = mean(depth_cm, na.rm = TRUE),
    max_depth = max(depth_bottom_cm, na.rm = TRUE)
  )

cat("\n=== OVERALL STATISTICS ===\n")
print(overall_stats)

# Stratum-specific statistics
stratum_stats <- cores_clean %>%
  group_by(stratum) %>%
  summarise(
    n_cores = n_distinct(core_id),
    n_samples = n(),
    mean_soc = mean(soc_g_kg, na.rm = TRUE),
    sd_soc = sd(soc_g_kg, na.rm = TRUE),
    mean_bd = mean(bulk_density_g_cm3, na.rm = TRUE),
    sd_bd = sd(bulk_density_g_cm3, na.rm = TRUE),
    mean_depth = mean(depth_cm, na.rm = TRUE),
    mean_carbon_stock = mean(carbon_stock_mg_ha, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(mean_soc))

cat("\n=== STATISTICS BY STRATUM ===\n")
print(stratum_stats)

# ============================================================================
# PLOT 1: SPATIAL DISTRIBUTION OF CORES
# ============================================================================

log_message("Creating spatial distribution plot...")

p_spatial <- ggplot(cores_clean %>% distinct(core_id, .keep_all = TRUE),
                    aes(x = longitude, y = latitude, color = stratum)) +
  geom_point(size = 3, alpha = 0.7) +
  scale_color_manual(values = STRATUM_COLORS) +
  labs(
    title = "Spatial Distribution of Core Locations",
    subtitle = sprintf("n = %d cores across %d strata", 
                       n_distinct(cores_clean$core_id),
                       n_distinct(cores_clean$stratum)),
    x = "Longitude",
    y = "Latitude",
    color = "Stratum"
  ) +
  theme(
    legend.position = "right",
    plot.title = element_text(face = "bold", size = 14)
  )

ggsave(file.path(plot_dir, "01_spatial_distribution.png"),
       p_spatial, width = FIGURE_WIDTH, height = FIGURE_HEIGHT, dpi = FIGURE_DPI)

log_message("Saved: 01_spatial_distribution.png")

# ============================================================================
# PLOT 2: SOC DISTRIBUTION BY STRATUM
# ============================================================================

log_message("Creating SOC distribution plots...")

# Boxplot
p_soc_box <- ggplot(cores_clean, aes(x = reorder(stratum, -soc_g_kg), 
                                      y = soc_g_kg, 
                                      fill = stratum)) +
  geom_boxplot(alpha = 0.7) +
  scale_fill_manual(values = STRATUM_COLORS) +
  labs(
    title = "SOC Distribution by Stratum",
    x = "Stratum",
    y = "SOC (g/kg)",
    fill = "Stratum"
  ) +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    legend.position = "none",
    plot.title = element_text(face = "bold")
  )

# Violin plot
p_soc_violin <- ggplot(cores_clean, aes(x = reorder(stratum, -soc_g_kg), 
                                         y = soc_g_kg, 
                                         fill = stratum)) +
  geom_violin(alpha = 0.7) +
  geom_boxplot(width = 0.2, alpha = 0.3) +
  scale_fill_manual(values = STRATUM_COLORS) +
  labs(
    title = "SOC Distribution by Stratum (Violin Plot)",
    x = "Stratum",
    y = "SOC (g/kg)",
    fill = "Stratum"
  ) +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    legend.position = "none",
    plot.title = element_text(face = "bold")
  )

# Combine
p_soc_combined <- grid.arrange(p_soc_box, p_soc_violin, ncol = 2)

ggsave(file.path(plot_dir, "02_soc_distribution_by_stratum.png"),
       p_soc_combined, width = FIGURE_WIDTH * 1.5, height = FIGURE_HEIGHT, dpi = FIGURE_DPI)

log_message("Saved: 02_soc_distribution_by_stratum.png")

# ============================================================================
# PLOT 3: DEPTH PROFILES BY STRATUM
# ============================================================================

log_message("Creating depth profile plots...")

# Calculate mean SOC by depth and stratum
depth_profiles <- cores_clean %>%
  group_by(stratum, depth_cm) %>%
  summarise(
    mean_soc = mean(soc_g_kg, na.rm = TRUE),
    se_soc = sd(soc_g_kg, na.rm = TRUE) / sqrt(n()),
    n = n(),
    .groups = "drop"
  )

p_depth_profiles <- ggplot(depth_profiles, aes(x = mean_soc, y = -depth_cm, 
                                                color = stratum, group = stratum)) +
  geom_line(size = 1) +
  geom_point(aes(size = n), alpha = 0.6) +
  geom_errorbarh(aes(xmin = mean_soc - se_soc, xmax = mean_soc + se_soc),
                 height = 2, alpha = 0.4) +
  scale_color_manual(values = STRATUM_COLORS) +
  scale_size_continuous(range = c(2, 6)) +
  labs(
    title = "SOC Depth Profiles by Stratum",
    subtitle = "Lines show mean SOC, error bars show ±SE, point size shows sample size",
    x = "SOC (g/kg)",
    y = "Depth (cm)",
    color = "Stratum",
    size = "n samples"
  ) +
  theme(
    plot.title = element_text(face = "bold"),
    legend.position = "right"
  ) +
  facet_wrap(~stratum, scales = "free_x")

ggsave(file.path(plot_dir, "03_depth_profiles_by_stratum.png"),
       p_depth_profiles, width = FIGURE_WIDTH * 1.5, height = FIGURE_HEIGHT * 1.2, dpi = FIGURE_DPI)

log_message("Saved: 03_depth_profiles_by_stratum.png")

# ============================================================================
# PLOT 4: BULK DENSITY PATTERNS
# ============================================================================

log_message("Creating bulk density plots...")

# BD by stratum
p_bd_stratum <- ggplot(cores_clean, aes(x = reorder(stratum, bulk_density_g_cm3), 
                                         y = bulk_density_g_cm3, 
                                         fill = stratum)) +
  geom_boxplot(alpha = 0.7) +
  scale_fill_manual(values = STRATUM_COLORS) +
  labs(
    title = "Bulk Density by Stratum",
    x = "Stratum",
    y = "Bulk Density (g/cm³)",
    fill = "Stratum"
  ) +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    legend.position = "none",
    plot.title = element_text(face = "bold")
  )

# BD vs depth by stratum
p_bd_depth <- ggplot(cores_clean, aes(x = bulk_density_g_cm3, y = -depth_cm, 
                                      color = stratum)) +
  geom_point(alpha = 0.5) +
  geom_smooth(method = "loess", se = TRUE, alpha = 0.2) +
  scale_color_manual(values = STRATUM_COLORS) +
  labs(
    title = "Bulk Density vs Depth by Stratum",
    x = "Bulk Density (g/cm³)",
    y = "Depth (cm)",
    color = "Stratum"
  ) +
  theme(
    plot.title = element_text(face = "bold")
  ) +
  facet_wrap(~stratum, scales = "free_x")

# BD vs SOC
p_bd_soc <- ggplot(cores_clean, aes(x = soc_g_kg, y = bulk_density_g_cm3, 
                                    color = stratum)) +
  geom_point(alpha = 0.5) +
  geom_smooth(method = "lm", se = TRUE, alpha = 0.2) +
  scale_color_manual(values = STRATUM_COLORS) +
  labs(
    title = "Bulk Density vs SOC by Stratum",
    subtitle = "Lines show linear regression",
    x = "SOC (g/kg)",
    y = "Bulk Density (g/cm³)",
    color = "Stratum"
  ) +
  theme(
    plot.title = element_text(face = "bold")
  )

# Combine BD plots
p_bd_combined <- grid.arrange(
  p_bd_stratum, 
  p_bd_soc, 
  ncol = 2
)

ggsave(file.path(plot_dir, "04_bulk_density_patterns.png"),
       p_bd_combined, width = FIGURE_WIDTH * 1.5, height = FIGURE_HEIGHT, dpi = FIGURE_DPI)

ggsave(file.path(plot_dir, "04b_bulk_density_vs_depth.png"),
       p_bd_depth, width = FIGURE_WIDTH * 1.5, height = FIGURE_HEIGHT, dpi = FIGURE_DPI)

log_message("Saved: 04_bulk_density_patterns.png")

# ============================================================================
# PLOT 5: CARBON STOCK PATTERNS
# ============================================================================

log_message("Creating carbon stock plots...")

# Carbon stock by stratum
p_stock_stratum <- ggplot(cores_clean, aes(x = reorder(stratum, -carbon_stock_mg_ha), 
                                           y = carbon_stock_mg_ha, 
                                           fill = stratum)) +
  geom_boxplot(alpha = 0.7) +
  scale_fill_manual(values = STRATUM_COLORS) +
  labs(
    title = "Carbon Stock per Sample by Stratum",
    x = "Stratum",
    y = "Carbon Stock (Mg C/ha)",
    fill = "Stratum"
  ) +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    legend.position = "none",
    plot.title = element_text(face = "bold")
  )

# Total carbon stock by core
core_totals <- cores_clean %>%
  group_by(core_id, stratum) %>%
  summarise(
    total_stock = sum(carbon_stock_mg_ha, na.rm = TRUE),
    max_depth = max(depth_bottom_cm),
    .groups = "drop"
  )

p_stock_total <- ggplot(core_totals, aes(x = reorder(stratum, -total_stock), 
                                         y = total_stock, 
                                         fill = stratum)) +
  geom_boxplot(alpha = 0.7) +
  scale_fill_manual(values = STRATUM_COLORS) +
  labs(
    title = "Total Carbon Stock by Core",
    subtitle = sprintf("Summed across depth (n = %d cores)", nrow(core_totals)),
    x = "Stratum",
    y = "Total Carbon Stock (Mg C/ha)",
    fill = "Stratum"
  ) +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    legend.position = "none",
    plot.title = element_text(face = "bold")
  )

# Combine
p_stock_combined <- grid.arrange(p_stock_stratum, p_stock_total, ncol = 2)

ggsave(file.path(plot_dir, "05_carbon_stock_by_stratum.png"),
       p_stock_combined, width = FIGURE_WIDTH * 1.5, height = FIGURE_HEIGHT, dpi = FIGURE_DPI)

log_message("Saved: 05_carbon_stock_by_stratum.png")

# ============================================================================
# PLOT 6: CORE TYPE COMPARISON (HR vs COMPOSITE)
# ============================================================================

log_message("Creating core type comparison plots...")

if ("core_type" %in% names(cores_clean) && n_distinct(cores_clean$core_type) > 1) {
  
  # SOC comparison
  p_type_soc <- ggplot(cores_clean, aes(x = core_type, y = soc_g_kg, fill = core_type)) +
    geom_boxplot(alpha = 0.7) +
    labs(
      title = "SOC by Core Type",
      x = "Core Type",
      y = "SOC (g/kg)"
    ) +
    theme(legend.position = "none") +
    facet_wrap(~stratum)
  
  # Sample count
  type_counts <- cores_clean %>%
    group_by(stratum, core_type) %>%
    summarise(n_cores = n_distinct(core_id), .groups = "drop")
  
  p_type_count <- ggplot(type_counts, aes(x = stratum, y = n_cores, fill = core_type)) +
    geom_col(position = "dodge", alpha = 0.7) +
    labs(
      title = "Core Count by Type and Stratum",
      x = "Stratum",
      y = "Number of Cores",
      fill = "Core Type"
    ) +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  
  p_type_combined <- grid.arrange(p_type_count, p_type_soc, ncol = 2)
  
  ggsave(file.path(plot_dir, "06_core_type_comparison.png"),
         p_type_combined, width = FIGURE_WIDTH * 1.5, height = FIGURE_HEIGHT, dpi = FIGURE_DPI)
  
  log_message("Saved: 06_core_type_comparison.png")
} else {
  log_message("Skipping core type comparison (single type or missing data)", "WARNING")
}

# ============================================================================
# PLOT 7: DATA QUALITY FLAGS
# ============================================================================

log_message("Creating QA/QC summary plots...")

# Count QA issues
qa_summary <- cores %>%
  summarise(
    total_samples = n(),
    spatial_valid = sum(qa_spatial_valid, na.rm = TRUE),
    depth_valid = sum(qa_depth_valid, na.rm = TRUE),
    soc_valid = sum(qa_soc_valid, na.rm = TRUE),
    bd_valid = sum(qa_bd_valid, na.rm = TRUE),
    stratum_valid = sum(qa_stratum_valid, na.rm = TRUE),
    overall_pass = sum(qa_pass, na.rm = TRUE)
  )

qa_long <- qa_summary %>%
  select(-total_samples) %>%
  pivot_longer(everything(), names_to = "check", values_to = "passed") %>%
  mutate(
    failed = qa_summary$total_samples - passed,
    check = gsub("_", " ", check),
    check = tools::toTitleCase(check)
  )

p_qa <- ggplot(qa_long, aes(x = reorder(check, passed))) +
  geom_col(aes(y = passed), fill = "#2E7D32", alpha = 0.7) +
  geom_col(aes(y = failed), fill = "#C62828", alpha = 0.7) +
  coord_flip() +
  labs(
    title = "QA/QC Summary",
    subtitle = sprintf("Total samples: %d", qa_summary$total_samples),
    x = "",
    y = "Number of Samples"
  ) +
  theme(
    plot.title = element_text(face = "bold")
  )

ggsave(file.path(plot_dir, "07_qa_summary.png"),
       p_qa, width = FIGURE_WIDTH, height = FIGURE_HEIGHT * 0.8, dpi = FIGURE_DPI)

log_message("Saved: 07_qa_summary.png")

# ============================================================================
# PLOT 8: SUMMARY STATISTICS TABLE
# ============================================================================

log_message("Creating summary statistics table...")

# Format stratum stats for display
stratum_table <- stratum_stats %>%
  mutate(
    SOC = sprintf("%.1f ± %.1f", mean_soc, sd_soc),
    BD = sprintf("%.2f ± %.2f", mean_bd, sd_bd),
    `C Stock` = sprintf("%.1f", mean_carbon_stock)
  ) %>%
  select(Stratum = stratum, 
         `N Cores` = n_cores, 
         `N Samples` = n_samples,
         `SOC (g/kg)` = SOC,
         `BD (g/cm³)` = BD,
         `C Stock (Mg/ha)` = `C Stock`)

# Create table plot
table_grob <- gridExtra::tableGrob(stratum_table, rows = NULL)

p_table <- grid.arrange(
  table_grob,
  top = "Summary Statistics by Stratum\n(Mean ± SD)"
)

ggsave(file.path(plot_dir, "08_summary_table.png"),
       p_table, width = FIGURE_WIDTH * 1.2, height = FIGURE_HEIGHT * 0.8, dpi = FIGURE_DPI)

log_message("Saved: 08_summary_table.png")

# ============================================================================
# SAVE EDA SUMMARY
# ============================================================================

log_message("Saving EDA summary...")

eda_summary <- list(
  overall_stats = overall_stats,
  stratum_stats = stratum_stats,
  core_totals = core_totals,
  qa_summary = qa_summary,
  depth_profiles = depth_profiles,
  processing_date = Sys.Date(),
  n_plots_created = length(list.files(plot_dir, pattern = "\\.png$"))
)

saveRDS(eda_summary, "data_processed/eda_summary.rds")

log_message("Saved: eda_summary.rds")

# ============================================================================
# FINAL SUMMARY
# ============================================================================

cat("\n========================================\n")
cat("MODULE 02 COMPLETE\n")
cat("========================================\n\n")

cat("Exploratory Analysis Summary:\n")
cat("----------------------------------------\n")
cat(sprintf("Cores analyzed: %d\n", n_distinct(cores_clean$core_id)))
cat(sprintf("Samples analyzed: %d\n", nrow(cores_clean)))
cat(sprintf("Strata represented: %d\n", n_distinct(cores_clean$stratum)))
cat(sprintf("\nMean SOC: %.1f ± %.1f g/kg\n", 
            overall_stats$mean_soc, overall_stats$sd_soc))
cat(sprintf("Mean BD: %.2f ± %.2f g/cm³\n", 
            overall_stats$mean_bd, overall_stats$sd_bd))

cat("\nSOC by stratum (highest to lowest):\n")
for (i in 1:nrow(stratum_stats)) {
  cat(sprintf("  %s: %.1f g/kg (n=%d cores)\n",
              stratum_stats$stratum[i],
              stratum_stats$mean_soc[i],
              stratum_stats$n_cores[i]))
}

cat(sprintf("\nPlots created: %d\n", eda_summary$n_plots_created))
cat(sprintf("Output directory: %s\n", plot_dir))

cat("\nPlots created:\n")
cat("  01_spatial_distribution.png\n")
cat("  02_soc_distribution_by_stratum.png\n")
cat("  03_depth_profiles_by_stratum.png\n")
cat("  04_bulk_density_patterns.png\n")
cat("  05_carbon_stock_by_stratum.png\n")
cat("  06_core_type_comparison.png (if applicable)\n")
cat("  07_qa_summary.png\n")
cat("  08_summary_table.png\n")

cat("\nNext steps:\n")
cat("  1. Review plots in outputs/plots/exploratory/\n")
cat("  2. Check for any outliers or data quality issues\n")
cat("  3. Run: source('03_depth_harmonization_bluecarbon.R')\n\n")

log_message("=== MODULE 02 COMPLETE ===")
