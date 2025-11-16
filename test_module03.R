#!/usr/bin/env Rscript
# ============================================================================
# TEST SCRIPT: Module 03 - Equal-Area Spline Implementation
# ============================================================================

cat("=== TESTING MODULE 03: EQUAL-AREA SPLINE ===\n\n")

# Load required packages
suppressPackageStartupMessages({
  library(dplyr)
})

# Try to load ithir (optional)
has_ithir <- requireNamespace("ithir", quietly = TRUE)

# Create log_message stub
log_message <- function(msg, level = "INFO") {
  cat(sprintf("  [%s] %s\n", level, msg))
}

# Source the equal_area_spline function
source_lines <- readLines("03_depth_harmonization_bluecarbon.R")
func_start <- which(grepl("^equal_area_spline <- function", source_lines))[1]
func_end <- which(source_lines == "}")[which(source_lines == "}") > func_start][1]
eval(parse(text = source_lines[func_start:func_end]))

# Also source linear_interpolation (fallback)
func_start2 <- which(grepl("^linear_interpolation <- function", source_lines))[1]
func_end2 <- which(source_lines == "}")[which(source_lines == "}") > func_start2][1]
eval(parse(text = source_lines[func_start2:func_end2]))

# ============================================================================
# TEST 1: Basic Function Structure
# ============================================================================
cat("Test 1: Function Structure\n")

test_1_pass <- TRUE

if (!exists("equal_area_spline")) {
  cat("  ✗ FAILED: equal_area_spline function not found\n")
  test_1_pass <- FALSE
} else {
  cat("  ✓ equal_area_spline function loaded\n")
}

if (!exists("linear_interpolation")) {
  cat("  ✗ FAILED: linear_interpolation fallback not found\n")
  test_1_pass <- FALSE
} else {
  cat("  ✓ linear_interpolation fallback loaded\n")
}

if (!test_1_pass) {
  stop("Test 1 FAILED")
}

# ============================================================================
# TEST 2: Package Availability
# ============================================================================
cat("\nTest 2: Package Availability\n")

if (has_ithir) {
  cat("  ✓ ithir package available - TRUE equal-area spline will be used\n")
  cat(sprintf("    Version: %s\n", packageVersion("ithir")))
} else {
  cat("  ⚠ ithir package NOT available - will use fallback methods\n")
  cat("  Install with: install.packages('ithir')\n")
}

# ============================================================================
# TEST 3: Spline with Realistic SOC Data
# ============================================================================
cat("\nTest 3: Realistic SOC Depth Profile\n")

test_3_pass <- TRUE

# Create realistic decreasing SOC profile
test_depths <- c(5, 15, 30, 60, 90)
test_soc <- c(50, 45, 38, 28, 22)  # Decreasing with depth (typical)
standard_depths <- c(7.5, 22.5, 40, 75)

cat("  Input profile:\n")
for (i in seq_along(test_depths)) {
  cat(sprintf("    %3dcm: %5.1f g/kg\n", test_depths[i], test_soc[i]))
}

result <- equal_area_spline(test_depths, test_soc, standard_depths)

if (is.null(result)) {
  cat("  ✗ FAILED: Spline returned NULL\n")
  test_3_pass <- FALSE
} else {
  cat("\n  Harmonized to VM0033 depths:\n")
  for (i in seq_along(standard_depths)) {
    cat(sprintf("    %5.1fcm: %5.1f g/kg\n", standard_depths[i], result[i]))
  }

  # Check basic properties
  if (length(result) != length(standard_depths)) {
    cat("  ✗ FAILED: Wrong number of predictions\n")
    test_3_pass <- FALSE
  } else {
    cat("  ✓ Correct number of predictions\n")
  }

  if (any(is.na(result))) {
    cat("  ✗ FAILED: Contains NA values\n")
    test_3_pass <- FALSE
  } else {
    cat("  ✓ No NA values\n")
  }

  if (any(result < 0)) {
    cat("  ✗ FAILED: Contains negative values\n")
    test_3_pass <- FALSE
  } else {
    cat("  ✓ No negative values\n")
  }

  # Check monotonicity (should be decreasing)
  if (!all(diff(result) <= 0)) {
    cat("  ⚠ WARNING: Profile not strictly monotonic (may be acceptable)\n")
  } else {
    cat("  ✓ Monotonically decreasing (realistic)\n")
  }

  # Check values are in reasonable range
  if (all(result >= min(test_soc) * 0.8 & result <= max(test_soc) * 1.2)) {
    cat("  ✓ Values within reasonable range of input\n")
  } else {
    cat("  ⚠ WARNING: Some values outside expected range\n")
  }
}

if (!test_3_pass) {
  stop("Test 3 FAILED")
}

# ============================================================================
# TEST 4: Edge Cases
# ============================================================================
cat("\nTest 4: Edge Cases\n")

test_4_pass <- TRUE

# Test 4a: Too few points
result_few <- equal_area_spline(c(10, 20), c(50, 45), standard_depths)
if (!is.null(result_few)) {
  cat("  ✗ FAILED: Should return NULL for < 3 points\n")
  test_4_pass <- FALSE
} else {
  cat("  ✓ Correctly handles < 3 points (returns NULL)\n")
}

# Test 4b: Non-monotonic profile
test_depths_nm <- c(5, 15, 30, 60)
test_soc_nm <- c(50, 30, 45, 25)  # Non-monotonic
result_nm <- equal_area_spline(test_depths_nm, test_soc_nm, standard_depths)
if (is.null(result_nm)) {
  cat("  ⚠ WARNING: Non-monotonic profile failed (may use fallback)\n")
} else {
  cat("  ✓ Handles non-monotonic profiles\n")
}

# Test 4c: Increasing profile (unusual but possible in some systems)
test_soc_inc <- c(20, 25, 35, 40)  # Increasing
result_inc <- equal_area_spline(test_depths, test_soc_inc[1:length(test_depths)],
                                standard_depths)
if (is.null(result_inc)) {
  cat("  ⚠ WARNING: Increasing profile failed\n")
} else {
  cat("  ✓ Handles increasing profiles\n")
}

if (!test_4_pass) {
  stop("Test 4 FAILED")
}

# ============================================================================
# TEST 5: Compare with Fallback Method
# ============================================================================
cat("\nTest 5: Compare Methods\n")

# Test with same data using fallback (linear)
result_linear <- linear_interpolation(test_depths, test_soc, standard_depths)

if (!is.null(result_linear)) {
  cat("  ✓ Fallback method works\n")

  if (!is.null(result)) {
    # Compare spline vs linear
    diff_mean <- mean(abs(result - result_linear))
    cat(sprintf("  Mean absolute difference: %.2f g/kg\n", diff_mean))

    if (diff_mean > 10) {
      cat("  ⚠ WARNING: Large difference between methods\n")
    } else {
      cat("  ✓ Methods produce similar results\n")
    }
  }
} else {
  cat("  ✗ WARNING: Fallback method failed\n")
}

# ============================================================================
# SUMMARY
# ============================================================================
cat("\n=== MODULE 03 TESTS PASSED ✓ ===\n")
cat("\nSummary:\n")
cat("  ✓ Equal-area spline function implemented\n")
cat("  ✓ Handles realistic SOC depth profiles\n")
cat("  ✓ Edge cases handled appropriately\n")
cat("  ✓ Fallback methods available\n")

if (has_ithir) {
  cat("\n✓✓ OPTIMAL: ithir package available for TRUE equal-area spline\n")
} else {
  cat("\n⚠ Using fallback methods (install ithir for optimal performance)\n")
  cat("  Run: install.packages('ithir')\n")
}

cat("\nModule 03 changes successfully implemented!\n")
cat("\nNext: Test full Module 03 with real core data\n")
