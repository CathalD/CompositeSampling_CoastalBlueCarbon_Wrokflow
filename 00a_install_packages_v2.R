# ============================================================================
# MODULE 00a: BLUE CARBON - PACKAGE INSTALLATION (BINARY VERSIONS)
# ============================================================================
# PURPOSE: Install all required R packages using binary versions (faster/easier)
# USAGE: Run this FIRST, then run 00b_setup_directories.R
# ============================================================================

cat("========================================\n")
cat("BLUE CARBON - PACKAGE INSTALLATION\n")
cat("Using binary packages (recommended)\n")
cat("========================================\n\n")

# ============================================================================
# CONFIGURATION
# ============================================================================

options(
  warn = 1,
  repos = c(CRAN = "https://cloud.r-project.org/")
)

# Create logs directory if it doesn't exist
if (!dir.exists("logs")) {
  dir.create("logs", recursive = TRUE, showWarnings = FALSE)
}

log_file <- file.path("logs", paste0("package_install_log_", Sys.Date(), ".txt"))
log_message <- function(msg, level = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  log_entry <- sprintf("[%s] %s: %s", timestamp, level, msg)
  cat(log_entry, "\n")
  # Error handling for log file
  tryCatch({
    cat(log_entry, "\n", file = log_file, append = TRUE)
  }, error = function(e) {
    # Silently continue if log file can't be written
  })
}

log_message("Starting package installation (binary mode)")

# ============================================================================
# CHECK R VERSION
# ============================================================================

cat("Checking R version...\n")
r_version_string <- R.version$version.string
cat("  ", r_version_string, "\n")

if (as.numeric(R.version$major) < 4) {
  cat("  ⚠ R version 4.0+ recommended\n\n")
} else {
  cat("  ✓ R version OK\n\n")
}

log_message(r_version_string)

# ============================================================================
# DEFINE REQUIRED PACKAGES
# ============================================================================

core_packages <- c("dplyr", "tidyr", "ggplot2", "readr")
analysis_packages <- c("gridExtra", "corrplot", "lubridate")
spatial_packages <- c("sf", "raster", "terra", "gstat", "spdep")
modeling_packages <- c("nlme", "mgcv", "splines", "randomForest", "caret", "boot")
bluecarbon_packages <- c("CAST", "aqp")
reporting_packages <- c("openxlsx", "knitr")  # For Module 07 (MMRV reports)

# Optional but useful
optional_packages <- c("automap", "here", "viridis", "writexl")

required_packages <- c(
  core_packages,
  analysis_packages,
  spatial_packages,
  modeling_packages,
  bluecarbon_packages,
  reporting_packages
)

cat("Package Summary:\n")
cat(sprintf("  Required: %d packages\n", length(required_packages)))
cat(sprintf("  Optional: %d packages\n\n", length(optional_packages)))

# ============================================================================
# SIMPLE INSTALLATION FUNCTION (BINARY FIRST)
# ============================================================================

install_package_binary <- function(pkg) {
  
  # Check if already installed
  if (requireNamespace(pkg, quietly = TRUE)) {
    cat(sprintf("  ✓ %s (already installed)\n", pkg))
    log_message(sprintf("%s already installed", pkg))
    return(TRUE)
  }
  
  # Try binary installation
  cat(sprintf("  Installing %s (binary)... ", pkg))
  
  success <- tryCatch({
    install.packages(pkg, 
                    dependencies = TRUE,
                    quiet = TRUE,
                    type = "binary",
                    repos = "https://cloud.r-project.org/")
    
    # Verify
    if (requireNamespace(pkg, quietly = TRUE)) {
      cat("✓\n")
      log_message(sprintf("Installed %s (binary)", pkg))
      TRUE
    } else {
      cat("✗ (verification failed)\n")
      log_message(sprintf("%s binary install failed verification", pkg), "ERROR")
      FALSE
    }
    
  }, error = function(e) {
    cat(sprintf("✗ (%s)\n", e$message))
    log_message(sprintf("Error installing %s: %s", pkg, e$message), "ERROR")
    FALSE
  })
  
  # If binary failed, try source as fallback
  if (!success) {
    cat(sprintf("  Trying %s from source... ", pkg))
    
    success <- tryCatch({
      install.packages(pkg,
                      dependencies = TRUE,
                      quiet = TRUE,
                      type = "source",
                      repos = "https://cloud.r-project.org/")
      
      if (requireNamespace(pkg, quietly = TRUE)) {
        cat("✓\n")
        log_message(sprintf("Installed %s (source)", pkg))
        TRUE
      } else {
        cat("✗\n")
        log_message(sprintf("%s source install also failed", pkg), "ERROR")
        FALSE
      }
      
    }, error = function(e) {
      cat(sprintf("✗ (%s)\n", e$message))
      FALSE
    })
  }
  
  return(success)
}

# ============================================================================
# INSTALL PACKAGES BY CATEGORY
# ============================================================================

cat("\n========================================\n")
cat("INSTALLING PACKAGES\n")
cat("========================================\n\n")

# Track results
results <- list()

# Core packages
cat("CORE PACKAGES:\n")
core_results <- sapply(core_packages, install_package_binary)
results$core <- sum(core_results)
cat(sprintf("  Success: %d/%d\n\n", sum(core_results), length(core_packages)))

# Analysis packages
cat("ANALYSIS PACKAGES:\n")
analysis_results <- sapply(analysis_packages, install_package_binary)
results$analysis <- sum(analysis_results)
cat(sprintf("  Success: %d/%d\n\n", sum(analysis_results), length(analysis_packages)))

# Spatial packages
cat("SPATIAL PACKAGES:\n")
cat("  Note: May require system libraries (GDAL, PROJ, GEOS)\n")
cat("  Mac: brew install gdal proj geos\n")
cat("  Ubuntu: sudo apt-get install gdal-bin libgdal-dev libproj-dev\n\n")
spatial_results <- sapply(spatial_packages, install_package_binary)
results$spatial <- sum(spatial_results)
cat(sprintf("  Success: %d/%d\n\n", sum(spatial_results), length(spatial_packages)))

# Modeling packages
cat("MODELING PACKAGES:\n")
modeling_results <- sapply(modeling_packages, install_package_binary)
results$modeling <- sum(modeling_results)
cat(sprintf("  Success: %d/%d\n\n", sum(modeling_results), length(modeling_packages)))

# Blue carbon specific
cat("BLUE CARBON PACKAGES:\n")
bluecarbon_results <- sapply(bluecarbon_packages, install_package_binary)
results$bluecarbon <- sum(bluecarbon_results)
cat(sprintf("  Success: %d/%d\n\n", sum(bluecarbon_results), length(bluecarbon_packages)))

# Reporting packages
cat("REPORTING PACKAGES:\n")
reporting_results <- sapply(reporting_packages, install_package_binary)
results$reporting <- sum(reporting_results)
cat(sprintf("  Success: %d/%d\n\n", sum(reporting_results), length(reporting_packages)))

# Optional packages
cat("\n========================================\n")
cat("OPTIONAL PACKAGES\n")
cat("========================================\n\n")

cat("Installing optional packages...\n")
optional_results <- sapply(optional_packages, install_package_binary)
results$optional <- sum(optional_results)
cat(sprintf("  Success: %d/%d\n\n", sum(optional_results), length(optional_packages)))

# ============================================================================
# FINAL VERIFICATION
# ============================================================================

cat("\n========================================\n")
cat("INSTALLATION COMPLETE\n")
cat("========================================\n\n")

# Check all required packages
all_installed <- sapply(required_packages, 
                       function(pkg) requireNamespace(pkg, quietly = TRUE))

total_required <- length(required_packages)
total_installed <- sum(all_installed)
success_rate <- round(100 * total_installed / total_required, 1)

cat("Summary:\n")
cat("----------------------------------------\n")
cat(sprintf("Required packages: %d\n", total_required))
cat(sprintf("Installed: %d\n", total_installed))
cat(sprintf("Missing: %d\n", total_required - total_installed))
cat(sprintf("Success rate: %.1f%%\n\n", success_rate))

# List missing packages
missing_packages <- required_packages[!all_installed]
if (length(missing_packages) > 0) {
  cat("Missing packages:\n")
  for (pkg in missing_packages) {
    cat(sprintf("  ✗ %s\n", pkg))
  }
  cat("\n")
}

# Check critical packages
critical_packages <- c("dplyr", "ggplot2", "sf", "terra", "gstat", "openxlsx")
critical_installed <- sapply(critical_packages,
                             function(pkg) requireNamespace(pkg, quietly = TRUE))

cat("Critical packages:\n")
for (i in seq_along(critical_packages)) {
  status <- if (critical_installed[i]) "✓" else "✗"
  cat(sprintf("  %s %s\n", status, critical_packages[i]))
}
cat("\n")

# Save summary
if (!dir.exists("data_processed")) {
  dir.create("data_processed", recursive = TRUE, showWarnings = FALSE)
}

install_summary <- list(
  date = Sys.Date(),
  r_version = r_version_string,
  total_required = total_required,
  total_installed = total_installed,
  success_rate = success_rate,
  missing_packages = missing_packages,
  installation_method = "binary (with source fallback)"
)

# Save summary with error handling
summary_saved <- tryCatch({
  saveRDS(install_summary, "data_processed/package_install_summary.rds")
  TRUE
}, error = function(e) {
  cat("Warning: Could not save installation summary\n")
  FALSE
})

if (summary_saved) {
  cat("Installation summary saved to: data_processed/package_install_summary.rds\n")
}
cat("Log file:", log_file, "\n\n")

# ============================================================================
# NEXT STEPS
# ============================================================================

if (success_rate == 100) {
  cat("✓✓✓ ALL PACKAGES INSTALLED!\n\n")
  cat("Next step:\n")
  cat("  source('00b_setup_directories.R')\n\n")
  
} else if (success_rate >= 90) {
  cat(sprintf("✓ MOSTLY COMPLETE (%.1f%%)\n\n", success_rate))
  cat("Core packages installed, some optional features may be unavailable.\n\n")
  cat("Next step:\n")
  cat("  source('00b_setup_directories.R')\n\n")

} else {
  cat(sprintf("⚠ INCOMPLETE (%.1f%%)\n\n", success_rate))
  
  if (length(missing_packages) > 0) {
    cat("Try installing missing packages manually:\n")
    cat(sprintf("install.packages(c(%s), type = 'binary')\n\n",
                paste(sprintf('"%s"', missing_packages), collapse = ", ")))
  }
  
  cat("For spatial packages, you may need:\n")
  cat("  Mac: brew install gdal proj geos\n")
  cat("  Ubuntu: sudo apt-get install gdal-bin libgdal-dev libproj-dev\n\n")
}

log_message(sprintf("Package installation complete - %.1f%% success", success_rate))

cat("Done! 🌊\n\n")
