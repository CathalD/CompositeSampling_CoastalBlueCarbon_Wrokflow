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
//
// INSTRUCTIONS:
//   1. Define your study area (studyArea variable below)
//   2. Add Sothe et al. 2022 asset paths (SOTHE_* variables)
//   3. Run script in GEE Code Editor
//   4. Export all tasks to Google Drive
//   5. Download files and run Module 00C in R to process
// ============================================================================

// ============================================================================
// USER INPUTS - MODIFY THESE
// ============================================================================

// Study area boundary (draw polygon or import shapefile)
// Example: Draw a polygon in GEE or import from assets
var studyArea = ee.FeatureCollection('users/YOUR_USERNAME/YOUR_BOUNDARY');
// Or draw manually:
// var studyArea = ee.Geometry.Rectangle([-123.5, 49.0, -123.0, 49.3]);

// Export parameters
var EXPORT_SCALE = 250;  // Resolution in meters (SoilGrids native)
var EXPORT_CRS = 'EPSG:3005';  // BC Albers (or your preferred CRS)
var EXPORT_FOLDER = 'BlueCarbon_Priors';  // Google Drive folder name

// Sothe et al. 2022 BC Coast Assets
// **USER MUST UPDATE THESE PATHS**
// Format: 'users/YOUR_USERNAME/ASSET_NAME' or 'projects/PROJECT_ID/ASSET_NAME'
var SOTHE_FOREST_BIOMASS = '';  // ← ENTER PATH HERE
var SOTHE_SOIL_CARBON = '';     // ← ENTER PATH HERE
var SOTHE_OTHER_BIOMASS = '';   // ← ENTER PATH HERE

// VM0033 Standard Depths (midpoints in cm)
var VM0033_DEPTHS = [7.5, 22.5, 40, 75];

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

print('Loading SoilGrids 250m data...');

// SoilGrids v2.0 (Poggio et al. 2021)
// SOC in g/kg at different depths
var soilgrids = {
  '0-5': ee.Image('projects/soilgrids-isric/soc_0-5cm_mean'),
  '5-15': ee.Image('projects/soilgrids-isric/soc_5-15cm_mean'),
  '15-30': ee.Image('projects/soilgrids-isric/soc_15-30cm_mean'),
  '30-60': ee.Image('projects/soilgrids-isric/soc_30-60cm_mean'),
  '60-100': ee.Image('projects/soilgrids-isric/soc_60-100cm_mean')
};

// Uncertainty (5th and 95th percentiles)
var soilgrids_q05 = {
  '0-5': ee.Image('projects/soilgrids-isric/soc_0-5cm_Q0.05'),
  '5-15': ee.Image('projects/soilgrids-isric/soc_5-15cm_Q0.05'),
  '15-30': ee.Image('projects/soilgrids-isric/soc_15-30cm_Q0.05'),
  '30-60': ee.Image('projects/soilgrids-isric/soc_30-60cm_Q0.05'),
  '60-100': ee.Image('projects/soilgrids-isric/soc_60-100cm_Q0.05')
};

var soilgrids_q95 = {
  '0-5': ee.Image('projects/soilgrids-isric/soc_0-5cm_Q0.95'),
  '5-15': ee.Image('projects/soilgrids-isric/soc_5-15cm_Q0.95'),
  '15-30': ee.Image('projects/soilgrids-isric/soc_15-30cm_Q0.95'),
  '30-60': ee.Image('projects/soilgrids-isric/soc_30-60cm_Q0.95'),
  '60-100': ee.Image('projects/soilgrids-isric/soc_60-100cm_Q0.95')
};

// Bulk density (needed for g/kg → Mg/ha conversion)
var bulk_density = {
  '0-5': ee.Image('projects/soilgrids-isric/bdod_0-5cm_mean'),
  '5-15': ee.Image('projects/soilgrids-isric/bdod_5-15cm_mean'),
  '15-30': ee.Image('projects/soilgrids-isric/bdod_15-30cm_mean'),
  '30-60': ee.Image('projects/soilgrids-isric/bdod_30-60cm_mean'),
  '60-100': ee.Image('projects/soilgrids-isric/bdod_60-100cm_mean')
};

// ============================================================================
// SOTHE ET AL. 2022 DATA (Optional - User Provided)
// ============================================================================

var useSothe = (SOTHE_SOIL_CARBON !== '' ||
                SOTHE_FOREST_BIOMASS !== '' ||
                SOTHE_OTHER_BIOMASS !== '');

if (useSothe) {
  print('Loading Sothe et al. 2022 BC Coast data...');

  var sothe_soil = SOTHE_SOIL_CARBON !== '' ?
    ee.Image(SOTHE_SOIL_CARBON) : null;

  var sothe_forest = SOTHE_FOREST_BIOMASS !== '' ?
    ee.Image(SOTHE_FOREST_BIOMASS) : null;

  var sothe_other = SOTHE_OTHER_BIOMASS !== '' ?
    ee.Image(SOTHE_OTHER_BIOMASS) : null;

  print('Sothe layers loaded:', {
    soil: sothe_soil !== null,
    forest: sothe_forest !== null,
    other: sothe_other !== null
  });
} else {
  print('Sothe et al. 2022 layers not provided - using SoilGrids only');
}

// ============================================================================
// INTERPOLATE TO VM0033 DEPTHS
// ============================================================================

print('Interpolating to VM0033 standard depths...');

// Function to linearly interpolate between two SoilGrids layers
function interpolateDepth(targetDepth, layer1, depth1, layer2, depth2) {
  // Linear interpolation weight
  var weight = (targetDepth - depth1) / (depth2 - depth1);

  return layer1.multiply(1 - weight).add(layer2.multiply(weight));
}

// Interpolate to VM0033 depths
var vm0033_layers = {};

// 7.5 cm: interpolate between 0-5 (midpoint=2.5) and 5-15 (midpoint=10)
vm0033_layers['7.5'] = interpolateDepth(
  7.5,
  soilgrids['0-5'], 2.5,
  soilgrids['5-15'], 10
);

// 22.5 cm: interpolate between 15-30 (midpoint=22.5) - perfect match!
vm0033_layers['22.5'] = soilgrids['15-30'];

// 40 cm: interpolate between 30-60 (midpoint=45) and previous
vm0033_layers['40'] = interpolateDepth(
  40,
  soilgrids['15-30'], 22.5,
  soilgrids['30-60'], 45
);

// 75 cm: interpolate between 60-100 (midpoint=80) and previous
vm0033_layers['75'] = interpolateDepth(
  75,
  soilgrids['30-60'], 45,
  soilgrids['60-100'], 80
);

// ============================================================================
// CALCULATE UNCERTAINTY (SE FROM QUANTILES)
// ============================================================================

print('Calculating uncertainty layers...');

// Approximate SE from 5th and 95th percentiles
// Assuming normal distribution: q95 - q05 ≈ 3.29 * SD
// Therefore: SE ≈ (q95 - q05) / 3.29

function calculateSE(q05, q95) {
  return q95.subtract(q05).divide(3.29);
}

var vm0033_se = {};

// 7.5 cm SE
var se_7_5_q05 = interpolateDepth(7.5, soilgrids_q05['0-5'], 2.5, soilgrids_q05['5-15'], 10);
var se_7_5_q95 = interpolateDepth(7.5, soilgrids_q95['0-5'], 2.5, soilgrids_q95['5-15'], 10);
vm0033_se['7.5'] = calculateSE(se_7_5_q05, se_7_5_q95);

// 22.5 cm SE
vm0033_se['22.5'] = calculateSE(soilgrids_q05['15-30'], soilgrids_q95['15-30']);

// 40 cm SE
var se_40_q05 = interpolateDepth(40, soilgrids_q05['15-30'], 22.5, soilgrids_q05['30-60'], 45);
var se_40_q95 = interpolateDepth(40, soilgrids_q95['15-30'], 22.5, soilgrids_q95['30-60'], 45);
vm0033_se['40'] = calculateSE(se_40_q05, se_40_q95);

// 75 cm SE
var se_75_q05 = interpolateDepth(75, soilgrids_q05['30-60'], 45, soilgrids_q05['60-100'], 80);
var se_75_q95 = interpolateDepth(75, soilgrids_q95['30-60'], 45, soilgrids_q95['60-100'], 80);
vm0033_se['75'] = calculateSE(se_75_q05, se_75_q95);

// ============================================================================
// OPTIONAL: BLEND WITH SOTHE ET AL. 2022 (IF AVAILABLE)
// ============================================================================

if (useSothe && sothe_soil !== null) {
  print('Blending SoilGrids with Sothe et al. 2022 soil carbon...');

  // Simple average where both datasets overlap
  // More sophisticated: precision-weighted average
  // For now: give equal weight

  Object.keys(vm0033_layers).forEach(function(depth) {
    var blended = vm0033_layers[depth].blend(sothe_soil);
    vm0033_layers[depth] = blended;
  });
}

// ============================================================================
// CALCULATE COEFFICIENT OF VARIATION (FOR NEYMAN SAMPLING)
// ============================================================================

print('Calculating coefficient of variation...');

var cv_layers = {};

Object.keys(vm0033_layers).forEach(function(depth) {
  // CV = SE / Mean × 100
  cv_layers[depth] = vm0033_se[depth]
    .divide(vm0033_layers[depth])
    .multiply(100)
    .rename('cv_' + depth + 'cm');
});

// Create uncertainty strata (low/med/high) for Neyman allocation
// Using 7.5cm as representative surface layer
var cv_surface = cv_layers['7.5'];

var uncertainty_strata = ee.Image(0)
  .where(cv_surface.lt(10), 1)   // Low uncertainty
  .where(cv_surface.gte(10).and(cv_surface.lt(30)), 2)  // Medium
  .where(cv_surface.gte(30), 3)  // High
  .rename('uncertainty_stratum')
  .clip(studyArea);

// ============================================================================
// VISUALIZATION
// ============================================================================

// Add layers to map
Map.centerObject(studyArea, 10);
Map.addLayer(studyArea, {color: 'red'}, 'Study Area', false);

// SOC mean at 7.5cm (surface)
Map.addLayer(
  vm0033_layers['7.5'].clip(studyArea),
  {min: 0, max: 100, palette: ['yellow', 'orange', 'brown', 'black']},
  'SOC 7.5cm (g/kg)',
  false
);

// Uncertainty (CV) at 7.5cm
Map.addLayer(
  cv_layers['7.5'].clip(studyArea),
  {min: 0, max: 50, palette: ['green', 'yellow', 'red']},
  'CV 7.5cm (%)',
  false
);

// Uncertainty strata
Map.addLayer(
  uncertainty_strata,
  {min: 1, max: 3, palette: ['green', 'yellow', 'red']},
  'Uncertainty Strata (Neyman)',
  true
);

// ============================================================================
// EXPORT TASKS
// ============================================================================

print('Setting up export tasks...');
print('Check the Tasks tab and click RUN for each export');

// Export each VM0033 depth - MEAN
VM0033_DEPTHS.forEach(function(depth) {
  var depthStr = depth.toString().replace('.', '_');

  Export.image.toDrive({
    image: vm0033_layers[depth.toString()].clip(studyArea),
    description: 'soc_prior_mean_' + depthStr + 'cm',
    folder: EXPORT_FOLDER,
    fileNamePrefix: 'soc_prior_mean_' + depthStr + 'cm',
    region: studyArea,
    scale: EXPORT_SCALE,
    crs: EXPORT_CRS,
    maxPixels: 1e13
  });

  // Export SE
  Export.image.toDrive({
    image: vm0033_se[depth.toString()].clip(studyArea),
    description: 'soc_prior_se_' + depthStr + 'cm',
    folder: EXPORT_FOLDER,
    fileNamePrefix: 'soc_prior_se_' + depthStr + 'cm',
    region: studyArea,
    scale: EXPORT_SCALE,
    crs: EXPORT_CRS,
    maxPixels: 1e13
  });

  // Export CV
  Export.image.toDrive({
    image: cv_layers[depth.toString()].clip(studyArea),
    description: 'soc_prior_cv_' + depthStr + 'cm',
    folder: EXPORT_FOLDER,
    fileNamePrefix: 'soc_prior_cv_' + depthStr + 'cm',
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

// Export Sothe layers if available
if (useSothe) {
  if (sothe_soil !== null) {
    Export.image.toDrive({
      image: sothe_soil.clip(studyArea),
      description: 'sothe_soil_carbon',
      folder: EXPORT_FOLDER,
      fileNamePrefix: 'sothe_soil_carbon',
      region: studyArea,
      scale: EXPORT_SCALE,
      crs: EXPORT_CRS,
      maxPixels: 1e13
    });
  }

  if (sothe_forest !== null) {
    Export.image.toDrive({
      image: sothe_forest.clip(studyArea),
      description: 'sothe_forest_biomass',
      folder: EXPORT_FOLDER,
      fileNamePrefix: 'sothe_forest_biomass',
      region: studyArea,
      scale: EXPORT_SCALE,
      crs: EXPORT_CRS,
      maxPixels: 1e13
    });
  }

  if (sothe_other !== null) {
    Export.image.toDrive({
      image: sothe_other.clip(studyArea),
      description: 'sothe_other_biomass',
      folder: EXPORT_FOLDER,
      fileNamePrefix: 'sothe_other_biomass',
      region: studyArea,
      scale: EXPORT_SCALE,
      crs: EXPORT_CRS,
      maxPixels: 1e13
    });
  }
}

// ============================================================================
// SUMMARY
// ============================================================================

print('═══════════════════════════════════════');
print('EXPORT SETUP COMPLETE');
print('═══════════════════════════════════════');
print('Study Area:', studyArea.geometry().bounds());
print('Export Scale:', EXPORT_SCALE, 'meters');
print('Export CRS:', EXPORT_CRS);
print('VM0033 Depths:', VM0033_DEPTHS);
print('Using Sothe et al. 2022:', useSothe);
print('');
print('NEXT STEPS:');
print('1. Go to Tasks tab (top right)');
print('2. Click RUN on each export task');
print('3. Wait for exports to complete');
print('4. Download files from Google Drive');
print('5. Place in data_prior/ folder');
print('6. Run Module 00C in R to process');
print('═══════════════════════════════════════');
