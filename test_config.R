#!/usr/bin/env Rscript
# ============================================================================
# TEST SCRIPT: blue_carbon_config.R
# ============================================================================

cat("=== TESTING CONFIG CHANGES ===\n\n")

# Load configuration
source("blue_carbon_config.R")

# ============================================================================
# TEST 1: CRS Configuration
# ============================================================================
cat("Test 1: CRS Configuration\n")

test_1_pass <- TRUE
if (INPUT_CRS != 4326) {
  cat("  ✗ FAILED: INPUT_CRS should be 4326 (WGS84), got", INPUT_CRS, "\n")
  test_1_pass <- FALSE
} else {
  cat("  ✓ INPUT_CRS = 4326 (WGS84) - CORRECT\n")
}

if (PROCESSING_CRS != 3347) {
  cat("  ⚠ WARNING: PROCESSING_CRS is", PROCESSING_CRS, "(expected 3347 for Canada Albers)\n")
} else {
  cat("  ✓ PROCESSING_CRS = 3347 (Canada Albers) - CORRECT\n")
}

if (!test_1_pass) {
  stop("Test 1 FAILED")
}

# ============================================================================
# TEST 2: Unit Conversion Function
# ============================================================================
cat("\nTest 2: Unit Conversion Function\n")

test_2_pass <- TRUE

# Test kg/m² to Mg/ha
result <- convert_units(1, "kg_m2", "Mg_ha")
if (result != 10) {
  cat("  ✗ FAILED: 1 kg/m² should be 10 Mg/ha, got", result, "\n")
  test_2_pass <- FALSE
} else {
  cat("  ✓ 1 kg/m² = 10 Mg/ha\n")
}

# Test Mg/ha to kg/m²
result <- convert_units(10, "Mg_ha", "kg_m2")
if (result != 1) {
  cat("  ✗ FAILED: 10 Mg/ha should be 1 kg/m², got", result, "\n")
  test_2_pass <- FALSE
} else {
  cat("  ✓ 10 Mg/ha = 1 kg/m²\n")
}

# Test g/kg to %
result <- convert_units(100, "g_kg", "pct")
if (result != 10) {
  cat("  ✗ FAILED: 100 g/kg should be 10%, got", result, "\n")
  test_2_pass <- FALSE
} else {
  cat("  ✓ 100 g/kg = 10%\n")
}

# Test % to g/kg
result <- convert_units(10, "pct", "g_kg")
if (result != 100) {
  cat("  ✗ FAILED: 10% should be 100 g/kg, got", result, "\n")
  test_2_pass <- FALSE
} else {
  cat("  ✓ 10% = 100 g/kg\n")
}

# Test invalid conversion (should error)
error_caught <- FALSE
tryCatch({
  convert_units(1, "invalid", "units")
}, error = function(e) {
  error_caught <<- TRUE
  cat("  ✓ Invalid conversion properly raises error\n")
})

if (!error_caught) {
  cat("  ✗ FAILED: Invalid conversion should raise error\n")
  test_2_pass <- FALSE
}

if (!test_2_pass) {
  stop("Test 2 FAILED")
}

# ============================================================================
# TEST 3: Session Tracking
# ============================================================================
cat("\nTest 3: Session Tracking\n")

test_3_pass <- TRUE

# Check SESSION_START exists and is POSIXct
if (!exists("SESSION_START")) {
  cat("  ✗ FAILED: SESSION_START not defined\n")
  test_3_pass <- FALSE
} else if (!inherits(SESSION_START, "POSIXct")) {
  cat("  ✗ FAILED: SESSION_START is not POSIXct, got", class(SESSION_START), "\n")
  test_3_pass <- FALSE
} else {
  cat("  ✓ SESSION_START defined:", format(SESSION_START), "\n")
}

# Check SESSION_ID exists and has correct format
if (!exists("SESSION_ID")) {
  cat("  ✗ FAILED: SESSION_ID not defined\n")
  test_3_pass <- FALSE
} else if (!grepl("^\\d{8}_\\d{6}$", SESSION_ID)) {
  cat("  ✗ FAILED: SESSION_ID has wrong format, got", SESSION_ID, "\n")
  test_3_pass <- FALSE
} else {
  cat("  ✓ SESSION_ID defined:", SESSION_ID, "\n")
}

# Check TABLE_DIGITS exists
if (!exists("TABLE_DIGITS")) {
  cat("  ✗ FAILED: TABLE_DIGITS not defined\n")
  test_3_pass <- FALSE
} else if (TABLE_DIGITS != 2) {
  cat("  ⚠ WARNING: TABLE_DIGITS is", TABLE_DIGITS, "(expected 2)\n")
} else {
  cat("  ✓ TABLE_DIGITS = 2\n")
}

if (!test_3_pass) {
  stop("Test 3 FAILED")
}

# ============================================================================
# SUMMARY
# ============================================================================
cat("\n=== ALL CONFIG TESTS PASSED ✓ ===\n")
cat("\nSummary:\n")
cat("  ✓ CRS configuration correct (INPUT=4326, PROCESSING=3347)\n")
cat("  ✓ Unit conversion function working (4 conversions tested)\n")
cat("  ✓ Session tracking enabled (SESSION_ID, SESSION_START, TABLE_DIGITS)\n")
cat("\nConfig changes successfully implemented!\n")
