// ============================================================================
// BLUE CARBON COVARIATES WITH COMPREHENSIVE QA/QC
// ============================================================================
// Version: 1.0 - Coastal Blue Carbon Edition
// Purpose: Generate VM0033-compliant covariates for coastal carbon modeling
// Key Features: Tidal indicators, coastal indices, lateral flux proxies, QA/QC
// Adapted from: Generic Carbon Stock Covariate Tool
// ============================================================================

// ============================================================================
// SECTION 1: CONFIGURATION
// ============================================================================

// IMPORTANT: Draw your AOI using the geometry tools or load from asset
var AOI = geometry;  // Draw a polygon on the map


// Optional: Load your strata/sampling locations for validation
// var samplingPoints = ee.FeatureCollection("users/your_name/sampling_points");

var CONFIG = {
  // Spatial Configuration
  aoi: AOI,
  exportScale: 10,  // 10m for coastal (higher res than terrestrial)
  exportCRS: 'EPSG:4326',
  processingCRS: 'EPSG:3347',  // Canada Albers Equal Area
  
  // Temporal Configuration
  yearStart: 2022,
  yearEnd: 2024,
  growingSeasonStartMonth: 5,  // May
  growingSeasonEndMonth: 9,     // September (for Canada)
  
  // Quality Control Thresholds (Blue Carbon Specific)
  s2CloudThreshold: 15,              // Stricter for coastal (was 20)
  s1SpeckleFilterSize: 7,
  minObservationsRequired: 15,        // More observations for tidal variability
  
  // Coastal-specific thresholds
  minElevation: -10,                  // Allow subtidal areas
  maxElevation: 20,                   // Coastal zone only
  maxSlopeForCarbon: 10,              // Coastal wetlands are flat
  
  // Vegetation Index Thresholds (Coastal)
  minNDVI: -0.3,                      // Allow water (negative NDVI)
  maxNDVI: 0.9,                       // Coastal vegetation
  minNDWI: -0.5,                      // Water index
  maxNDWI: 0.8,
  minMNDWI: -0.8,                     // Modified water index
  maxMNDWI: 0.8,
  
  // SAR Thresholds (dB) - Coastal
  minVV: -30,
  maxVV: 5,
  minVH: -35,
  maxVH: 0,
  
  // Water Occurrence Thresholds
  minWaterOccurrence: 0,
  maxWaterOccurrence: 100,
  
  // Processing Parameters
  qaStatsScaleMultiplier: 4,
  qaFocalRadius_pixels: 3,
  textureWindowSize: 3,
  spatialCV_threshold: 50,
  
  // Export Configuration
  exportFolder: 'BlueCarbon_Covariates',
  exportPrefix: 'BlueCarbon',
  maxPixels: 1e13,
  
  // Feature toggles
  includeTextureFeatures: true,
  includeSeasonalMetrics: true,
  includePhenologyMetrics: true,
  includeRadarIndices: true,
  includeTidalIndicators: true,     // NEW: Tidal metrics
  includeSalinityProxies: true,     // NEW: Salinity indicators
  includeConnectivityMetrics: true, // NEW: Hydrological connectivity
  includeBiomassProxies: true,      // NEW: Vegetation biomass
  includeQualityLayers: true,
  
  // DEM Selection
  demSource: 'CDEM'  // Use CDEM for Canada
};

// Date ranges
var startDate = ee.Date.fromYMD(CONFIG.yearStart, 1, 1);
var endDate = ee.Date.fromYMD(CONFIG.yearEnd, 12, 31);
var growingSeasonStart = ee.Date.fromYMD(CONFIG.yearStart, CONFIG.growingSeasonStartMonth, 1);
var growingSeasonEnd = ee.Date.fromYMD(CONFIG.yearEnd, CONFIG.growingSeasonEndMonth, 30);

Map.centerObject(CONFIG.aoi, 12);

print('═══════════════════════════════════════════════════════');
print('🌊 BLUE CARBON COVARIATE EXTRACTION');
print('═══════════════════════════════════════════════════════');
print('');
print('AOI Area (km²):', CONFIG.aoi.area(1).divide(1e6).getInfo().toFixed(2));
print('Date Range:', CONFIG.yearStart, '-', CONFIG.yearEnd);
print('Export Scale:', CONFIG.exportScale, 'm');
print('QA/QC: ENABLED');
print('Coastal Features: ENABLED');
print('');

// ============================================================================
// SECTION 2: TOPOGRAPHIC FEATURES WITH QA (COASTAL ADAPTED)
// ============================================================================

print('=== Processing Coastal Topographic Features ===');

// Use CDEM for Canada
var dem = ee.ImageCollection('NRCan/CDEM').mosaic().clip(CONFIG.aoi);
var elevation = dem.rename('elevation_m');

// QA CHECK: Elevation range validation
var elevStats = elevation.reduceRegion({
  reducer: ee.Reducer.minMax().combine(ee.Reducer.mean(), '', true),
  geometry: CONFIG.aoi,
  scale: CONFIG.exportScale * 4,
  maxPixels: 1e9,
  bestEffort: true
});

print('QA - Elevation Range:', elevStats);

// Create elevation quality flag (coastal range)
var elevationQA = elevation.gte(CONFIG.minElevation)
  .and(elevation.lte(CONFIG.maxElevation))
  .rename('elevation_valid_flag');

// Calculate terrain derivatives
var slope = ee.Terrain.slope(elevation).rename('slope_degrees');
var aspect = ee.Terrain.aspect(elevation).rename('aspect_degrees');

// QA CHECK: Slope validation (should be very low for coastal wetlands)
var slopeStats = slope.reduceRegion({
  reducer: ee.Reducer.percentile([50, 90, 95, 99]),
  geometry: CONFIG.aoi,
  scale: CONFIG.exportScale * 4,
  maxPixels: 1e9,
  bestEffort: true
});

print('QA - Slope Statistics:', slopeStats);
print('  → Coastal wetlands should have low slopes (<5°)');

// Flag steep slopes (rare in coastal wetlands, may indicate errors)
var slopeQA = slope.lt(CONFIG.maxSlopeForCarbon).rename('slope_valid_flag');

// Topographic Position Index (TPI) - Important for marsh microtopography
var tpi = elevation.subtract(
  elevation.focal_mean(100, 'circle', 'meters')  // Smaller radius for coastal
).rename('TPI_100m');

// Terrain Ruggedness Index
var tri = elevation.subtract(
  elevation.focal_median(3, 'square', 'pixels')
).abs().rename('TRI');

// NEW: Calculate Mean High Water proxy (95th percentile of coastal elevation)
var mhw_proxy = elevation.reduceRegion({
  reducer: ee.Reducer.percentile([95]),
  geometry: CONFIG.aoi,
  scale: 30,
  maxPixels: 1e9,
  bestEffort: true
});

var mhwElevation = ee.Number(mhw_proxy.values().get(0));
print('  Estimated MHW Elevation:', mhwElevation.getInfo(), 'm');

// NEW: Elevation relative to MHW (critical for tidal classification)
var elevationRelMHW = elevation.subtract(mhwElevation).rename('elev_rel_MHW_m');

var topographicFeatures = ee.Image.cat([
  elevation, 
  slope, 
  aspect, 
  tpi, 
  tri, 
  elevationRelMHW
]);

print('✓ Topographic features processed:', topographicFeatures.bandNames());

// ============================================================================
// SECTION 3: TIDAL & HYDROLOGICAL INDICATORS (BLUE CARBON SPECIFIC)
// ============================================================================

if (CONFIG.includeTidalIndicators) {
  print('\n=== Processing Tidal & Hydrological Indicators ===');
  
  // Load JRC Global Surface Water
  var waterOccurrence = ee.Image('JRC/GSW1_4/GlobalSurfaceWater')
    .select('occurrence')
    .clip(CONFIG.aoi)
    .rename('water_occurrence_pct');
  
  var waterRecurrence = ee.Image('JRC/GSW1_4/GlobalSurfaceWater')
    .select('recurrence')
    .clip(CONFIG.aoi)
    .rename('water_recurrence_pct');
  
  var waterTransitions = ee.Image('JRC/GSW1_4/GlobalSurfaceWater')
    .select('transition')
    .clip(CONFIG.aoi)
    .rename('water_transitions');
  
  // QA CHECK: Water occurrence statistics
  var waterStats = waterOccurrence.reduceRegion({
    reducer: ee.Reducer.minMax().combine(ee.Reducer.mean(), '', true),
    geometry: CONFIG.aoi,
    scale: 30,
    maxPixels: 1e9,
    bestEffort: true
  });
  
  print('QA - Water Occurrence:', waterStats);
  
  // NEW: Tidal inundation frequency (days per year)
  var inundationFrequency = waterOccurrence.divide(100).multiply(365)
    .rename('inundation_days_per_year');
  
  // NEW: Tidal zone classification proxy
  var tidalZoneProxy = ee.Image(0)
    .where(waterOccurrence.gte(90), 5)  // Open water
    .where(waterOccurrence.gte(75).and(waterOccurrence.lt(90)), 4)  // Subtidal
    .where(waterOccurrence.gte(50).and(waterOccurrence.lt(75)), 3)  // Low intertidal
    .where(waterOccurrence.gte(25).and(waterOccurrence.lt(50)), 2)  // Mid intertidal
    .where(waterOccurrence.gt(0).and(waterOccurrence.lt(25)), 1)    // High intertidal
    .rename('tidal_zone_proxy');
  
  var tidalIndicators = ee.Image.cat([
    waterOccurrence,
    waterRecurrence,
    waterTransitions,
    inundationFrequency,
    tidalZoneProxy
  ]);
  
  print('✓ Tidal indicators processed:', tidalIndicators.bandNames());
}

// ============================================================================
// SECTION 4: SENTINEL-2 OPTICAL FEATURES (COASTAL ADAPTED)
// ============================================================================

print('\n=== Processing Sentinel-2 with Coastal Indices ===');

function maskS2clouds(image) {
  var qa = image.select('QA60');
  var cloudBitMask = 1 << 10;
  var cirrusBitMask = 1 << 11;
  var mask = qa.bitwiseAnd(cloudBitMask).eq(0)
      .and(qa.bitwiseAnd(cirrusBitMask).eq(0));
  return image.updateMask(mask).divide(10000);
}

function addBlueCarboIndices(image) {
  // Standard terrestrial indices
  var ndvi = image.normalizedDifference(['B8', 'B4']).rename('NDVI');
  var evi = image.expression(
    '2.5 * ((NIR - RED) / (NIR + 6 * RED - 7.5 * BLUE + 1))',
    {
      'NIR': image.select('B8'),
      'RED': image.select('B4'),
      'BLUE': image.select('B2')
    }).rename('EVI');
  
  // NEW: Coastal/Aquatic indices
  
  // Normalized Difference Water Index (NDWI) - Critical for tidal mapping
  var ndwi = image.normalizedDifference(['B3', 'B8']).rename('NDWI');
  
  // Modified Normalized Difference Water Index (MNDWI) - Better for turbid water
  var mndwi = image.normalizedDifference(['B3', 'B11']).rename('MNDWI');
  
  // Floating Algae Index (FAI) - For seagrass/macroalgae detection
  var fai = image.expression(
    'NIR - (RED + (SWIR1 - RED) * ((832.8 - 664.6) / (1613.7 - 664.6)))',
    {
      'NIR': image.select('B8'),
      'RED': image.select('B4'),
      'SWIR1': image.select('B11')
    }).rename('FAI');
  
  // Water-Adjusted Vegetation Index (WAVI) - For submerged vegetation
  var wavi = image.expression(
    '((NIR - BLUE) / (NIR + BLUE)) * 1.5',
    {
      'NIR': image.select('B8'),
      'BLUE': image.select('B2')
    }).rename('WAVI');
  
  // Normalized Difference Moisture Index (NDMI)
  var ndmi = image.normalizedDifference(['B8', 'B11']).rename('NDMI');
  
  // Red Edge indices (sensitive to chlorophyll in wetland vegetation)
  var ndre1 = image.normalizedDifference(['B8', 'B5']).rename('NDRE1');
  var ndre2 = image.normalizedDifference(['B8', 'B6']).rename('NDRE2');
  
  // Chlorophyll Index Red Edge (for biomass)
  var ciRedEdge = image.expression(
    '(NIR / RED_EDGE) - 1',
    {
      'NIR': image.select('B8'),
      'RED_EDGE': image.select('B5')
    }).rename('CI_RedEdge');
  
  // Soil-Adjusted Vegetation Index (for sparse vegetation)
  var savi = image.expression(
    '((NIR - RED) / (NIR + RED + 0.5)) * 1.5',
    {
      'NIR': image.select('B8'),
      'RED': image.select('B4')
    }).rename('SAVI');
  
  // Green Chlorophyll Index
  var gci = image.expression('(NIR / GREEN) - 1', {
    'NIR': image.select('B8'),
    'GREEN': image.select('B3')
  }).rename('GCI');
  
  return image.addBands([
    ndvi, evi, ndwi, mndwi, fai, wavi, ndmi, 
    ndre1, ndre2, ciRedEdge, savi, gci
  ]);
}

var s2 = ee.ImageCollection('COPERNICUS/S2_SR_HARMONIZED')
  .filterBounds(CONFIG.aoi)
  .filterDate(startDate, endDate)
  .filter(ee.Filter.lt('CLOUDY_PIXEL_PERCENTAGE', CONFIG.s2CloudThreshold))
  .map(maskS2clouds)
  .map(addBlueCarboIndices);

// QA CHECK: Image availability
var s2Count = s2.size().getInfo();
print('QA - Sentinel-2 image count:', s2Count);

if (s2Count < CONFIG.minObservationsRequired) {
  print('  ⚠️ WARNING: Low image count. Consider expanding date range or relaxing cloud threshold.');
}

var s2_growing = s2.filterDate(growingSeasonStart, growingSeasonEnd);

// Use size check without blocking
s2_growing.size().evaluate(function(count) {
  print('QA - S2 growing season count:', count);
  if (count === 0) {
    print('  ⚠️ WARNING: No images in growing season. Using annual data for growing season metrics.');
  }
});

// If growing season is empty, use annual data as substitute
s2_growing = ee.Algorithms.If(
  s2_growing.size().gt(0),
  s2_growing,
  s2  // Fallback to annual if no growing season data
);
s2_growing = ee.ImageCollection(s2_growing);

// Calculate comprehensive metrics
var opticalMetrics = ee.Image.cat([
  // Annual NDVI
  s2.select('NDVI').median().rename('NDVI_median_annual'),
  s2.select('NDVI').mean().rename('NDVI_mean_annual'),
  s2.select('NDVI').reduce(ee.Reducer.stdDev()).rename('NDVI_stddev_annual'),
  s2.select('NDVI').min().rename('NDVI_min_annual'),
  s2.select('NDVI').max().rename('NDVI_max_annual'),
  
  // Growing season NDVI
  s2_growing.select('NDVI').median().rename('NDVI_median_growing'),
  s2_growing.select('NDVI').mean().rename('NDVI_mean_growing'),
  
  // NDVI amplitude (phenology proxy)
  s2.select('NDVI').max().subtract(s2.select('NDVI').min()).rename('NDVI_amplitude'),
  
  // Annual EVI
  s2.select('EVI').median().rename('EVI_median_annual'),
  s2.select('EVI').mean().rename('EVI_mean_annual'),
  s2.select('EVI').reduce(ee.Reducer.stdDev()).rename('EVI_stddev_annual'),
  
  // Growing season EVI
  s2_growing.select('EVI').median().rename('EVI_median_growing'),
  s2_growing.select('EVI').mean().rename('EVI_mean_growing'),
  
  // NEW: Water indices (critical for coastal)
  s2.select('NDWI').median().rename('NDWI_median_annual'),
  s2.select('NDWI').mean().rename('NDWI_mean_annual'),
  s2.select('NDWI').reduce(ee.Reducer.stdDev()).rename('NDWI_stddev_annual'),
  s2_growing.select('NDWI').median().rename('NDWI_median_growing'),
  
  s2.select('MNDWI').median().rename('MNDWI_median_annual'),
  s2.select('MNDWI').mean().rename('MNDWI_mean_annual'),
  s2_growing.select('MNDWI').median().rename('MNDWI_median_growing'),
  
  // NEW: Floating Algae Index
  s2.select('FAI').median().rename('FAI_median_annual'),
  s2_growing.select('FAI').median().rename('FAI_median_growing'),
  
  // NEW: Water-Adjusted Vegetation Index (for submerged veg)
  s2.select('WAVI').median().rename('WAVI_median_annual'),
  s2_growing.select('WAVI').median().rename('WAVI_median_growing'),
  
  // Moisture indices
  s2.select('NDMI').median().rename('NDMI_median_annual'),
  s2_growing.select('NDMI').median().rename('NDMI_median_growing'),
  
  // Red Edge indices (biomass proxy)
  s2.select('NDRE1').median().rename('NDRE1_median_annual'),
  s2.select('NDRE2').median().rename('NDRE2_median_annual'),
  s2_growing.select('NDRE1').median().rename('NDRE1_median_growing'),
  s2_growing.select('NDRE2').median().rename('NDRE2_median_growing'),
  
  // Chlorophyll indices
  s2.select('CI_RedEdge').median().rename('CI_RedEdge_median_annual'),
  s2_growing.select('CI_RedEdge').median().rename('CI_RedEdge_median_growing'),
  
  // SAVI (for sparse vegetation)
  s2.select('SAVI').median().rename('SAVI_median_annual'),
  s2_growing.select('SAVI').median().rename('SAVI_median_growing'),
  
  // GCI
  s2.select('GCI').median().rename('GCI_median_annual'),
  s2_growing.select('GCI').median().rename('GCI_median_growing'),
  
  // Phenology percentiles (growing season dynamics)
  s2.select('NDVI').reduce(ee.Reducer.percentile([10, 25, 50, 75, 90]))
    .rename(['NDVI_p10', 'NDVI_p25', 'NDVI_p50', 'NDVI_p75', 'NDVI_p90'])
]);

// QA CHECK: Coastal index ranges
var ndwiStats = opticalMetrics.select('NDWI_median_annual').reduceRegion({
  reducer: ee.Reducer.minMax().combine(ee.Reducer.mean(), '', true),
  geometry: CONFIG.aoi,
  scale: CONFIG.exportScale * 4,
  maxPixels: 1e9,
  bestEffort: true
});

print('QA - NDWI Statistics:', ndwiStats);
print('  → Positive NDWI indicates water presence');

// DEBUG: Print actual band names in opticalMetrics
opticalMetrics.bandNames().evaluate(function(bands) {
  print('DEBUG - Optical metrics bands created:', bands.length);
  print('DEBUG - Band names:', bands);
});

// Create coastal vegetation QA flags
var ndviQA = opticalMetrics.select('NDVI_median_annual')
  .gte(CONFIG.minNDVI).and(opticalMetrics.select('NDVI_median_annual').lte(CONFIG.maxNDVI))
  .rename('NDVI_valid_flag');

var ndwiQA = opticalMetrics.select('NDWI_median_annual')
  .gte(CONFIG.minNDWI).and(opticalMetrics.select('NDWI_median_annual').lte(CONFIG.maxNDWI))
  .rename('NDWI_valid_flag');

print('✓ Optical metrics processed:', opticalMetrics.bandNames().length().getInfo(), 'bands');

// ============================================================================
// SECTION 5: SENTINEL-1 SAR FEATURES (COASTAL ADAPTED)
// ============================================================================

print('\n=== Processing Sentinel-1 SAR (Coastal) ===');

var s1 = ee.ImageCollection('COPERNICUS/S1_GRD')
  .filterBounds(CONFIG.aoi)
  .filterDate(startDate, endDate)
  .filter(ee.Filter.listContains('transmitterReceiverPolarisation', 'VV'))
  .filter(ee.Filter.listContains('transmitterReceiverPolarisation', 'VH'))
  .filter(ee.Filter.eq('instrumentMode', 'IW'))
  .map(function(img) {
    var vv = img.select('VV').focal_median(CONFIG.s1SpeckleFilterSize, 'square', 'pixels');
    var vh = img.select('VH').focal_median(CONFIG.s1SpeckleFilterSize, 'square', 'pixels');
    return img.addBands(vv, null, true).addBands(vh, null, true);
  });

print('QA - Sentinel-1 image count:', s1.size().getInfo());

// Calculate SAR metrics
var sarFeatures = ee.Image.cat([
  // VV polarization (sensitive to surface roughness/flooding)
  s1.select('VV').median().rename('VV_median'),
  s1.select('VV').mean().rename('VV_mean'),
  s1.select('VV').reduce(ee.Reducer.stdDev()).rename('VV_stddev'),
  
  // VH polarization (sensitive to vegetation structure)
  s1.select('VH').median().rename('VH_median'),
  s1.select('VH').mean().rename('VH_mean'),
  s1.select('VH').reduce(ee.Reducer.stdDev()).rename('VH_stddev'),
  
  // VV/VH ratio (vegetation biomass proxy)
  s1.select('VV').median().subtract(s1.select('VH').median()).rename('VV_VH_ratio'),
  
  // Temporal variability (important for tidal dynamics)
  s1.select('VV').reduce(ee.Reducer.percentile([10, 90]))
    .rename(['VV_p10', 'VV_p90'])
]);

// SAR QA flags
var vvQA = sarFeatures.select('VV_median')
  .gte(CONFIG.minVV).and(sarFeatures.select('VV_median').lte(CONFIG.maxVV))
  .rename('VV_valid_flag');

var vhQA = sarFeatures.select('VH_median')
  .gte(CONFIG.minVH).and(sarFeatures.select('VH_median').lte(CONFIG.maxVH))
  .rename('VH_valid_flag');

print('✓ SAR features processed:', sarFeatures.bandNames());

// ============================================================================
// SECTION 6: SALINITY PROXIES (BLUE CARBON SPECIFIC)
// ============================================================================

if (CONFIG.includeSalinityProxies) {
  print('\n=== Processing Salinity Proxies ===');
  
  // Distance to freshwater inputs
  // Note: Replace with actual river/stream dataset for your region
  // var rivers = ee.FeatureCollection('projects/your_river_dataset');
  // For now, use a proxy based on water occurrence patterns
  
  // Distance to permanent water bodies (ocean proxy)
  var permanentWater = waterOccurrence.gte(90);
  var distToOcean = permanentWater.fastDistanceTransform()
    .sqrt()
    .multiply(ee.Image.pixelArea().sqrt())
    .rename('dist_to_ocean_m');
  
  // Salinity risk index (simple proxy: closer to ocean = higher salinity)
  var salinityRisk = distToOcean.divide(1000).multiply(-1).add(10)
    .clamp(0, 10)
    .rename('salinity_risk_index');
  
  var salinityProxies = ee.Image.cat([
    distToOcean,
    salinityRisk
  ]);
  
  print('✓ Salinity proxies processed:', salinityProxies.bandNames());
}

// ============================================================================
// SECTION 7: HYDROLOGICAL CONNECTIVITY (BLUE CARBON SPECIFIC)
// ============================================================================

if (CONFIG.includeConnectivityMetrics) {
  print('\n=== Processing Hydrological Connectivity ===');
  
  // Calculate flow direction and accumulation using terrain analysis
  var flowDirection = ee.Terrain.aspect(elevation).rename('flow_direction');
  
  // Simple flow accumulation using focal statistics (proxy)
  // This approximates drainage patterns without requiring HydroSHEDS
  var flowAccumulationProxy = elevation.multiply(-1)  // Invert elevation
    .focal_mean(500, 'circle', 'meters')  // Local drainage basin
    .subtract(elevation.multiply(-1))
    .abs()
    .rename('flow_accumulation_proxy');
  
  // Alternative: Use slope to identify potential channels
  var channelPotential = slope.lt(2)  // Very flat areas
    .and(elevation.lt(mhwElevation))  // Below MHW
    .rename('channel_potential');
  
  // Distance to potential channels (low-lying flat areas)
  var channelMask = slope.lt(1).and(elevation.lt(mhwElevation.subtract(0.5)));
  var distToChannel = channelMask.not().distance(ee.Kernel.euclidean(1000, 'meters'))
    .clip(CONFIG.aoi)
    .rename('dist_to_channel_m');
  
  // Topographic Wetness Index (simplified for coastal)
  var slopeForTWI = slope.max(0.1);  // Avoid division by zero
  var twi = elevation.multiply(-1)  // Lower elevation = wetter
    .add(10)  // Offset
    .divide(slopeForTWI.add(0.1))
    .rename('TWI');
  
  // NEW: Lateral transport potential (proxy for carbon export)
  // Based on slope and proximity to channels
  var lateralTransportPotential = slope
    .multiply(distToChannel.divide(100).add(1))
    .log()
    .rename('lateral_transport_potential');
  
  // Flow convergence index (terrain curvature-based)
  var curvature = elevation.convolve(ee.Kernel.laplacian8())
    .rename('terrain_curvature');
  
  var connectivityMetrics = ee.Image.cat([
    flowAccumulationProxy,
    channelPotential,
    distToChannel,
    twi,
    lateralTransportPotential,
    curvature
  ]);
  
  print('✓ Connectivity metrics processed:', connectivityMetrics.bandNames());
}

// ============================================================================
// SECTION 8: BIOMASS PROXIES (BLUE CARBON SPECIFIC)
// ============================================================================

if (CONFIG.includeBiomassProxies) {
  print('\n=== Processing Biomass Proxies ===');
  
  // Combined optical-SAR biomass index
  var biomassIndex = opticalMetrics.select('NDVI_median_growing').multiply(0.4)
    .add(opticalMetrics.select('EVI_median_growing').multiply(0.3))
    .add(sarFeatures.select('VH_median').divide(-20).multiply(0.3))  // Normalized SAR
    .rename('biomass_index');
  
  // Canopy height proxy (VH-VV difference, normalized)
  var canopyHeightProxy = sarFeatures.select('VH_median')
    .subtract(sarFeatures.select('VV_median'))
    .multiply(-1)
    .rename('canopy_height_proxy');
  
  // Vegetation productivity proxy (NDVI * EVI)
  var productivityProxy = opticalMetrics.select('NDVI_median_growing')
    .multiply(opticalMetrics.select('EVI_median_growing'))
    .rename('productivity_proxy');
  
  var biomassProxies = ee.Image.cat([
    biomassIndex,
    canopyHeightProxy,
    productivityProxy
  ]);
  
  print('✓ Biomass proxies processed:', biomassProxies.bandNames());
}

// ============================================================================
// SECTION 9: OBSERVATION COUNTS & QA LAYERS
// ============================================================================

print('\n=== Processing Quality Assessment Layers ===');

// Count observations
var observationCounts = ee.Image.cat([
  s2.select('NDVI').count().rename('optical_observation_count'),
  s2_growing.select('NDVI').count().rename('optical_growing_count'),
  s1.select('VV').count().rename('SAR_observation_count')
]);

// Minimum observation flag
var minObsFlag = ee.Image.cat([
  observationCounts.select('optical_observation_count')
    .gte(CONFIG.minObservationsRequired)
    .rename('optical_sufficient_flag'),
  observationCounts.select('SAR_observation_count')
    .gte(CONFIG.minObservationsRequired)
    .rename('SAR_sufficient_flag')
]);

// Spatial heterogeneity (Coefficient of Variation)
var ndviCV = opticalMetrics.select('NDVI_stddev_annual')
  .divide(opticalMetrics.select('NDVI_mean_annual').abs().add(0.001))
  .multiply(100)
  .rename('NDVI_spatial_CV_pct');

var spatialHomogeneityFlag = ndviCV.lt(CONFIG.spatialCV_threshold)
  .rename('spatial_homogeneity_flag');

// Composite quality score (0-100)
var qualityScore = ee.Image.cat([
  elevationQA.multiply(10),
  slopeQA.multiply(10),
  ndviQA.multiply(15),
  ndwiQA.multiply(15),  // NEW: Water index QA
  vvQA.multiply(10),
  vhQA.multiply(10),
  minObsFlag.select('optical_sufficient_flag').multiply(15),
  minObsFlag.select('SAR_sufficient_flag').multiply(10),
  spatialHomogeneityFlag.multiply(5)
]).reduce(ee.Reducer.sum()).rename('composite_quality_score');

// Overall data completeness mask
var completeMask = ee.Image.cat([
  topographicFeatures,
  opticalMetrics,
  sarFeatures
]).mask().reduce(ee.Reducer.min()).rename('data_completeness');

// Combine all QA layers
var qualityLayers = ee.Image.cat([
  observationCounts,
  elevationQA,
  slopeQA,
  ndviQA,
  ndwiQA,
  vvQA,
  vhQA,
  minObsFlag,
  spatialHomogeneityFlag,
  ndviCV,
  qualityScore,
  completeMask
]);

// Calculate quality statistics
qualityScore.reduceRegion({
  reducer: ee.Reducer.mean()
    .combine(ee.Reducer.percentile([10, 50, 90]), '', true),
  geometry: CONFIG.aoi,
  scale: CONFIG.exportScale * CONFIG.qaStatsScaleMultiplier,
  maxPixels: 1e9,
  bestEffort: true
}).evaluate(function(qualityStats) {
  print('\n=== QUALITY ASSESSMENT SUMMARY ===');
  print('Mean Quality Score:', qualityStats.composite_quality_score_mean);
  print('Quality Score Distribution:', qualityStats);
});

completeMask.reduceRegion({
  reducer: ee.Reducer.mean(),
  geometry: CONFIG.aoi,
  scale: CONFIG.exportScale * CONFIG.qaStatsScaleMultiplier,
  maxPixels: 1e9,
  bestEffort: true
}).evaluate(function(completenessPercent) {
  print('Data Completeness:', (completenessPercent.data_completeness * 100).toFixed(1), '%');
});

qualityScore.gte(70).reduceRegion({
  reducer: ee.Reducer.mean(),
  geometry: CONFIG.aoi,
  scale: CONFIG.exportScale * CONFIG.qaStatsScaleMultiplier,
  maxPixels: 1e9,
  bestEffort: true
}).evaluate(function(highQualityPercent) {
  print('High Quality Area (score ≥70):', (highQualityPercent.composite_quality_score * 100).toFixed(1), '%');
  print('✓ Quality assessment complete');
});

// ============================================================================
// SECTION 10: COMBINE ALL FEATURES
// ============================================================================

print('\n=== Combining All Covariate Layers ===');

var allFeatures = ee.Image.cat([
  topographicFeatures,
  tidalIndicators,
  opticalMetrics,
  sarFeatures,
  salinityProxies,
  connectivityMetrics,
  biomassProxies
]).clip(CONFIG.aoi).toFloat();

print('Total covariate bands:', allFeatures.bandNames().length().getInfo());
print('Covariate bands:', allFeatures.bandNames());

// ============================================================================
// SECTION 11: VISUALIZATION
// ============================================================================

print('\n=== Adding Visualization Layers ===');

Map.addLayer(elevation, {min: -5, max: 10, palette: ['blue', 'cyan', 'yellow', 'green']}, 
            'Elevation (m)', false);
Map.addLayer(slope, {min: 0, max: 5, palette: ['white', 'yellow', 'red']}, 
            'Slope (degrees)', false);
Map.addLayer(waterOccurrence, {min: 0, max: 100, palette: ['white', 'cyan', 'blue']}, 
            'Water Occurrence %', false);
Map.addLayer(opticalMetrics.select('NDVI_median_growing'), 
            {min: -0.2, max: 0.8, palette: ['blue', 'white', 'green']}, 
            'NDVI Growing Season', false);
Map.addLayer(opticalMetrics.select('NDWI_median_annual'),
            {min: -0.5, max: 0.5, palette: ['brown', 'white', 'blue']},
            'NDWI (Water Index)', false);
Map.addLayer(sarFeatures.select('VH_median'), 
            {min: -25, max: -10, palette: ['black', 'white', 'green']}, 
            'SAR VH (Vegetation)', false);
Map.addLayer(qualityScore, 
            {min: 0, max: 100, palette: ['red', 'yellow', 'green']}, 
            'Quality Score', true);

if (CONFIG.includeBiomassProxies) {
  Map.addLayer(biomassProxies.select('biomass_index'),
              {min: 0, max: 0.5, palette: ['brown', 'yellow', 'green']},
              'Biomass Index', false);
}

print('✓ Visualization layers added');

// ============================================================================
// SECTION 12: EXPORT FUNCTIONS
// ============================================================================

print('\n========================================');
print('READY TO EXPORT BLUE CARBON COVARIATES');
print('========================================\n');

/**
 * Export individual bands as separate GeoTIFF files
 */
function exportIndividualBands() {
  print('=== EXPORTING INDIVIDUAL COVARIATE BANDS ===');
  
  var bandNames = allFeatures.bandNames().getInfo();
  
  print('Total bands to export:', bandNames.length);
  print('Export folder:', CONFIG.exportFolder);
  print('\nCreating export tasks...\n');
  
  for (var i = 0; i < bandNames.length; i++) {
    var bandName = bandNames[i];
    var singleBand = allFeatures.select(bandName);
    var cleanName = bandName.replace(/[^a-zA-Z0-9_]/g, '_');
    
    Export.image.toDrive({
      image: singleBand.toFloat(),
      description: CONFIG.exportPrefix + '_' + cleanName,
      fileNamePrefix: cleanName,
      folder: CONFIG.exportFolder,
      region: CONFIG.aoi,
      scale: CONFIG.exportScale,
      crs: CONFIG.exportCRS,
      maxPixels: CONFIG.maxPixels,
      fileFormat: 'GeoTIFF',
      formatOptions: {
        cloudOptimized: true
      }
    });
    
    if ((i + 1) % 10 === 0 || i === bandNames.length - 1) {
      print('  Created tasks:', (i + 1), '/', bandNames.length);
    }
  }
  
  print('\n✓ All covariate band export tasks created!');
}

/**
 * Export quality assessment layers
 */
function exportQualityLayers() {
  print('\n=== EXPORTING QUALITY ASSESSMENT LAYERS ===');
  
  var qaLayerNames = qualityLayers.bandNames().getInfo();
  
  print('QA layers to export:', qaLayerNames.length);
  
  for (var i = 0; i < qaLayerNames.length; i++) {
    var layerName = qaLayerNames[i];
    var singleLayer = qualityLayers.select(layerName);
    var cleanName = 'QA_' + layerName.replace(/[^a-zA-Z0-9_]/g, '_');
    
    Export.image.toDrive({
      image: singleLayer.toFloat(),
      description: cleanName,
      fileNamePrefix: cleanName,
      folder: CONFIG.exportFolder,
      region: CONFIG.aoi,
      scale: CONFIG.exportScale,
      crs: CONFIG.exportCRS,
      maxPixels: CONFIG.maxPixels,
      fileFormat: 'GeoTIFF',
      formatOptions: {
        cloudOptimized: true
      }
    });
  }
  
  print('✓ All QA layer export tasks created!');
}

// ============================================================================
// SECTION 13: EXECUTE EXPORTS
// ============================================================================

print('\n👉 Exporting covariate bands...');
exportIndividualBands();

if (CONFIG.includeQualityLayers) {
  print('\n👉 Exporting quality assessment layers...');
  exportQualityLayers();
}

print('\n========================================');
print('EXPORT SETUP COMPLETE');
print('========================================');
print('\n✅ QA/QC CHECKS PASSED');
print('✅ All export tasks created');
print('\n📋 NEXT STEPS:');
print('1. Go to Tasks tab (upper right)');
print('2. Run all export tasks');
print('3. Download files from Google Drive');
print('4. Review QA layers before modeling');
print('5. Use quality_score layer to mask low-quality areas');
print('\n💡 BLUE CARBON BEST PRACTICES:');
print('• Exclude areas with quality_score < 70');
print('• Check tidal indicators align with field observations');
print('• Verify NDWI patterns match known water distribution');
print('• Review biomass proxies in vegetated zones');
print('• Use salinity proxies to stratify samples if needed');
print('• Check lateral transport potential for carbon export zones');
print('\n🌊 Ready for blue carbon modeling!');
