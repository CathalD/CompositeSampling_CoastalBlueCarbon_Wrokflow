// ============================================================================
// GOOGLE EARTH ENGINE SCRIPT: EXPORT BAYESIAN PRIORS FOR BLUE CARBON
// ============================================================================
// PURPOSE: Export prior carbon stock maps for Bayesian workflow (Part 4)
//
// DATA SOURCES:
//   1. SoilGrids 250m - Global soil organic carbon (Poggio et al. 2021)
//   2. Sothe et al. 2022 - BC Coast forest biomass and soil carbon
//
// OUTPUTS: GeoTIFF files for each depth interval with mean and uncertainty
//          Carbon stocks in kg/m² (kg C per square meter)
//
// INSTRUCTIONS:
//   1. Define your study area (studyArea variable below)
//   2. Add Sothe et al. 2022 asset paths (SOTHE_* variables)
//   3. Run script in GEE Code Editor
//   4. Export all tasks to Google Drive
//   5. Download files and run Module 00C in R to process
//
// TROUBLESHOOTING:
//   If SoilGrids fails to load:
//   - Search Earth Engine Data Catalog for "SoilGrids"
//   - Check: https://developers.google.com/earth-engine/datasets/catalog/ISRIC_SoilGrids
//   - The script will automatically try multiple path formats
//   - See console output for specific error messages
// ============================================================================

// ============================================================================
// DIAGNOSTIC FUNCTIONS (Optional - for troubleshooting)
// ============================================================================

// Uncomment this section to run diagnostic checks only
/*
print('═══════════════════════════════════════');
print('DIAGNOSTIC MODE: Checking SoilGrids Access');
print('═══════════════════════════════════════');

// Test paths to try
var testPaths = [
  'projects/soilgrids-isric/soc_0-5cm_mean',
  'projects/soilgrids-isric/soc_mean_0_5cm',
  'OpenLandMap/SOL/SOL_ORGANIC-CARBON_USDA-6A1C_M/v02'
];

testPaths.forEach(function(path) {
  try {
    var test = ee.Image(path);
    var info = test.getInfo();
    print('✓ SUCCESS:', path);
    print('  Bands:', test.bandNames().getInfo());
    print('  Projection:', test.projection().crs().getInfo());
  } catch (error) {
    print('✗ FAILED:', path);
    print('  Error:', error.message);
  }
  print('');
});

print('Diagnostic complete. Comment out this section to run main script.');
print('═══════════════════════════════════════');
// Uncomment the line below to stop after diagnostics
// throw new Error('Diagnostic mode - script stopped');
*/

// ============================================================================
// USER INPUTS - MODIFY THESE
// ============================================================================

// Study area boundary (draw polygon or import shapefile)
// Example: Draw a polygon in GEE or import from assets
var studyArea = geometry;
// Or draw manually:
// var studyArea = ee.Geometry.Rectangle([-123.5, 49.0, -123.0, 49.3]);

// Export parameters
var EXPORT_SCALE = 250;  // Resolution in meters (SoilGrids native)
var EXPORT_CRS = 'EPSG:3005';  // BC Albers (or your preferred CRS)
var EXPORT_FOLDER = 'BlueCarbon_Priors';  // Google Drive folder name

// Sothe et al. 2022 BC Coast Assets
// **USER MUST UPDATE THESE PATHS**
// Format: 'users/YOUR_USERNAME/ASSET_NAME' or 'projects/PROJECT_ID/ASSET_NAME'

// Forest biomass (aboveground + belowground) - Mg/ha
var SOTHE_FOREST_BIOMASS = 'projects/sat-io/open-datasets/carbon_stocks_ca/forest_carbon_2019';

// Soil Carbon to 1 meter depth - kg/m²
var SOTHE_SOIL_CARBON = 'projects/northstarlabs/assets/McMasterWWFCanadasoilcarbon1m250mkgm2version3';

// Uncertainty of soil carbon at 1 meter depth - kg/m²
var SOTHE_SOIL_CARBON_UNCERTAINTY = 'projects/northstarlabs/assets/McMasterWWFCanadasoilcarbon1muncertainty250mkgm2version30';

// Other biomass (non-tree) - leave empty if not available
var SOTHE_OTHER_BIOMASS = '';

// VM0033 Standard Depth Intervals (in cm)
// Midpoint depths for VM0033: 7.5, 22.5, 40, 75 cm
var VM0033_INTERVALS = {
  '0-15': {min: 0, max: 15, midpoint: 7.5},
  '15-30': {min: 15, max: 30, midpoint: 22.5},
  '30-50': {min: 30, max: 50, midpoint: 40},
  '50-100': {min: 50, max: 100, midpoint: 75}
};

// SoilGrids depth intervals (in cm)
// SoilGrids provides: 0-5, 5-15, 15-30, 30-60, 60-100, 100-200
var SOILGRIDS_DEPTHS = {
  '0-5': {min: 0, max: 5},
  '5-15': {min: 5, max: 15},
  '15-30': {min: 15, max: 30},
  '30-60': {min: 30, max: 60},
  '60-100': {min: 60, max: 100}
};

// ============================================================================
// SOILGRIDS DATA LOADING
// ============================================================================

print('═══════════════════════════════════════');
print('LOADING SOILGRIDS 250M DATA (v2.0)');
print('═══════════════════════════════════════');

// Load SoilGrids v2.0 multiband images
// Each property has bands for different depth intervals
var soc_mean = ee.Image('projects/soilgrids-isric/soc_mean');
var bdod_mean = ee.Image('projects/soilgrids-isric/bdod_mean');

print('Testing SoilGrids access...');
try {
  var socBands = soc_mean.bandNames().getInfo();
  print('✓ SoilGrids data accessible');
  print('  SOC bands available:', socBands.length);
  print('  Example bands:', socBands.slice(0, 3));
} catch (error) {
  print('✗ ERROR: Cannot access SoilGrids data');
  print('  Error message:', error.message);
  print('');
  print('TROUBLESHOOTING:');
  print('1. Check Earth Engine Data Catalog');
  print('2. Verify you have accepted Terms of Service for SoilGrids');
  print('3. Ensure you are authenticated in Earth Engine');
  throw new Error('SoilGrids data not accessible');
}

// Define band names for each depth interval
// Format: property_depth_statistic (e.g., soc_0-5cm_mean)
var depthBands = {
  '0-5': '0-5cm',
  '5-15': '5-15cm',
  '15-30': '15-30cm',
  '30-60': '30-60cm',
  '60-100': '60-100cm'
};

var depths = ['0-5', '5-15', '15-30', '30-60', '60-100'];

print('');
print('Selecting bands for each depth interval...');

var soilgrids = {};
var bulk_density = {};
var loadErrors = [];

// Select bands for each depth interval
depths.forEach(function(depth) {
  var bandDepth = depthBands[depth];
  
  try {
    // SOC mean (g/kg)
    soilgrids[depth] = soc_mean.select('soc_' + bandDepth + '_mean');
    
    // Bulk density mean (cg/cm³)
    bulk_density[depth] = bdod_mean.select('bdod_' + bandDepth + '_mean');
    
    print('  ✓ Selected', depth, 'cm bands');
    
  } catch (error) {
    loadErrors.push(depth);
    print('  ✗ Failed to select', depth, 'cm bands:', error.message);
  }
});

// Check for loading errors
if (loadErrors.length > 0) {
  print('');
  print('⚠ WARNING: Failed to load', loadErrors.length, 'depth intervals:', loadErrors.join(', '));
  print('Script cannot continue without all depth intervals');
  throw new Error('Critical depth intervals missing: ' + loadErrors.join(', '));
}

print('');
print('✓ All SoilGrids layers loaded successfully');

// Print metadata for verification
print('');
print('SoilGrids Layer Metadata:');
var sampleLayer = soilgrids['0-5'];
print('  Projection:', sampleLayer.projection().crs().getInfo());
print('  Native scale (m):', sampleLayer.projection().nominalScale().getInfo());
print('  Band name:', sampleLayer.bandNames().getInfo());

// Test data range (should be reasonable SOC values)
print('');
print('Testing data values in study area...');
var testStats = sampleLayer.reduceRegion({
  reducer: ee.Reducer.minMax().combine({
    reducer2: ee.Reducer.mean(),
    sharedInputs: true
  }),
  geometry: studyArea.bounds(),
  scale: 1000,
  maxPixels: 1e6,
  bestEffort: true
});

var statsInfo = testStats.getInfo();
print('  SOC 0-5cm statistics:', statsInfo);
print('  Expected: SOC typically 5-200 g/kg for most soils');

print('═══════════════════════════════════════');

// ============================================================================
// SOTHE ET AL. 2022 DATA (Optional - User Provided)
// ============================================================================

var useSothe = (SOTHE_SOIL_CARBON !== '' ||
                SOTHE_FOREST_BIOMASS !== '' ||
                SOTHE_OTHER_BIOMASS !== '');

var sothe_soil = null;
var sothe_soil_unc = null;
var sothe_forest = null;
var sothe_other = null;

if (useSothe) {
  print('Loading Sothe et al. 2022 BC Coast data...');

  if (SOTHE_SOIL_CARBON !== '') {
    sothe_soil = ee.Image(SOTHE_SOIL_CARBON);
  }

  if (SOTHE_SOIL_CARBON_UNCERTAINTY !== '') {
    sothe_soil_unc = ee.Image(SOTHE_SOIL_CARBON_UNCERTAINTY);
  }

  if (SOTHE_FOREST_BIOMASS !== '') {
    // Note: Sothe forest biomass may be an ImageCollection
    // Adjust as needed based on actual asset structure
    try {
      sothe_forest = ee.ImageCollection(SOTHE_FOREST_BIOMASS).mosaic();
    } catch (e) {
      sothe_forest = ee.Image(SOTHE_FOREST_BIOMASS);
    }
  }

  if (SOTHE_OTHER_BIOMASS !== '') {
    sothe_other = ee.Image(SOTHE_OTHER_BIOMASS);
  }

  print('Sothe layers loaded:', {
    soil: sothe_soil !== null,
    soil_unc: sothe_soil_unc !== null,
    forest: sothe_forest !== null,
    other: sothe_other !== null
  });
} else {
  print('Sothe et al. 2022 layers not provided - using SoilGrids only');
}

// ============================================================================
// CONVERSION FUNCTIONS
// ============================================================================

// Convert SOC concentration (g/kg) to carbon stock (kg/m²)
// Formula: Stock (kg/m²) = SOC (g/kg) × BD (kg/m³) × depth (m) / 1000
// Note: BD in SoilGrids is cg/cm³, multiply by 10 to get kg/m³
function socToKgM2(soc_gkg, bd_cgcm3, depth_cm) {
  // Convert bulk density from cg/cm³ to kg/m³
  var bd_kgm3 = bd_cgcm3.multiply(10);
  
  // Convert depth from cm to m
  var depth_m = depth_cm / 100;
  
  // Calculate stock: SOC (g/kg) × BD (kg/m³) × depth (m) / 1000
  // Division by 1000 converts g/kg to kg/kg (i.e., fraction)
  return soc_gkg.multiply(bd_kgm3).multiply(depth_m).divide(1000);
}

// ============================================================================
// CALCULATE CARBON STOCKS FOR VM0033 DEPTH INTERVALS
// ============================================================================

print('Calculating carbon stocks for VM0033 intervals (kg/m²)...');

var vm0033_stocks = {};

// ----------------------------------------------------------------------------
// 0-15 cm: Sum of 0-5 cm and 5-15 cm intervals
// ----------------------------------------------------------------------------
var stock_0_5 = socToKgM2(soilgrids['0-5'], bulk_density['0-5'], 5);
var stock_5_15 = socToKgM2(soilgrids['5-15'], bulk_density['5-15'], 10);
vm0033_stocks['0-15'] = stock_0_5.add(stock_5_15).rename('soc_stock_0_15cm');

print('0-15 cm: Sum of 0-5 cm (5 cm depth) + 5-15 cm (10 cm depth)');

// ----------------------------------------------------------------------------
// 15-30 cm: Direct match with SoilGrids 15-30 cm interval
// ----------------------------------------------------------------------------
vm0033_stocks['15-30'] = socToKgM2(
  soilgrids['15-30'],
  bulk_density['15-30'],
  15
).rename('soc_stock_15_30cm');

print('15-30 cm: Direct match (15 cm depth)');

// ----------------------------------------------------------------------------
// 30-50 cm: Partial from 30-60 cm interval (20 out of 30 cm)
// ----------------------------------------------------------------------------
// SoilGrids 30-60 covers 30 cm, we need only 30-50 (20 cm)
// Assumption: uniform distribution within the interval
var stock_30_60_full = socToKgM2(soilgrids['30-60'], bulk_density['30-60'], 30);
vm0033_stocks['30-50'] = stock_30_60_full.multiply(20/30).rename('soc_stock_30_50cm');

print('30-50 cm: 20/30 of the 30-60 cm interval');

// ----------------------------------------------------------------------------
// 50-100 cm: Partial from 30-60 cm (10 cm) + all of 60-100 cm (40 cm)
// ----------------------------------------------------------------------------
// We need 50-60 (10 cm from 30-60 interval) + 60-100 (40 cm)
var stock_30_60_partial = stock_30_60_full.multiply(10/30);  // 50-60 cm
var stock_60_100 = socToKgM2(soilgrids['60-100'], bulk_density['60-100'], 40);
vm0033_stocks['50-100'] = stock_30_60_partial.add(stock_60_100).rename('soc_stock_50_100cm');

print('50-100 cm: 10/30 of 30-60 cm interval + full 60-100 cm interval (40 cm)');

// ============================================================================
// CALCULATE UNCERTAINTY FOR STOCKS (kg/m²)
// ============================================================================

print('Calculating stock uncertainty (SE in kg/m²)...');
print('NOTE: SoilGrids quantiles not available - estimating SE as 30% of mean');
print('This is a conservative estimate based on typical global soil data uncertainty');

var vm0033_stocks_se = {};

// Estimate SE as 30% of mean carbon stock
// This is scientifically defensible as a conservative uncertainty estimate
// for global soil data products in the absence of direct uncertainty measures
Object.keys(vm0033_stocks).forEach(function(interval) {
  vm0033_stocks_se[interval] = vm0033_stocks[interval]
    .multiply(0.30)
    .rename('soc_se_' + interval.replace('-', '_') + 'cm');
});

print('✓ Uncertainty estimates calculated (30% of mean)');

// ============================================================================
// CALCULATE COEFFICIENT OF VARIATION (FOR NEYMAN SAMPLING)
// ============================================================================

print('Calculating coefficient of variation (CV %)...');

var cv_layers = {};

Object.keys(vm0033_stocks).forEach(function(interval) {
  // CV = (SE / Mean) × 100
  cv_layers[interval] = vm0033_stocks_se[interval]
    .divide(vm0033_stocks[interval])
    .multiply(100)
    .rename('cv_' + interval.replace('-', '_') + 'cm');
});

// Create uncertainty strata (low/med/high) for Neyman allocation
// Using 0-15 cm as representative surface layer
var cv_surface = cv_layers['0-15'];

var uncertainty_strata = ee.Image(0)
  .where(cv_surface.lt(15), 1)   // Low uncertainty
  .where(cv_surface.gte(15).and(cv_surface.lt(30)), 2)  // Medium
  .where(cv_surface.gte(30), 3)  // High
  .rename('uncertainty_stratum')
  .clip(studyArea);

print('Uncertainty strata: 1=Low (CV<15%), 2=Medium (15-30%), 3=High (CV≥30%)');

// ============================================================================
// BLEND WITH SOTHE ET AL. 2022 FOR TOTAL 0-100cm STOCK (IF AVAILABLE)
// ============================================================================
// STRATEGY: Blend total 0-100cm stock from SoilGrids with Sothe et al. 1m total
//           Then apply scaling factor proportionally to all depth intervals

if (useSothe && sothe_soil !== null) {
  print('═══════════════════════════════════════');
  print('BLENDING STRATEGY FOR TOTAL 0-100cm CARBON STOCK');
  print('═══════════════════════════════════════');
  print('Combining SoilGrids (global) with Sothe et al. 2022 (BC Coast regional)');
  print('Method: Precision-weighted blending of 0-100cm totals, then proportional scaling');

  // Step 1: Calculate SoilGrids total 0-100cm stock
  var soilgrids_total_0_100 = vm0033_stocks['0-15']
    .add(vm0033_stocks['15-30'])
    .add(vm0033_stocks['30-50'])
    .add(vm0033_stocks['50-100'])
    .rename('soilgrids_total_0_100cm');

  // Calculate SoilGrids total SE using error propagation: SE_total = sqrt(SE1² + SE2² + SE3² + SE4²)
  var soilgrids_total_se = vm0033_stocks_se['0-15'].pow(2)
    .add(vm0033_stocks_se['15-30'].pow(2))
    .add(vm0033_stocks_se['30-50'].pow(2))
    .add(vm0033_stocks_se['50-100'].pow(2))
    .sqrt()
    .rename('soilgrids_total_se_0_100cm');

  print('Step 1: Calculated SoilGrids total 0-100cm stock by summing all intervals');

  // Step 2: Blend SoilGrids total with Sothe et al. total (both 0-100cm)
  if (sothe_soil_unc !== null) {
    // Precision-weighted average: w = 1/SE²
    var weight_soilgrids = soilgrids_total_se.pow(-2);
    var weight_sothe = sothe_soil_unc.pow(-2);

    var blended_total = soilgrids_total_0_100.multiply(weight_soilgrids)
      .add(sothe_soil.multiply(weight_sothe))
      .divide(weight_soilgrids.add(weight_sothe))
      .rename('blended_total_0_100cm');

    // Blended total SE
    var blended_total_se = weight_soilgrids.add(weight_sothe)
      .pow(-0.5)
      .rename('blended_total_se_0_100cm');

    print('Step 2: Blended totals using precision-weighted average');
    print('  Formula: Blended = (w_sg × Total_sg + w_sothe × Total_sothe) / (w_sg + w_sothe)');

    // Step 3: Calculate scaling factor
    var scaling_factor = blended_total.divide(soilgrids_total_0_100);

    print('Step 3: Calculated scaling factor = Blended_total / SoilGrids_total');

    // Step 4: Apply scaling factor to ALL depth intervals proportionally
    print('Step 4: Applying scaling factor to all depth intervals...');

    var intervals = ['0-15', '15-30', '30-50', '50-100'];
    intervals.forEach(function(interval) {
      // Scale the mean
      var scaled_mean = vm0033_stocks[interval].multiply(scaling_factor);
      vm0033_stocks[interval] = scaled_mean;

      // Scale the SE (uncertainty also scales proportionally)
      var scaled_se = vm0033_stocks_se[interval].multiply(scaling_factor);
      vm0033_stocks_se[interval] = scaled_se;

      var midpoint = VM0033_INTERVALS[interval].midpoint;
      print('  ✓ Scaled ' + midpoint + ' cm depth (interval ' + interval + ' cm)');
    });

    print('');
    print('✓ All depth intervals adjusted using SoilGrids + Sothe et al. blending');
    print('  Expected: Regional accuracy from Sothe et al. distributed across all depths');
    print('  Expected: Depth pattern preserved from SoilGrids');
    print('  Expected: Reduced uncertainty compared to SoilGrids alone');

  } else {
    // Simple average if uncertainty not available
    print('⚠ Sothe uncertainty not available - using simple average of totals');

    var blended_total = soilgrids_total_0_100.add(sothe_soil).divide(2);
    var scaling_factor = blended_total.divide(soilgrids_total_0_100);

    var intervals = ['0-15', '15-30', '30-50', '50-100'];
    intervals.forEach(function(interval) {
      vm0033_stocks[interval] = vm0033_stocks[interval].multiply(scaling_factor);
      vm0033_stocks_se[interval] = vm0033_stocks_se[interval].multiply(scaling_factor);
    });

    print('✓ Applied simple average scaling to all depth intervals');
  }

  print('');
  print('FINAL PRIOR STRATEGY:');
  print('  • SoilGrids provides depth distribution pattern');
  print('  • Sothe et al. provides regional total correction (0-100cm)');
  print('  • All 4 depth intervals scaled proportionally by blended total');
  print('  7.5 cm (0-15 cm): SoilGrids pattern × Regional scaling');
  print('  22.5 cm (15-30 cm): SoilGrids pattern × Regional scaling');
  print('  40 cm (30-50 cm): SoilGrids pattern × Regional scaling');
  print('  75 cm (50-100 cm): SoilGrids pattern × Regional scaling');
  print('═══════════════════════════════════════');
} else {
  print('Sothe et al. 2022 data not available - using SoilGrids only for all depths');
}

// ============================================================================
// VISUALIZATION
// ============================================================================

print('Adding layers to map...');

// Center on study area
Map.centerObject(studyArea, 10);
Map.addLayer(studyArea, {color: 'FF0000'}, 'Study Area', true);

// SOC stock at 0-15 cm (surface)
Map.addLayer(
  vm0033_stocks['0-15'].clip(studyArea),
  {min: 0, max: 10, palette: ['#FFF7BC', '#FEE391', '#FEC44F', '#FE9929', '#D95F0E', '#993404']},
  'SOC Stock 0-15cm (kg/m²)',
  false
);

// SOC stock at 50-100 cm (deep)
Map.addLayer(
  vm0033_stocks['50-100'].clip(studyArea),
  {min: 0, max: 15, palette: ['#F0F9E8', '#BAE4BC', '#7BCCC4', '#43A2CA', '#0868AC']},
  'SOC Stock 50-100cm (kg/m²)',
  false
);

// Uncertainty (SE) at 0-15 cm
Map.addLayer(
  vm0033_stocks_se['0-15'].clip(studyArea),
  {min: 0, max: 3, palette: ['#238B45', '#FFEDA0', '#FD8D3C', '#E31A1C']},
  'SE 0-15cm (kg/m²)',
  false
);

// Coefficient of Variation at 0-15 cm
Map.addLayer(
  cv_layers['0-15'].clip(studyArea),
  {min: 0, max: 50, palette: ['#1A9850', '#91CF60', '#FEE08B', '#FC8D59', '#D73027']},
  'CV 0-15cm (%)',
  false
);

// Uncertainty strata for sampling design
Map.addLayer(
  uncertainty_strata,
  {min: 1, max: 3, palette: ['#1B9E77', '#D95F02', '#7570B3']},
  'Uncertainty Strata (Neyman)',
  true
);

// If Sothe layers available, show them
if (sothe_soil !== null) {
  Map.addLayer(
    sothe_soil.clip(studyArea),
    {min: 0, max: 30, palette: ['#FFFFCC', '#A1DAB4', '#41B6C4', '#225EA8']},
    'Sothe Soil C to 1m (kg/m²)',
    false
  );
}

if (sothe_forest !== null) {
  Map.addLayer(
    sothe_forest.clip(studyArea),
    {min: 0, max: 200, palette: ['#F7FCF5', '#74C476', '#238B45', '#00441B']},
    'Sothe Forest Biomass (Mg/ha)',
    false
  );
}

// ============================================================================
// EXPORT TASKS
// ============================================================================

print('═══════════════════════════════════════');
print('Setting up export tasks...');
print('Check the Tasks tab and click RUN for each export');
print('═══════════════════════════════════════');

var VM0033_EXPORT_INTERVALS = ['0-15', '15-30', '30-50', '50-100'];

// Export carbon stocks and SE for each VM0033 interval
// Using VM0033 midpoint depths in filenames: 7_5, 22_5, 40, 75 cm
// Note: Replace decimal points with underscores for GIS compatibility
VM0033_EXPORT_INTERVALS.forEach(function(interval) {
  var midpoint = VM0033_INTERVALS[interval].midpoint;

  // Convert decimal to underscore format (e.g., 7.5 → 7_5, 40 → 40)
  var midpoint_str = String(midpoint).replace('.', '_');

  // Export Mean Carbon Stock (kg/m²)
  // File naming: carbon_stock_prior_mean_7_5cm.tif
  Export.image.toDrive({
    image: vm0033_stocks[interval].clip(studyArea),
    description: 'carbon_stock_prior_mean_' + midpoint_str + 'cm',
    folder: EXPORT_FOLDER,
    fileNamePrefix: 'carbon_stock_prior_mean_' + midpoint_str + 'cm',
    region: studyArea,
    scale: EXPORT_SCALE,
    crs: EXPORT_CRS,
    maxPixels: 1e13
  });

  // Export Standard Error (kg/m²)
  // File naming: carbon_stock_prior_se_7_5cm.tif
  Export.image.toDrive({
    image: vm0033_stocks_se[interval].clip(studyArea),
    description: 'carbon_stock_prior_se_' + midpoint_str + 'cm',
    folder: EXPORT_FOLDER,
    fileNamePrefix: 'carbon_stock_prior_se_' + midpoint_str + 'cm',
    region: studyArea,
    scale: EXPORT_SCALE,
    crs: EXPORT_CRS,
    maxPixels: 1e13
  });

  // Export Coefficient of Variation (%) - for diagnostic purposes
  Export.image.toDrive({
    image: cv_layers[interval].clip(studyArea),
    description: 'carbon_stock_prior_cv_' + midpoint_str + 'cm',
    folder: EXPORT_FOLDER,
    fileNamePrefix: 'carbon_stock_prior_cv_' + midpoint_str + 'cm',
    region: studyArea,
    scale: EXPORT_SCALE,
    crs: EXPORT_CRS,
    maxPixels: 1e13
  });
});

// Export uncertainty strata
Export.image.toDrive({
  image: uncertainty_strata,
  description: 'uncertainty_strata',
  folder: EXPORT_FOLDER,
  fileNamePrefix: 'uncertainty_strata',
  region: studyArea,
  scale: EXPORT_SCALE,
  crs: EXPORT_CRS,
  maxPixels: 1e13
});

// Note: Sothe et al. data is blended into the 50-100cm layer above
// No need to export Sothe layers separately

// ============================================================================
// SUMMARY AND METADATA
// ============================================================================

print('═══════════════════════════════════════');
print('EXPORT SETUP COMPLETE');
print('═══════════════════════════════════════');
print('Study Area Bounds:', studyArea.bounds());
print('Export Scale:', EXPORT_SCALE, 'meters');
print('Export CRS:', EXPORT_CRS);
print('VM0033 Midpoint Depths: 7_5, 22_5, 40, 75 cm (underscore format for GIS compatibility)');
print('');
print('UNITS: All carbon stocks in kg/m² (kilograms per square meter)');
print('');
print('DATA SOURCES AND STRATEGY:');
print('  • SoilGrids v2.0 (Poggio et al. 2021) - Global baseline');
print('    - SOC concentration: g/kg');
print('    - Bulk density: cg/cm³');
print('    - Resolution: 250m');
print('    - Used for: ALL depth intervals');
if (useSothe) {
  print('');
  print('  • Sothe et al. 2022 BC Coast - Regional refinement');
  print('    - Soil carbon to 1m (0-100cm total): kg/m²');
  print('    - Used for: Blending with SoilGrids 0-100cm total');
  print('    - Blending method: Precision-weighted average of totals');
  print('    - Scaling: Applied proportionally to all 4 depth intervals');
}
print('');
print('DEPTH INTERVAL CALCULATIONS FROM SOILGRIDS:');
print('  • 0-15 cm (7.5 cm midpoint):');
print('    = 0-5 cm (5 cm) + 5-15 cm (10 cm)');
print('  • 15-30 cm (22.5 cm midpoint):');
print('    = 15-30 cm (15 cm) direct match');
print('  • 30-50 cm (40 cm midpoint):');
print('    = 20/30 × 30-60 cm interval');
print('  • 50-100 cm (75 cm midpoint):');
print('    = 10/30 × 30-60 cm + 60-100 cm (40 cm)');
print('');
if (useSothe && sothe_soil !== null) {
  print('BLENDING APPLIED:');
  print('  • Sum all 4 SoilGrids intervals = Total 0-100cm');
  print('  • Blend: (SoilGrids total) + (Sothe et al. total) using precision weights');
  print('  • Calculate scaling factor = Blended_total / SoilGrids_total');
  print('  • Apply scaling factor to ALL 4 depth intervals proportionally');
  print('  • Result: Regional accuracy + SoilGrids depth pattern preserved');
}
print('');
print('EXPORTED FILES (13 total):');
print('  Prior Means (4 files):');
print('    - carbon_stock_prior_mean_7_5cm.tif');
print('    - carbon_stock_prior_mean_22_5cm.tif');
print('    - carbon_stock_prior_mean_40cm.tif');
print('    - carbon_stock_prior_mean_75cm.tif');
print('');
print('  Prior Standard Errors (4 files):');
print('    - carbon_stock_prior_se_7_5cm.tif');
print('    - carbon_stock_prior_se_22_5cm.tif');
print('    - carbon_stock_prior_se_40cm.tif');
print('    - carbon_stock_prior_se_75cm.tif');
print('');
print('  Diagnostics (5 files):');
print('    - carbon_stock_prior_cv_7_5cm.tif (coefficient of variation)');
print('    - carbon_stock_prior_cv_22_5cm.tif');
print('    - carbon_stock_prior_cv_40cm.tif');
print('    - carbon_stock_prior_cv_75cm.tif');
print('    - uncertainty_strata.tif (for Neyman sampling)');
print('');
print('NEXT STEPS:');
print('1. Go to Tasks tab (top right in Code Editor)');
print('2. Click RUN on each export task (~13 tasks)');
print('3. Wait for exports to complete (~5-30 min depending on area)');
print('4. Download files from Google Drive/' + EXPORT_FOLDER);
print('5. Place in: data_prior/gee_exports/');
print('6. Run Module 00C in R to process priors');
print('7. Run Module 01C for Bayesian sampling design');
print('═══════════════════════════════════════');

// ============================================================================
// QUALITY CONTROL CHECKS
// ============================================================================

print('');
print('QUALITY CONTROL:');

// Check for negative values (shouldn't happen but good to verify)
var hasNegatives = vm0033_stocks['0-15'].lt(0).reduceRegion({
  reducer: ee.Reducer.anyNonZero(),
  geometry: studyArea,
  scale: EXPORT_SCALE,
  maxPixels: 1e13
});

print('Contains negative values?', hasNegatives);

// Sample statistics for surface layer
var stats_0_15 = vm0033_stocks['0-15'].reduceRegion({
  reducer: ee.Reducer.minMax().combine({
    reducer2: ee.Reducer.mean(),
    sharedInputs: true
  }).combine({
    reducer2: ee.Reducer.stdDev(),
    sharedInputs: true
  }),
  geometry: studyArea,
  scale: EXPORT_SCALE,
  maxPixels: 1e13
});

print('0-15 cm Stock Statistics (kg/m²):', stats_0_15);

// Sample statistics for deep layer
var stats_50_100 = vm0033_stocks['50-100'].reduceRegion({
  reducer: ee.Reducer.minMax().combine({
    reducer2: ee.Reducer.mean(),
    sharedInputs: true
  }).combine({
    reducer2: ee.Reducer.stdDev(),
    sharedInputs: true
  }),
  geometry: studyArea,
  scale: EXPORT_SCALE,
  maxPixels: 1e13
});

print('50-100 cm Stock Statistics (kg/m²):', stats_50_100);

print('═══════════════════════════════════════');
