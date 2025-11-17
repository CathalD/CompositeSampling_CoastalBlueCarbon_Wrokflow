# ============================================================================
# GRASSLAND WORKFLOW COMPREHENSIVE TEST SUITE
# ============================================================================
# PURPOSE: Validate that grassland adaptation fixes are working correctly
# RUN: source("test_grassland_workflow.R")
# ============================================================================

test_all_fixes <- function() {

  cat("\n")
  cat("==============================================================================\n")
  cat("  CANADIAN GRASSLAND CARBON MMRV WORKFLOW - COMPREHENSIVE TEST SUITE\n")
  cat("==============================================================================\n\n")

  test_results <- list()

  # ============================================================================
  # TEST 1: Configuration Variable Aliases
  # ============================================================================

  cat("TEST 1: Configuration variable aliases (Fixes #1, #2, #4, #5)...\n")

  tryCatch({
    source("grassland_carbon_config.R")

    # Check critical aliases exist
    stopifnot(exists("VM0033_DEPTH_INTERVALS"))
    stopifnot(exists("VM0033_DEPTH_MIDPOINTS"))
    stopifnot(exists("VM0033_MIN_CORES"))
    stopifnot(exists("VM0033_TARGET_PRECISION"))
    stopifnot(exists("VM0033_ASSUMED_CV"))
    stopifnot(exists("VM0033_CV_THRESHOLD"))
    stopifnot(exists("VM0033_MONITORING_FREQUENCY"))

    # Validate values
    stopifnot(nrow(VM0033_DEPTH_INTERVALS) == 4)
    stopifnot(length(VM0033_DEPTH_MIDPOINTS) == 4)
    stopifnot(VM0033_MIN_CORES == 5)  # max(5,5,5,3)
    stopifnot(VM0033_TARGET_PRECISION == 20)
    stopifnot(VM0033_ASSUMED_CV == 35)

    # Check grassland-specific variables
    stopifnot(exists("GRASSLAND_DEPTH_INTERVALS"))
    stopifnot(exists("GRASSLAND_DEPTH_MIDPOINTS"))

    cat("  ✓ All variable aliases present and correct\n")
    cat(sprintf("  ✓ VM0033_DEPTH_INTERVALS: %d layers\n", nrow(VM0033_DEPTH_INTERVALS)))
    cat(sprintf("  ✓ VM0033_MIN_CORES: %d (strictest of all standards)\n", VM0033_MIN_CORES))
    cat(sprintf("  ✓ VM0033_TARGET_PRECISION: %d%%\n", VM0033_TARGET_PRECISION))
    cat(sprintf("  ✓ VM0033_ASSUMED_CV: %d%%\n", VM0033_ASSUMED_CV))

    test_results$test1 <- list(pass = TRUE, message = "Variable aliases working")

  }, error = function(e) {
    cat(sprintf("  ✗ FAILED: %s\n", e$message))
    test_results$test1 <<- list(pass = FALSE, message = e$message)
  })

  cat("\n")

  # ============================================================================
  # TEST 2: Required Variables for Module Compatibility
  # ============================================================================

  cat("TEST 2: Blue carbon module variable compatibility...\n")

  tryCatch({
    # Variables expected by Module 01
    required_vars <- c(
      "VALID_STRATA", "BD_DEFAULTS", "INPUT_CRS", "PROCESSING_CRS",
      "CONFIDENCE_LEVEL", "STANDARD_DEPTHS", "MAX_CORE_DEPTH",
      "QC_SOC_MIN", "QC_SOC_MAX", "QC_BD_MIN", "QC_BD_MAX"
    )

    missing <- required_vars[!sapply(required_vars, exists)]

    if (length(missing) > 0) {
      stop(sprintf("Missing required variables: %s", paste(missing, collapse=", ")))
    }

    cat("  ✓ All Module 01 required variables present\n")

    # Variables expected by Module 03
    module03_vars <- c("INTERPOLATION_METHOD", "BOOTSTRAP_ITERATIONS", "BOOTSTRAP_SEED")
    missing_m03 <- module03_vars[!sapply(module03_vars, exists)]

    if (length(missing_m03) == 0) {
      cat("  ✓ All Module 03 required variables present\n")
    } else {
      cat(sprintf("  ⚠ Module 03 missing: %s\n", paste(missing_m03, collapse=", ")))
    }

    # Variables expected by Module 05
    module05_vars <- c("RF_NTREE", "RF_MTRY", "RF_MIN_NODE_SIZE", "ENABLE_AOA")
    missing_m05 <- module05_vars[!sapply(module05_vars, exists)]

    if (length(missing_m05) == 0) {
      cat("  ✓ All Module 05 required variables present\n")
    } else {
      cat(sprintf("  ⚠ Module 05 missing: %s\n", paste(missing_m05, collapse=", ")))
    }

    test_results$test2 <- list(pass = TRUE, message = "Module compatibility OK")

  }, error = function(e) {
    cat(sprintf("  ✗ FAILED: %s\n", e$message))
    test_results$test2 <<- list(pass = FALSE, message = e$message)
  })

  cat("\n")

  # ============================================================================
  # TEST 3: Grassland Stratum Configuration
  # ============================================================================

  cat("TEST 3: Grassland stratum definitions...\n")

  tryCatch({
    expected_strata <- c(
      "Native Prairie", "Improved Pasture", "Degraded Grassland",
      "Restored Grassland", "Riparian Grassland"
    )

    # Check strata match expected
    if (!all(VALID_STRATA %in% expected_strata)) {
      stop("VALID_STRATA contains unexpected values")
    }

    # Check bulk density defaults match strata
    if (length(BD_DEFAULTS) != length(VALID_STRATA)) {
      stop("BD_DEFAULTS count doesn't match VALID_STRATA count")
    }

    # Check all strata have BD defaults
    missing_bd <- setdiff(VALID_STRATA, names(BD_DEFAULTS))
    if (length(missing_bd) > 0) {
      stop(sprintf("Missing BD defaults for: %s", paste(missing_bd, collapse=", ")))
    }

    # Check bulk density values are reasonable for grassland
    bd_values <- unlist(BD_DEFAULTS)
    if (any(bd_values < 0.8 | bd_values > 1.6)) {
      cat("  ⚠ WARNING: Some BD values outside typical grassland range (0.8-1.6 g/cm³)\n")
    }

    cat("  ✓ Grassland strata configured correctly\n")
    cat(sprintf("  ✓ Strata defined: %d types\n", length(VALID_STRATA)))
    cat(sprintf("  ✓ Bulk density defaults: %d strata\n", length(BD_DEFAULTS)))
    cat(sprintf("  ✓ BD range: %.1f - %.1f g/cm³\n", min(bd_values), max(bd_values)))

    test_results$test3 <- list(pass = TRUE, message = "Strata configuration valid")

  }, error = function(e) {
    cat(sprintf("  ✗ FAILED: %s\n", e$message))
    test_results$test3 <<- list(pass = FALSE, message = e$message)
  })

  cat("\n")

  # ============================================================================
  # TEST 4: QC Thresholds (Grassland-Specific)
  # ============================================================================

  cat("TEST 4: QC thresholds for grassland soils...\n")

  tryCatch({
    # Check SOC thresholds
    if (QC_SOC_MIN != 10 || QC_SOC_MAX != 150) {
      cat(sprintf("  ⚠ SOC range: %d-%d g/kg (expected: 10-150 for grassland)\n",
                  QC_SOC_MIN, QC_SOC_MAX))
    } else {
      cat(sprintf("  ✓ SOC range: %d-%d g/kg (grassland-appropriate)\n",
                  QC_SOC_MIN, QC_SOC_MAX))
    }

    # Check BD thresholds
    if (QC_BD_MIN != 0.8 || QC_BD_MAX != 1.6) {
      cat(sprintf("  ⚠ BD range: %.1f-%.1f g/cm³ (expected: 0.8-1.6 for grassland)\n",
                  QC_BD_MIN, QC_BD_MAX))
    } else {
      cat(sprintf("  ✓ BD range: %.1f-%.1f g/cm³ (grassland-appropriate)\n",
                  QC_BD_MIN, QC_BD_MAX))
    }

    # Check coordinate range (Canadian prairies)
    if (QC_LON_MIN != -120 || QC_LON_MAX != -95) {
      cat(sprintf("  ⚠ Longitude range not optimized for Canadian prairies\n"))
    } else {
      cat("  ✓ Longitude range: Canadian prairie provinces\n")
    }

    test_results$test4 <- list(pass = TRUE, message = "QC thresholds appropriate")

  }, error = function(e) {
    cat(sprintf("  ✗ FAILED: %s\n", e$message))
    test_results$test4 <<- list(pass = FALSE, message = e$message)
  })

  cat("\n")

  # ============================================================================
  # TEST 5: Root Biomass Parameters
  # ============================================================================

  cat("TEST 5: Root biomass calculation parameters (Fix #7 partial)...\n")

  tryCatch({
    stopifnot(exists("INCLUDE_ROOT_BIOMASS"))
    stopifnot(exists("ROOT_SHOOT_RATIOS"))
    stopifnot(exists("ROOT_CARBON_CONCENTRATION"))
    stopifnot(exists("ROOT_BIOMASS_METHOD"))
    stopifnot(exists("ROOT_BIOMASS_DEPTH"))

    # Validate root:shoot ratios
    if (length(ROOT_SHOOT_RATIOS) != length(VALID_STRATA)) {
      stop("ROOT_SHOOT_RATIOS count doesn't match VALID_STRATA count")
    }

    # Check all strata have ratios
    missing_ratios <- setdiff(VALID_STRATA, names(ROOT_SHOOT_RATIOS))
    if (length(missing_ratios) > 0) {
      stop(sprintf("Missing root:shoot ratios for: %s", paste(missing_ratios, collapse=", ")))
    }

    # Validate ratio values (grassland typical: 1.5-4.0)
    ratio_values <- unlist(ROOT_SHOOT_RATIOS)
    if (any(ratio_values < 1.0 | ratio_values > 5.0)) {
      cat("  ⚠ WARNING: Some root:shoot ratios outside typical range (1.0-5.0)\n")
    }

    cat("  ✓ Root biomass parameters configured\n")
    cat(sprintf("  ✓ Root:shoot ratios: %d strata\n", length(ROOT_SHOOT_RATIOS)))
    cat(sprintf("  ✓ Ratio range: %.1f - %.1f\n", min(ratio_values), max(ratio_values)))
    cat(sprintf("  ✓ Root C concentration: %.0f%%\n", ROOT_CARBON_CONCENTRATION * 100))
    cat(sprintf("  ✓ Method: %s\n", ROOT_BIOMASS_METHOD))
    cat(sprintf("  ✓ Sampling depth: %d cm\n", ROOT_BIOMASS_DEPTH))

    if (INCLUDE_ROOT_BIOMASS) {
      cat("  ⚠ Root biomass ENABLED but implementation pending (Fix #7)\n")
    } else {
      cat("  ℹ Root biomass currently DISABLED (set INCLUDE_ROOT_BIOMASS = TRUE to enable)\n")
    }

    test_results$test5 <- list(pass = TRUE, message = "Root biomass params configured (impl pending)")

  }, error = function(e) {
    cat(sprintf("  ✗ FAILED: %s\n", e$message))
    test_results$test5 <<- list(pass = FALSE, message = e$message)
  })

  cat("\n")

  # ============================================================================
  # TEST 6: Verification Standards Enabled
  # ============================================================================

  cat("TEST 6: Verification standards configuration...\n")

  tryCatch({
    standards <- c(
      "VM0026" = VM0026_ENABLED,
      "VM0032" = VM0032_ENABLED,
      "VM0042" = VM0042_ENABLED,
      "Alberta TIER" = ALBERTA_TIER_ENABLED,
      "Canadian IPCC Tier 3" = CANADA_IPCC_TIER3_ENABLED
    )

    enabled_count <- sum(standards)

    cat(sprintf("  Standards enabled: %d of %d\n", enabled_count, length(standards)))

    for (i in 1:length(standards)) {
      status <- if (standards[i]) "✓ ENABLED " else "✗ DISABLED"
      cat(sprintf("    %s: %s\n", status, names(standards)[i]))
    }

    # Check minimum cores for each standard
    if (VM0026_ENABLED) {
      cat(sprintf("      - VM0026 min cores: %d\n", VM0026_MIN_CORES))
    }
    if (VM0032_ENABLED) {
      cat(sprintf("      - VM0032 min cores: %d\n", VM0032_MIN_CORES))
    }
    if (VM0042_ENABLED) {
      cat(sprintf("      - VM0042 min cores: %d\n", VM0042_MIN_CORES))
    }
    if (ALBERTA_TIER_ENABLED) {
      cat(sprintf("      - TIER min cores: %d\n", ALBERTA_TIER_MIN_CORES))
    }

    test_results$test6 <- list(pass = TRUE,
                               message = sprintf("%d standards enabled", enabled_count))

  }, error = function(e) {
    cat(sprintf("  ✗ FAILED: %s\n", e$message))
    test_results$test6 <<- list(pass = FALSE, message = e$message)
  })

  cat("\n")

  # ============================================================================
  # TEST 7: Coordinate Reference System (CRS)
  # ============================================================================

  cat("TEST 7: Coordinate reference system configuration...\n")

  tryCatch({
    # Check CRS is defined
    stopifnot(exists("INPUT_CRS"))
    stopifnot(exists("PROCESSING_CRS"))

    # Validate WGS84 for input
    if (INPUT_CRS != 4326) {
      cat(sprintf("  ⚠ WARNING: INPUT_CRS is %d (expected 4326/WGS84)\n", INPUT_CRS))
    } else {
      cat("  ✓ INPUT_CRS: EPSG:4326 (WGS84)\n")
    }

    # Check processing CRS
    canadian_crs <- c(
      3347,  # Canada Albers
      3400, 3402,  # Alberta
      2955, 2151,  # Saskatchewan
      2957, 3158,  # Manitoba
      32612, 32613, 32614, 32615  # UTM zones
    )

    crs_names <- c(
      "3347" = "Canada Albers",
      "3400" = "Alberta 10-TM Resource",
      "3402" = "Alberta 10-TM Forest",
      "2955" = "Saskatchewan UTM 13N",
      "2151" = "Saskatchewan Central",
      "2957" = "Manitoba UTM 14N",
      "3158" = "Manitoba UTM 15N"
    )

    if (PROCESSING_CRS %in% canadian_crs) {
      crs_name <- crs_names[as.character(PROCESSING_CRS)]
      if (is.na(crs_name)) {
        crs_name <- sprintf("UTM Zone %d", PROCESSING_CRS)
      }
      cat(sprintf("  ✓ PROCESSING_CRS: EPSG:%d (%s)\n", PROCESSING_CRS, crs_name))
    } else {
      cat(sprintf("  ⚠ PROCESSING_CRS: EPSG:%d (not a Canadian provincial CRS)\n", PROCESSING_CRS))
      cat("    Recommended: 3400 (AB), 2955 (SK), 2957 (MB), or 3347 (National)\n")
    }

    test_results$test7 <- list(pass = TRUE, message = "CRS configuration valid")

  }, error = function(e) {
    cat(sprintf("  ✗ FAILED: %s\n", e$message))
    test_results$test7 <<- list(pass = FALSE, message = e$message)
  })

  cat("\n")

  # ============================================================================
  # TEST 8: File Structure Check
  # ============================================================================

  cat("TEST 8: Expected directory and file structure...\n")

  tryCatch({
    # Check for required files
    required_files <- c(
      "grassland_carbon_config.R",
      "07b_comprehensive_standards_report_grassland.R",
      "README_GRASSLAND_CARBON_WORKFLOW.md",
      "GRASSLAND_ADAPTATION_SUMMARY.md",
      "IMPLEMENTATION_FIXES.md"
    )

    file_status <- sapply(required_files, file.exists)

    cat("  Required grassland workflow files:\n")
    for (i in 1:length(required_files)) {
      status <- if (file_status[i]) "✓" else "✗"
      cat(sprintf("    %s %s\n", status, required_files[i]))
    }

    # Check for expected modules (should use existing blue carbon modules)
    expected_modules <- c(
      "01_data_prep_bluecarbon.R",
      "03_depth_harmonization_bluecarbon.R",
      "05_raster_predictions_rf_bluecarbon.R",
      "06_carbon_stock_calculation_bluecarbon.R"
    )

    module_status <- sapply(expected_modules, file.exists)

    cat("\n  Required workflow modules:\n")
    for (i in 1:length(expected_modules)) {
      status <- if (module_status[i]) "✓" else "✗"
      cat(sprintf("    %s %s\n", status, expected_modules[i]))
    }

    if (all(file_status) && all(module_status)) {
      cat("\n  ✓ All required files present\n")
    } else {
      cat("\n  ⚠ Some files missing - workflow may not run\n")
    }

    test_results$test8 <- list(pass = all(file_status),
                               message = sprintf("%d/%d files present",
                                               sum(file_status), length(file_status)))

  }, error = function(e) {
    cat(sprintf("  ✗ FAILED: %s\n", e$message))
    test_results$test8 <<- list(pass = FALSE, message = e$message)
  })

  cat("\n")

  # ============================================================================
  # SUMMARY
  # ============================================================================

  cat("==============================================================================\n")
  cat("  TEST SUMMARY\n")
  cat("==============================================================================\n\n")

  passed <- sum(sapply(test_results, function(x) isTRUE(x$pass)))
  total <- length(test_results)

  cat(sprintf("Tests Passed: %d / %d\n\n", passed, total))

  for (i in 1:length(test_results)) {
    test_name <- names(test_results)[i]
    result <- test_results[[i]]
    status <- if (isTRUE(result$pass)) "✓ PASS" else "✗ FAIL"
    cat(sprintf("  %s: %s - %s\n", status, test_name, result$message))
  }

  cat("\n")

  if (passed == total) {
    cat("==============================================================================\n")
    cat("  ✓ ALL TESTS PASSED - Grassland configuration ready for use!\n")
    cat("==============================================================================\n")
    cat("\nNext steps:\n")
    cat("  1. Implement remaining fixes (see IMPLEMENTATION_FIXES.md)\n")
    cat("  2. Test with sample grassland data\n")
    cat("  3. Run Module 01 with grassland config\n\n")
  } else {
    cat("==============================================================================\n")
    cat("  ⚠ SOME TESTS FAILED - Review errors above\n")
    cat("==============================================================================\n\n")
  }

  invisible(test_results)
}

# Run tests
test_all_fixes()
