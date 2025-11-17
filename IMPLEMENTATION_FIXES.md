# GRASSLAND WORKFLOW IMPLEMENTATION FIXES
## Critical Fixes for Production Deployment

**Document Version:** 1.0
**Date:** November 2024
**Status:** Implementation Guide
**Based On:** Comprehensive Technical Code Review

---

## 🎯 EXECUTIVE SUMMARY

This document provides implementation guidance for **10 critical fixes** identified in the technical code review of the Canadian Grassland Carbon MMRV workflow adaptation.

**Fix Status:**
- ✅ **Fixes #1-5 COMPLETED:** Variable aliases added to grassland_carbon_config.R
- ⚠️ **Fixes #6-10 PENDING:** Require module code modifications (documented below)

---

## ✅ PHASE 1: COMPLETED FIXES

### **FIX #1 & #2: Variable Compatibility Aliases** ✅ DONE
**Issue:** Modules expect `VM0033_*` variables but grassland config defines `GRASSLAND_*`
**Severity:** CRITICAL (blocking execution)

**Solution Implemented:**
```r
# Added to grassland_carbon_config.R lines 86-87, 231-235:

# Depth aliases
VM0033_DEPTH_INTERVALS <- GRASSLAND_DEPTH_INTERVALS
VM0033_DEPTH_MIDPOINTS <- GRASSLAND_DEPTH_MIDPOINTS

# Standards aliases
VM0033_MIN_CORES <- max(VM0026_MIN_CORES, VM0032_MIN_CORES, VM0042_MIN_CORES)
VM0033_TARGET_PRECISION <- GRASSLAND_TARGET_PRECISION
VM0033_ASSUMED_CV <- GRASSLAND_ASSUMED_CV
VM0033_CV_THRESHOLD <- GRASSLAND_CV_THRESHOLD
VM0033_MONITORING_FREQUENCY <- GRASSLAND_MONITORING_FREQUENCY
```

**Testing:**
```r
source("grassland_carbon_config.R")
stopifnot(exists("VM0033_DEPTH_INTERVALS"))
stopifnot(exists("VM0033_MIN_CORES"))
stopifnot(nrow(VM0033_DEPTH_INTERVALS) == 4)
stopifnot(VM0033_MIN_CORES == 5)  # Max of 5,5,5,3
print("✓ Variable aliases working correctly")
```

---

## ⚠️ PHASE 2: PENDING FIXES (Require Module Updates)

### **FIX #3: Auto-Detect Config Files** ⚠️ PENDING
**Issue:** Modules hardcode `blue_carbon_config.R` check
**Severity:** CRITICAL
**Files Affected:** All modules (01-10)

**Current Code:**
```r
# Module 01 line 35 (and similar in all modules):
if (file.exists("blue_carbon_config.R")) {
  source("blue_carbon_config.R")
} else {
  stop("Configuration file not found.")
}
```

**Required Fix:**
```r
# Replace in ALL modules (01, 02, 03, 04, 05, 06, 07, 08, 09, 10):

# Auto-detect ecosystem config file
config_file <- if (file.exists("grassland_carbon_config.R")) {
  "grassland_carbon_config.R"
} else if (file.exists("blue_carbon_config.R")) {
  "blue_carbon_config.R"
} else {
  stop("No configuration file found. Run setup script first.")
}

source(config_file)
log_message(sprintf("Configuration loaded: %s", basename(config_file)))
```

**Implementation Steps:**
1. Create a find-and-replace script:
```bash
# Bash script to update all modules
for file in 0{1..9}*.R 10*.R; do
  # Backup
  cp "$file" "$file.backup"

  # Replace config loading block
  sed -i 's/if (file.exists("blue_carbon_config.R"))/config_file <- if (file.exists("grassland_carbon_config.R")) "grassland_carbon_config.R" else if (file.exists("blue_carbon_config.R")/' "$file"
done
```

2. OR manually update each module (10 files)
3. Test with both configs

**Estimated Time:** 2 hours

---

### **FIX #6: Ecosystem-Aware File Naming** ⚠️ PENDING
**Issue:** Module 03 saves as `cores_harmonized_bluecarbon.rds` (hardcoded)
**Severity:** HIGH
**Files Affected:** 03_depth_harmonization_bluecarbon.R (line 1250)

**Required Fix in Module 03:**
```r
# Line 1250 (replace hardcoded naming):

# Auto-detect ecosystem type from config
ecosystem_suffix <- if (exists("GRASSLAND_DEPTH_MIDPOINTS") &&
                       exists("VM0026_ENABLED")) {
  "grassland"
} else {
  "bluecarbon"
}

# Use dynamic naming
output_file_rds <- sprintf("data_processed/cores_harmonized_%s.rds", ecosystem_suffix)
output_file_csv <- sprintf("data_processed/cores_harmonized_%s.csv", ecosystem_suffix)

saveRDS(harmonized_cores, output_file_rds)
write.csv(harmonized_cores, output_file_csv, row.names = FALSE)

log_message(sprintf("Saved harmonized cores: %s", output_file_rds))
```

**Required Fix in Modules 04-07 (loading):**
```r
# Replace hardcoded file path with fallback logic:

harmonized_file <- if (file.exists("data_processed/cores_harmonized_grassland.rds")) {
  "data_processed/cores_harmonized_grassland.rds"
} else if (file.exists("data_processed/cores_harmonized_bluecarbon.rds")) {
  "data_processed/cores_harmonized_bluecarbon.rds"
} else {
  stop("Harmonized cores not found. Run Module 03 first.")
}

cores_harmonized <- readRDS(harmonized_file)
log_message(sprintf("Loaded harmonized cores: %s", basename(harmonized_file)))
```

**Estimated Time:** 3 hours

---

### **FIX #7: Implement Root Biomass Calculation** ⚠️ PENDING
**Issue:** Config promises `INCLUDE_ROOT_BIOMASS` feature but Module 06 doesn't implement it
**Severity:** MEDIUM (feature gap)
**Files Affected:** 06_carbon_stock_calculation_bluecarbon.R

**Required Implementation:**

Add to Module 06 after carbon stock calculation (around line 450):

```r
# ============================================================================
# ROOT BIOMASS CARBON CALCULATION (GRASSLAND ECOSYSTEMS)
# ============================================================================

if (exists("INCLUDE_ROOT_BIOMASS") && INCLUDE_ROOT_BIOMASS) {

  log_message("\n=== ADDING ROOT BIOMASS TO CARBON STOCKS ===")

  if (!exists("ROOT_BIOMASS_METHOD")) {
    log_message("ROOT_BIOMASS_METHOD not defined, skipping", "WARNING")
  } else if (ROOT_BIOMASS_METHOD == "direct") {

    # DIRECT METHOD: Use measured root biomass
    log_message("Using direct root biomass measurements...")

    if (!"root_biomass_g_m2" %in% names(cores_harmonized)) {
      stop("ROOT_BIOMASS_METHOD='direct' requires 'root_biomass_g_m2' column in core data")
    }

    # Calculate root carbon
    cores_harmonized <- cores_harmonized %>%
      mutate(
        root_carbon_g_m2 = root_biomass_g_m2 * ROOT_CARBON_CONCENTRATION,
        root_carbon_Mg_ha = root_carbon_g_m2 / 100  # Convert g/m² to Mg/ha
      )

    # Aggregate by stratum
    root_stocks_by_stratum <- cores_harmonized %>%
      filter(depth_midpoint_cm <= ROOT_BIOMASS_DEPTH) %>%
      group_by(stratum) %>%
      summarise(
        root_carbon_mean_Mg_ha = mean(root_carbon_Mg_ha, na.rm = TRUE),
        root_carbon_sd_Mg_ha = sd(root_carbon_Mg_ha, na.rm = TRUE),
        root_carbon_se_Mg_ha = sd(root_carbon_Mg_ha, na.rm = TRUE) / sqrt(n()),
        n_cores = n_distinct(core_id),
        .groups = "drop"
      )

  } else if (ROOT_BIOMASS_METHOD == "ratio") {

    # RATIO METHOD: Estimate from shoot biomass using root:shoot ratios
    log_message("Using root:shoot ratio estimates...")

    if (!"shoot_biomass_g_m2" %in% names(cores_harmonized) &&
        !"anpp_g_m2" %in% names(cores_harmonized)) {
      log_message("No shoot biomass data (shoot_biomass_g_m2 or anpp_g_m2 column needed)", "WARNING")
      log_message("Using literature-based root:shoot ratios only", "INFO")

      # Use stratum-averaged shoot biomass (placeholder - ideally measured)
      # Typical grassland ANPP ranges:
      # Native Prairie: 200-400 g/m²
      # Improved Pasture: 300-500 g/m²
      # Degraded Grassland: 100-250 g/m²

      stratum_anpp_defaults <- data.frame(
        stratum = names(ROOT_SHOOT_RATIOS),
        shoot_biomass_g_m2 = c(300, 400, 150, 250, 350)  # Defaults by stratum
      )

      root_stocks_by_stratum <- stratum_anpp_defaults %>%
        mutate(
          root_shoot_ratio = sapply(stratum, function(s) ROOT_SHOOT_RATIOS[[s]]),
          root_biomass_g_m2 = shoot_biomass_g_m2 * root_shoot_ratio,
          root_carbon_g_m2 = root_biomass_g_m2 * ROOT_CARBON_CONCENTRATION,
          root_carbon_mean_Mg_ha = root_carbon_g_m2 / 100,
          root_carbon_sd_Mg_ha = root_carbon_mean_Mg_ha * 0.3,  # Assume 30% CV
          root_carbon_se_Mg_ha = NA,
          n_cores = 0
        ) %>%
        select(stratum, root_carbon_mean_Mg_ha, root_carbon_sd_Mg_ha,
               root_carbon_se_Mg_ha, n_cores)

      log_message("Using default ANPP values - REPLACE WITH MEASURED DATA", "WARNING")
    }

  } else {
    stop(sprintf("Unknown ROOT_BIOMASS_METHOD: %s (use 'direct' or 'ratio')",
                 ROOT_BIOMASS_METHOD))
  }

  # Merge root carbon with soil carbon stocks
  carbon_stocks_summary <- carbon_stocks_summary %>%
    left_join(root_stocks_by_stratum, by = "stratum") %>%
    mutate(
      # Add root carbon to total stocks
      total_carbon_with_roots_Mg_ha = mean_stock_0_100_Mg_ha +
                                       coalesce(root_carbon_mean_Mg_ha, 0),
      root_fraction_pct = 100 * root_carbon_mean_Mg_ha /
                          (mean_stock_0_100_Mg_ha + root_carbon_mean_Mg_ha)
    )

  log_message(sprintf("Root biomass added to %d strata",
                      sum(!is.na(carbon_stocks_summary$root_carbon_mean_Mg_ha))))

  # Log root fractions
  for (i in 1:nrow(carbon_stocks_summary)) {
    if (!is.na(carbon_stocks_summary$root_fraction_pct[i])) {
      log_message(sprintf("  %s: %.1f%% belowground (%s Mg C/ha roots)",
                          carbon_stocks_summary$stratum[i],
                          carbon_stocks_summary$root_fraction_pct[i],
                          round(carbon_stocks_summary$root_carbon_mean_Mg_ha[i], 1)))
    }
  }

} else {
  log_message("Root biomass calculation disabled (INCLUDE_ROOT_BIOMASS = FALSE)")
}
```

**Testing:**
```r
# Enable in config
INCLUDE_ROOT_BIOMASS <- TRUE
ROOT_BIOMASS_METHOD <- "ratio"

# Run Module 06
source("06_carbon_stock_calculation_bluecarbon.R")

# Check output
stocks <- read.csv("outputs/carbon_stocks/carbon_stocks_by_stratum.csv")
stopifnot("root_carbon_mean_Mg_ha" %in% names(stocks))
stopifnot("total_carbon_with_roots_Mg_ha" %in% names(stocks))
print("✓ Root biomass calculation working")
```

**Estimated Time:** 4-6 hours

---

### **FIX #8: Add Column Structure Validation** ⚠️ PENDING
**Issue:** Module 07b assumes specific column names exist
**Severity:** MEDIUM
**Files Affected:** 07b_comprehensive_standards_report_grassland.R

**Required Fix:**

Add validation function at start of Module 07b (after line 100):

```r
# Validate carbon stocks data structure
validate_carbon_stocks <- function(carbon_stocks) {

  required_cols <- c(
    "stratum",
    "mean_stock_0_100_Mg_ha",
    "conservative_stock_0_100_Mg_ha",
    "mean_stock_0_30_Mg_ha",  # Primary for grassland
    "total_stock_0_100_Mg"
  )

  missing_cols <- setdiff(required_cols, names(carbon_stocks))

  if (length(missing_cols) > 0) {
    log_message(sprintf("WARNING: Carbon stocks missing expected columns: %s",
                        paste(missing_cols, collapse=", ")), "WARNING")
    log_message(sprintf("Available columns: %s",
                        paste(names(carbon_stocks), collapse=", ")), "INFO")
    return(FALSE)
  }

  return(TRUE)
}

# Use in compliance checks:
if (!is.null(data$carbon_stocks)) {
  if (!validate_carbon_stocks(data$carbon_stocks)) {
    log_message("Carbon stocks validation failed - some checks may fail", "WARNING")
  }
}
```

**Estimated Time:** 1 hour

---

### **FIX #9: Make ECCC and Provincial Checks Actionable** ⚠️ PENDING
**Issue:** ECCC/Provincial checks are informational only (pass = NA)
**Severity:** MEDIUM
**Files Affected:** 07b_comprehensive_standards_report_grassland.R (lines 461-575)

**Required Enhancements:**

Replace in Module 07b:

```r
# ECCC Criterion 1: Grassland land use classification
# OLD (line 469-477):
check_function = function(data) {
  message <- "INFO: Verify land use classification..."
  list(pass = NA, value = "N/A", message = message)
}

# NEW (actionable):
check_function = function(data) {
  valid_ipcc_categories <- c(
    "Grassland Remaining Grassland", "Land Converted to Grassland",
    "BASELINE", "PROJECT", "NATIVE", "DEGRADED", "CROPLAND"
  )

  if (!is.null(data$cores) && "scenario_type" %in% names(data$cores)) {
    scenarios <- unique(data$cores$scenario_type)
    all_valid <- all(scenarios %in% valid_ipcc_categories)

    message <- if (all_valid) {
      sprintf("✓ Scenarios align with IPCC categories: %s",
              paste(scenarios, collapse=", "))
    } else {
      invalid <- setdiff(scenarios, valid_ipcc_categories)
      sprintf("WARNING: Non-IPCC scenario types detected: %s. Update to match IPCC land use categories.",
              paste(invalid, collapse=", "))
    }

    list(pass = all_valid, value = paste(scenarios, collapse=", "), message = message)
  } else {
    list(pass = NA, value = "N/A",
         message = "INFO: No scenario_type column in cores data. Verify IPCC classification manually.")
  }
}

# Provincial Criterion 1: Alberta CRS validation
# OLD (line 517-523):
message <- sprintf("INFO: Project location: %s. Verify alignment...", PROJECT_LOCATION)
list(pass = NA, value = "N/A", message = message)

# NEW (actionable):
alberta_crs_codes <- c(3400, 3402, 32612)  # Alberta-specific
saskatchewan_crs_codes <- c(2955, 2151)
manitoba_crs_codes <- c(2957, 3158)

# Detect province from location
is_alberta <- grepl("Alberta|AB", PROJECT_LOCATION, ignore.case = TRUE)
is_saskatchewan <- grepl("Saskatchewan|SK", PROJECT_LOCATION, ignore.case = TRUE)
is_manitoba <- grepl("Manitoba|MB", PROJECT_LOCATION, ignore.case = TRUE)

valid_crs <- if (is_alberta) {
  alberta_crs_codes
} else if (is_saskatchewan) {
  saskatchewan_crs_codes
} else if (is_manitoba) {
  manitoba_crs_codes
} else {
  c(alberta_crs_codes, saskatchewan_crs_codes, manitoba_crs_codes, 3347)  # Allow any Canadian
}

is_valid_crs <- PROCESSING_CRS %in% valid_crs

message <- if (is_valid_crs) {
  sprintf("✓ CRS appropriate for %s (EPSG:%d)", PROJECT_LOCATION, PROCESSING_CRS)
} else {
  sprintf("WARNING: CRS (EPSG:%d) may not be optimal for %s. Recommended: %s",
          PROCESSING_CRS, PROJECT_LOCATION,
          paste(valid_crs, collapse=", "))
}

list(pass = is_valid_crs, value = PROCESSING_CRS, message = message)
```

**Estimated Time:** 2-3 hours

---

### **FIX #10: Add Stratum File Validation** ⚠️ PENDING
**Issue:** Module 05 auto-generates filenames but doesn't validate existence
**Severity:** LOW
**Files Affected:** 05_raster_predictions_rf_bluecarbon.R (line 300+)

**Required Fix:**

Add after stratum file mapping (Module 05 line 300):

```r
# Validate stratum mask files exist
log_message("\nValidating GEE stratum mask files...")

gee_strata_dir <- "data_raw/gee_strata"
if (!dir.exists(gee_strata_dir)) {
  dir.create(gee_strata_dir, recursive = TRUE)
  log_message(sprintf("Created directory: %s", gee_strata_dir), "INFO")
}

validation_results <- data.frame(
  stratum = stratum_mapping$stratum_name,
  expected_file = stratum_mapping$gee_file,
  full_path = file.path(gee_strata_dir, stratum_mapping$gee_file),
  exists = file.exists(file.path(gee_strata_dir, stratum_mapping$gee_file))
)

# Log validation results
for (i in 1:nrow(validation_results)) {
  status <- if (validation_results$exists[i]) "✓ FOUND" else "✗ MISSING"
  log_message(sprintf("  %s: %s",
                      validation_results$expected_file[i],
                      status))

  if (!validation_results$exists[i]) {
    log_message(sprintf("    Expected at: %s",
                        validation_results$full_path[i]), "WARNING")
  }
}

# Fail early with helpful message
missing_count <- sum(!validation_results$exists)
if (missing_count > 0) {
  error_msg <- sprintf(
    "Missing %d stratum mask files. Please export from GEE using this naming convention:\n%s\n\nExpected location: %s/",
    missing_count,
    paste(sprintf("  '%s' → %s",
                  validation_results$stratum[!validation_results$exists],
                  validation_results$expected_file[!validation_results$exists]),
          collapse="\n"),
    gee_strata_dir
  )
  stop(error_msg)
}

log_message(sprintf("✓ All %d stratum mask files found", nrow(validation_results)))
```

**Estimated Time:** 1 hour

---

## 📋 IMPLEMENTATION CHECKLIST

### **Immediate (Already Done)** ✅
- [x] Fix #1: VM0033_DEPTH_INTERVALS alias
- [x] Fix #2: VM0033_MIN_CORES alias
- [x] Fix #4: VM0033_TARGET_PRECISION alias
- [x] Fix #5: VM0033_ASSUMED_CV alias

### **High Priority (Do Next)** ⚠️
- [ ] Fix #3: Auto-detect config files (2 hours)
  - Update 10 module files
  - Test with both configs
- [ ] Fix #6: Ecosystem-aware file naming (3 hours)
  - Update Module 03 (save)
  - Update Modules 04-07 (load)
  - Test file path resolution

### **Medium Priority** ⏳
- [ ] Fix #7: Root biomass calculation (4-6 hours)
  - Implement in Module 06
  - Add validation
  - Test with sample data
- [ ] Fix #8: Column validation (1 hour)
  - Add validation function
  - Test error handling
- [ ] Fix #9: Actionable ECCC/Provincial checks (2-3 hours)
  - Update check functions
  - Test with real data

### **Low Priority** 📝
- [ ] Fix #10: Stratum file validation (1 hour)
  - Add to Module 05
  - Test with missing files

---

## 🧪 COMPREHENSIVE TESTING SCRIPT

Create `test_grassland_workflow.R`:

```r
# ============================================================================
# GRASSLAND WORKFLOW COMPREHENSIVE TEST SUITE
# ============================================================================

test_all_fixes <- function() {

  cat("\n=== TESTING GRASSLAND WORKFLOW FIXES ===\n\n")

  # TEST 1: Config Loading
  cat("TEST 1: Configuration variable aliases...\n")
  source("grassland_carbon_config.R")

  stopifnot(exists("VM0033_DEPTH_INTERVALS"))
  stopifnot(exists("VM0033_DEPTH_MIDPOINTS"))
  stopifnot(exists("VM0033_MIN_CORES"))
  stopifnot(exists("VM0033_TARGET_PRECISION"))
  stopifnot(exists("VM0033_ASSUMED_CV"))

  stopifnot(nrow(VM0033_DEPTH_INTERVALS) == 4)
  stopifnot(length(VM0033_DEPTH_MIDPOINTS) == 4)
  stopifnot(VM0033_MIN_CORES == 5)  # max(5,5,5,3)

  cat("  ✓ All variable aliases present\n")
  cat("  ✓ Depth intervals: 4 layers\n")
  cat("  ✓ Min cores: 5 (strictest)\n\n")

  # TEST 2: Config Auto-Detection (after Fix #3)
  cat("TEST 2: Config file auto-detection...\n")
  # This test will work after Fix #3 is implemented
  cat("  ⚠ SKIPPED: Requires Fix #3 (update all modules)\n\n")

  # TEST 3: Variable Compatibility
  cat("TEST 3: Blue carbon module variable compatibility...\n")

  # Check that grassland config has all required variables
  required_vars <- c("VALID_STRATA", "BD_DEFAULTS", "INPUT_CRS",
                     "PROCESSING_CRS", "CONFIDENCE_LEVEL",
                     "STANDARD_DEPTHS", "MAX_CORE_DEPTH")

  missing <- required_vars[!sapply(required_vars, exists)]
  if (length(missing) > 0) {
    stop(sprintf("Missing required variables: %s", paste(missing, collapse=", ")))
  }

  cat("  ✓ All required variables present\n")
  cat(sprintf("  ✓ Strata defined: %d types\n", length(VALID_STRATA)))
  cat(sprintf("  ✓ CRS: EPSG:%d\n", PROCESSING_CRS))
  cat("\n")

  # TEST 4: Stratum Validation
  cat("TEST 4: Grassland stratum definitions...\n")

  expected_strata <- c("Native Prairie", "Improved Pasture",
                       "Degraded Grassland", "Restored Grassland",
                       "Riparian Grassland")

  stopifnot(all(VALID_STRATA %in% expected_strata))
  stopifnot(length(BD_DEFAULTS) == length(VALID_STRATA))

  cat("  ✓ Grassland strata configured correctly\n")
  cat(sprintf("  ✓ Bulk density defaults: %d strata\n", length(BD_DEFAULTS)))
  cat("\n")

  # TEST 5: Root Biomass Parameters (after Fix #7)
  cat("TEST 5: Root biomass calculation parameters...\n")

  stopifnot(exists("INCLUDE_ROOT_BIOMASS"))
  stopifnot(exists("ROOT_SHOOT_RATIOS"))
  stopifnot(exists("ROOT_CARBON_CONCENTRATION"))
  stopifnot(exists("ROOT_BIOMASS_METHOD"))

  stopifnot(length(ROOT_SHOOT_RATIOS) == length(VALID_STRATA))

  cat("  ✓ Root biomass parameters configured\n")
  cat(sprintf("  ✓ Root:shoot ratios: %d strata\n", length(ROOT_SHOOT_RATIOS)))
  cat(sprintf("  ✓ Method: %s\n", ROOT_BIOMASS_METHOD))
  cat("  ⚠ Implementation pending (Fix #7)\n\n")

  # TEST 6: Standards Coverage
  cat("TEST 6: Verification standards enabled...\n")

  standards <- c("VM0026", "VM0032", "VM0042", "ALBERTA_TIER",
                 "CANADA_IPCC_TIER3")
  enabled <- c(VM0026_ENABLED, VM0032_ENABLED, VM0042_ENABLED,
               ALBERTA_TIER_ENABLED, CANADA_IPCC_TIER3_ENABLED)

  cat(sprintf("  Standards enabled: %d of %d\n", sum(enabled), length(standards)))
  for (i in 1:length(standards)) {
    status <- if (enabled[i]) "✓" else "✗"
    cat(sprintf("    %s %s\n", status, standards[i]))
  }
  cat("\n")

  # SUMMARY
  cat("=== TEST SUMMARY ===\n")
  cat("✓ Phase 1 fixes verified (variable aliases)\n")
  cat("⚠ Phase 2 fixes pending (module updates)\n")
  cat("\nConfiguration is ready for grassland workflow!\n\n")

  invisible(TRUE)
}

# Run tests
test_all_fixes()
```

**Run Test:**
```r
source("test_grassland_workflow.R")
```

---

## 📊 FIX PRIORITY MATRIX

| Fix # | Issue | Severity | Time | Status | Priority |
|-------|-------|----------|------|--------|----------|
| #1-2 | Variable aliases (depth, min cores) | CRITICAL | 0.5h | ✅ DONE | 1 |
| #4-5 | Variable aliases (precision, CV) | CRITICAL | 0.5h | ✅ DONE | 1 |
| #3 | Config auto-detection | CRITICAL | 2h | ⚠️ PENDING | 2 |
| #6 | File naming | HIGH | 3h | ⚠️ PENDING | 3 |
| #7 | Root biomass | MEDIUM | 6h | ⚠️ PENDING | 4 |
| #8 | Column validation | MEDIUM | 1h | ⚠️ PENDING | 5 |
| #9 | Actionable checks | MEDIUM | 3h | ⚠️ PENDING | 6 |
| #10 | File validation | LOW | 1h | ⚠️ PENDING | 7 |

**Total Time Remaining:** 16 hours (~2 days)

---

## 🚀 RECOMMENDED IMPLEMENTATION SEQUENCE

### **Week 1: Core Functionality**
1. ✅ **DONE:** Variable aliases (#1, #2, #4, #5) - 1 hour
2. **Fix #3:** Config auto-detection - 2 hours
3. **Fix #6:** File naming - 3 hours
4. **Test:** Run Modules 01-03 end-to-end

### **Week 2: Feature Completion**
5. **Fix #7:** Root biomass calculation - 6 hours
6. **Fix #8:** Column validation - 1 hour
7. **Fix #9:** Enhanced standards checks - 3 hours
8. **Test:** Full workflow with sample data

### **Week 3: Polish & Deploy**
9. **Fix #10:** File validation - 1 hour
10. **Comprehensive testing** - 4 hours
11. **Documentation updates** - 2 hours
12. **Production deployment**

---

## 📝 NOTES FOR DEVELOPERS

### **Important Conventions:**
1. **Config Loading:** Always check for grassland config FIRST, then blue carbon
2. **File Naming:** Use `ecosystem_suffix` variable to determine naming
3. **Variable Aliases:** Keep both original and alias names for backwards compatibility
4. **Error Messages:** Provide actionable guidance (expected file paths, etc.)
5. **Logging:** Always log which config/files are loaded

### **Testing Best Practices:**
1. Test with BOTH grassland and blue carbon configs
2. Test with missing files (should fail gracefully)
3. Test with minimal data (edge cases)
4. Validate all output files are created
5. Check standards report generates correctly

### **Common Pitfalls:**
- Don't assume files exist - always check
- Don't hardcode ecosystem names - use config variables
- Don't skip logging - it helps debugging
- Don't break backwards compatibility - add, don't replace

---

**Document Status:** Implementation Guide
**Next Update:** After Phase 2 fixes completed
**Maintained By:** Workflow Development Team
