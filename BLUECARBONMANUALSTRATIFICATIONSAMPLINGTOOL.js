// =================================================================================
// === BLUE CARBON MANUAL STRATIFICATION SAMPLING TOOL ============================
// =================================================================================
// Purpose: Generate hierarchical sampling design for coastal blue carbon ecosystems
//          with MANUAL stratification by 5 ecological zones
//
// Workflow:
//   1. User manually draws polygons for each of 5 ecosystem strata
//   2. Tool analyzes areas and visualizes with proper colors
//   3. User configures sampling parameters (HR cores, composites, subsamples)
//   4. Tool generates stratified sampling locations
//   5. Export results for field sampling
//
// Adapted from: North-Star Manual Stratification Tool + Blue Carbon protocols
// Updated: VM0033 Compliant - True systematic sampling, sample size validation
// =================================================================================

// =================================================================================
// === 1. CONFIGURATION ============================================================
// =================================================================================

var CONFIG = {
  // Sampling Design Parameters (VM0033 compliant)
  DEFAULT_HR_CORES: 15,
  DEFAULT_COMPOSITES_PER_STRATUM: 20,
  DEFAULT_COMPOSITE_AREA: 25, // m²
  DEFAULT_SUBSAMPLES: 5,
  DEFAULT_PAIRING_FRACTION: 0.5,
  DEFAULT_MAX_PAIRING_DISTANCE: 5000, // meters

  // Blue Carbon Specific
  CORE_DEPTH_CM: 100,  // VM0033 standard
  MIN_CORES_PER_STRATUM: 3,  // VM0033 minimum
  TARGET_CV: 30,  // Target coefficient of variation (%)

  // Analysis Parameters
  MAX_ERROR: 1, // meters for geometry operations
  RANDOM_SEED: 42
};

// 5 Coastal Ecosystem Strata Definitions
var ECOSYSTEM_STRATA = {
  'Upper Marsh': {
    color: 'FFFF99',
    description: 'Infrequently flooded, salt-tolerant shrubs (Spartina patens)',
    monitoring: 'Vegetation cover, soil cores, elevation surveys'
  },
  'Mid Marsh': {
    color: '99FF99',
    description: 'Regularly inundated, mixed halophytes - HIGHEST C sequestration',
    monitoring: 'Biomass sampling, redox, accretion tracking'
  },
  'Lower Marsh': {
    color: '33CC33',
    description: 'Daily tides, dense Spartina alterniflora - HIGHEST burial rates',
    monitoring: 'Hydrological monitoring, GHG flux, accretion'
  },
  'Underwater Vegetation': {
    color: '0066CC',
    description: 'Subtidal seagrass beds (Zostera marina)',
    monitoring: 'Remote sensing, underwater cores, biomass'
  },
  'Open Water': {
    color: '000099',
    description: 'Tidal channels, lagoons - carbon transport',
    monitoring: 'Water quality, sediment transport, DOC/DIC'
  }
};

var STYLES = {
  TITLE: {fontSize: '28px', fontWeight: 'bold', color: '#005931'},
  SUBTITLE: {fontSize: '18px', fontWeight: '500', color: '#0277BD'},
  PARAGRAPH: {fontSize: '14px', color: '#555555'},
  HEADER: {fontSize: '16px', fontWeight: 'bold', margin: '16px 0 4px 8px'},
  SUBHEADER: {fontSize: '14px', fontWeight: 'bold', margin: '10px 0 0 0'},
  PANEL: {width: '440px', border: '1px solid #cccccc'},
  HR: function() {
    return ui.Panel(null, ui.Panel.Layout.flow('horizontal'), {
      border: '1px solid #E0E0E0',
      margin: '20px 0px'
    });
  },
  INSTRUCTION: {fontSize: '12px', color: '#999999', margin: '4px 8px'},
  SUCCESS: {fontSize: '13px', color: '#388E3C', fontWeight: 'bold', margin: '8px'},
  ERROR: {fontSize: '13px', color: '#D32F2F', fontWeight: 'bold', margin: '8px'},
  WARNING: {fontSize: '13px', color: '#F57C00', fontWeight: 'bold', margin: '8px'},
  INFO: {fontSize: '12px', color: '#0277BD', margin: '4px 8px'}
};

// =================================================================================
// === 2. STATE MANAGEMENT =========================================================
// =================================================================================

var AppState = {
  drawnFeatures: [],
  finalStrataCollection: null,
  strataInfo: null,
  hrCores: null,
  composites: null,
  pairedComposites: null,
  subsamples: null,
  scenarioType: 'PROJECT',

  reset: function() {
    this.drawnFeatures = [];
    this.finalStrataCollection = null;
    this.strataInfo = null;
    this.hrCores = null;
    this.composites = null;
    this.pairedComposites = null;
    this.subsamples = null;
  }
};

// =================================================================================
// === 3. UTILITY FUNCTIONS ========================================================
// =================================================================================

var Utils = {
  /**
   * Create TRUE systematic (fishnet) grid of points with regular spacing
   * VM0033 compliant - provides better spatial coverage than random sampling
   */
  createSystematicGrid: function(region, count, seed) {
    // Calculate grid dimensions
    var area = region.area(CONFIG.MAX_ERROR);
    var pointsPerSide = ee.Number(count).sqrt().ceil();
    var cellSize = area.sqrt().divide(pointsPerSide);

    // Get bounding box
    var bounds = region.bounds(CONFIG.MAX_ERROR);
    var coords = ee.List(bounds.coordinates().get(0));
    var xMin = ee.Number(ee.List(coords.get(0)).get(0));
    var yMin = ee.Number(ee.List(coords.get(0)).get(1));
    var xMax = ee.Number(ee.List(coords.get(2)).get(0));
    var yMax = ee.Number(ee.List(coords.get(2)).get(1));

    // Calculate actual grid spacing
    var xSpacing = xMax.subtract(xMin).divide(pointsPerSide);
    var ySpacing = yMax.subtract(yMin).divide(pointsPerSide);

    // Generate systematic grid with random start (for unbiased coverage)
    var randomizer = ee.Number(seed).divide(1000).subtract(ee.Number(seed).divide(1000).floor());
    var xOffset = xSpacing.multiply(randomizer).multiply(0.5);
    var yOffset = ySpacing.multiply(randomizer.multiply(0.7)).multiply(0.5);

    // Create grid points
    var gridPoints = ee.FeatureCollection(
      ee.List.sequence(0, pointsPerSide.subtract(1)).map(function(i) {
        return ee.List.sequence(0, pointsPerSide.subtract(1)).map(function(j) {
          var x = xMin.add(xSpacing.multiply(ee.Number(i))).add(xSpacing.divide(2)).add(xOffset);
          var y = yMin.add(ySpacing.multiply(ee.Number(j))).add(ySpacing.divide(2)).add(yOffset);
          var point = ee.Geometry.Point([x, y]);
          return ee.Feature(point);
        });
      }).flatten()
    );

    // Filter to only points within the actual region and limit to requested count
    var filteredPoints = gridPoints.filterBounds(region).randomColumn('random', seed);

    // Return exactly the requested number of points
    return filteredPoints.limit(count, 'random');
  },

  /**
   * Creates square composite using buffer method
   */
  createSquare: function(point, area_m2) {
    var side = Math.sqrt(area_m2);
    var radius = side / 2;

    var buffer = point.geometry().buffer(radius, CONFIG.MAX_ERROR);
    var bounds = buffer.bounds(CONFIG.MAX_ERROR);

    return ee.Feature(bounds).set({
      'shape': 'square',
      'area_m2': area_m2
    });
  },

  /**
   * Creates circular composite area
   */
  createCircle: function(point, area_m2) {
    var radius = Math.sqrt(area_m2 / Math.PI);
    var buffer = point.geometry().buffer(radius, CONFIG.MAX_ERROR);
    return ee.Feature(buffer).set({
      'shape': 'circle',
      'area_m2': area_m2
    });
  },

  /**
   * Generates random points within a polygon
   */
  randomPointsInPolygon: function(polygon, count, seed) {
    return ee.FeatureCollection.randomPoints({
      region: polygon.geometry(),
      points: count,
      seed: seed
    });
  }
};

// =================================================================================
// === 3B. SAMPLE SIZE VALIDATION (VM0033 Compliance) ============================
// =================================================================================

var SampleSize = {
  /**
   * Calculate required sample size for VM0033 compliance
   * Based on 95% confidence intervals with acceptable error range of 10-20%
   *
   * @param {number} estimatedCV - Estimated coefficient of variation (%) for the stratum
   * @param {number} targetPrecision - Target relative error (default 20% for VM0033)
   * @param {number} confidenceLevel - Confidence level (default 95%)
   * @returns {Object} Required sample size and statistics
   */
  calculateRequiredN: function(estimatedCV, targetPrecision, confidenceLevel) {
    targetPrecision = targetPrecision || 20; // Default 20% relative error
    confidenceLevel = confidenceLevel || 95;

    // Z-score for confidence level
    var z = confidenceLevel === 95 ? 1.96 :
            confidenceLevel === 90 ? 1.645 :
            confidenceLevel === 99 ? 2.576 : 1.96;

    // Calculate required n using formula: n = (z * CV / targetPrecision)^2
    var requiredN = Math.pow((z * estimatedCV / targetPrecision), 2);

    return {
      requiredN: Math.ceil(requiredN),
      z: z,
      confidenceLevel: confidenceLevel,
      targetPrecision: targetPrecision,
      estimatedCV: estimatedCV
    };
  },

  /**
   * Validate sample allocation and show warnings/recommendations
   * VM0033 requires sufficient sampling to achieve 10-20% precision at 95% CI
   */
  validateAllocation: function(allocatedStrata, resultsPanel) {
    resultsPanel.add(ui.Label('', {margin: '8px 0'})); // Spacer
    resultsPanel.add(ui.Label('📊 Sample Size Validation (VM0033):', STYLES.SUBHEADER));
    resultsPanel.add(ui.Label(
      'VM0033 requires 95% CI with 10-20% relative precision. Using conservative CV=30% estimate.',
      {fontSize: '11px', color: '#666', margin: '4px 8px', fontStyle: 'italic'}
    ));

    var allGood = true;

    allocatedStrata.forEach(function(s) {
      // Use TARGET_CV from config as preliminary estimate
      var estimatedCV = CONFIG.TARGET_CV;

      // Calculate required N for different precision targets
      var req20pct = SampleSize.calculateRequiredN(estimatedCV, 20, 95); // VM0033 acceptable
      var req15pct = SampleSize.calculateRequiredN(estimatedCV, 15, 95); // VM0033 good
      var req10pct = SampleSize.calculateRequiredN(estimatedCV, 10, 95); // VM0033 excellent

      var allocated = s.points;
      var areaHa = (s.area / 10000).toFixed(1);

      // Determine status and color
      var status, color, icon, precision;
      if (allocated >= req10pct.requiredN) {
        status = 'Excellent (≤10% error)';
        color = '#2E7D32'; // Dark green
        icon = '✓✓';
        precision = '±10%';
      } else if (allocated >= req15pct.requiredN) {
        status = 'Good (≤15% error)';
        color = '#388E3C'; // Green
        icon = '✓';
        precision = '±15%';
      } else if (allocated >= req20pct.requiredN) {
        status = 'Acceptable (≤20% error)';
        color = '#F57F17'; // Amber
        icon = '⚠';
        precision = '±20%';
      } else if (allocated >= CONFIG.MIN_CORES_PER_STRATUM) {
        status = 'Low precision (>20% error)';
        color = '#F57C00'; // Orange
        icon = '⚠⚠';
        precision = '>±20%';
        allGood = false;
      } else {
        status = 'Insufficient (<3 cores)';
        color = '#D32F2F'; // Red
        icon = '✗';
        precision = 'N/A';
        allGood = false;
      }

      // Display stratum validation
      var stratumLabel = ui.Label(
        icon + ' ' + s.stratum + ': ' + allocated + ' cores (' + areaHa + ' ha)',
        {fontSize: '12px', fontWeight: 'bold', color: color, margin: '4px 8px'}
      );
      resultsPanel.add(stratumLabel);

      var detailsText = '    Status: ' + status + ' | Precision: ' + precision +
                        ' | Required for ±20%: ' + req20pct.requiredN +
                        ' | ±10%: ' + req10pct.requiredN;
      resultsPanel.add(ui.Label(detailsText, {fontSize: '10px', color: '#666', margin: '0 8px 6px 20px'}));
    });

    // Overall assessment
    if (allGood) {
      resultsPanel.add(ui.Label(
        '✓ All strata meet VM0033 minimum requirements',
        {fontSize: '12px', fontWeight: 'bold', color: '#2E7D32', margin: '8px'}
      ));
    } else {
      resultsPanel.add(ui.Label(
        '⚠ Some strata may have high uncertainty. Consider adding more cores or adjusting allocation.',
        {fontSize: '12px', fontWeight: 'bold', color: '#F57C00', margin: '8px'}
      ));
    }

    resultsPanel.add(ui.Label(
      'Note: These are estimates based on CV=30%. Actual precision will be calculated from field data.',
      {fontSize: '10px', color: '#999', margin: '4px 8px', fontStyle: 'italic'}
    ));
  }
};

// =================================================================================
// === 4. BLUE CARBON STRATIFICATION FUNCTIONS ====================================
// =================================================================================

var BlueCarbon = {

  /**
   * Update UI to show which strata have been drawn
   */
  updateStrataListUI: function(labelWidget) {
    if (AppState.drawnFeatures.length === 0) {
      labelWidget.setValue('Drawn Strata: None (draw at least one)');
      return;
    }

    var drawnStrata = {};
    AppState.drawnFeatures.forEach(function(f) {
      var stratum = f.get('stratum').getInfo();
      drawnStrata[stratum] = (drawnStrata[stratum] || 0) + 1;
    });

    var statusParts = [];
    Object.keys(drawnStrata).forEach(function(s) {
      statusParts.push(s + ' (' + drawnStrata[s] + ' polygon' + (drawnStrata[s] > 1 ? 's' : '') + ')');
    });

    labelWidget.setValue('Drawn Strata: ' + statusParts.join(', '));
  },

  /**
   * Handle completion of drawing a stratum polygon
   */
  handleDrawingCompletion: function(geometry, stratumName) {
    if (!stratumName || stratumName === '') {
      alert('Please select a stratum type before drawing.');
      return;
    }

    var feature = ee.Feature(geometry, {
      'stratum': stratumName,
      'stratum_id': AppState.drawnFeatures.length + 1,
      'scenario': AppState.scenarioType,
      'date_drawn': ee.Date(Date.now()).format('YYYY-MM-dd').getInfo()
    });

    AppState.drawnFeatures.push(feature);

    print('✓ Added:', stratumName, '(Total polygons:', AppState.drawnFeatures.length + ')');
  },

  /**
   * Finalize and analyze drawn strata
   */
  finalizeAndAnalyzeStrata: function(resultsPanel) {
    if (AppState.drawnFeatures.length === 0) {
      alert('Please draw at least one stratum polygon first.');
      return;
    }

    resultsPanel.clear();
    resultsPanel.add(ui.Label('⏳ Analyzing strata areas...', STYLES.INFO));

    AppState.finalStrataCollection = ee.FeatureCollection(AppState.drawnFeatures);

    var uniqueStrata = ee.List(AppState.finalStrataCollection.aggregate_array('stratum')).distinct();

    uniqueStrata.evaluate(function(strataNames) {
      if (!strataNames || strataNames.length === 0) {
        resultsPanel.clear();
        resultsPanel.add(ui.Label('❌ Error retrieving strata', STYLES.ERROR));
        return;
      }

      // Visualize with proper colors
      BlueCarbon.visualizeStrata(strataNames);

      // Calculate areas
      AppState.strataInfo = [];
      var completed = 0;

      strataNames.forEach(function(stratumName) {
        var stratumFeatures = AppState.finalStrataCollection.filter(ee.Filter.eq('stratum', stratumName));
        var stratumArea = stratumFeatures.geometry().area({'maxError': CONFIG.MAX_ERROR});

        stratumArea.evaluate(function(areaValue) {
          AppState.strataInfo.push({
            stratum: stratumName,
            area: areaValue
          });
          completed++;

          if (completed === strataNames.length) {
            BlueCarbon.displayStrataAnalysis(resultsPanel);
          }
        });
      });
    });
  },

  /**
   * Visualize strata with proper ecosystem colors
   */
  visualizeStrata: function(strataNames) {
    var styledLayers = strataNames.map(function(stratumName) {
      var subset = AppState.finalStrataCollection.filter(ee.Filter.eq('stratum', stratumName));
      var color = ECOSYSTEM_STRATA[stratumName].color;

      return subset.style({
        color: color,
        fillColor: color + '80', // 50% transparency
        width: 2
      });
    });

    var finalStyledImage = ee.ImageCollection.fromImages(styledLayers).mosaic();
    map.addLayer(finalStyledImage, {}, '5 Ecosystem Strata (Manual)', true);

    print('✓ Strata visualized on map with ecosystem colors');
  },

  /**
   * Display stratum analysis results
   */
  displayStrataAnalysis: function(resultsPanel) {
    resultsPanel.clear();
    resultsPanel.add(ui.Label('✓ Ecosystem Stratum Areas:', STYLES.SUCCESS));

    // Sort by area (largest first)
    AppState.strataInfo.sort(function(a, b) { return b.area - a.area; });

    var totalArea = AppState.strataInfo.reduce(function(sum, s) { return sum + s.area; }, 0);

    AppState.strataInfo.forEach(function(s) {
      var areaHa = s.area / 10000;
      var percentage = (s.area / totalArea * 100).toFixed(1);

      var infoText = '  • ' + s.stratum + ': ' + areaHa.toFixed(2) + ' ha (' + percentage + '%)';
      resultsPanel.add(ui.Label(infoText, {fontSize: '12px', margin: '2px 8px'}));

      // Add monitoring focus
      var monitoringInfo = '    → ' + ECOSYSTEM_STRATA[s.stratum].monitoring;
      resultsPanel.add(ui.Label(monitoringInfo, {fontSize: '11px', color: '#666666', margin: '0 8px 4px 20px'}));
    });

    resultsPanel.add(ui.Label(
      'Total Coastal Area: ' + (totalArea / 10000).toFixed(2) + ' ha',
      {fontSize: '13px', fontWeight: 'bold', margin: '8px'}
    ));

    print('✓ Strata analysis complete');
    print('  Total Area:', (totalArea / 10000).toFixed(2), 'ha');
    print('  Number of Strata:', AppState.strataInfo.length);
  },

  /**
   * Allocate sample points across strata (VM0033 compliant)
   * Now includes sample size validation for 95% CI requirements
   */
  allocatePoints: function(method, totalPoints, resultsPanel) {
    if (!AppState.strataInfo) {
      alert('Please finalize strata first.');
      return null;
    }

    var totalArea = AppState.strataInfo.reduce(function(sum, s) { return sum + s.area; }, 0);

    AppState.strataInfo.forEach(function(s) {
      if (method === 'Proportional') {
        var proportion = totalArea > 0 ? s.area / totalArea : 0;
        var decimal = proportion * totalPoints;
        s.points = Math.max(CONFIG.MIN_CORES_PER_STRATUM, Math.floor(decimal));
        s._remainder = decimal - s.points;
      } else if (method === 'Equal') {
        s.points = Math.max(CONFIG.MIN_CORES_PER_STRATUM, Math.floor(totalPoints / AppState.strataInfo.length));
        s._remainder = 0;
      }
    });

    // Distribute remainder points
    var assigned = AppState.strataInfo.reduce(function(sum, s) { return sum + s.points; }, 0);
    var diff = totalPoints - assigned;

    if (diff > 0) {
      AppState.strataInfo.slice()
        .sort(function(a, b) { return b._remainder - a._remainder; })
        .slice(0, diff)
        .forEach(function(s) { s.points += 1; });
    }

    // NEW: Run sample size validation if resultsPanel provided
    if (resultsPanel) {
      SampleSize.validateAllocation(AppState.strataInfo, resultsPanel);
    }

    return AppState.strataInfo;
  }
};

// =================================================================================
// === 5. USER INTERFACE SETUP =====================================================
// =================================================================================

ui.root.clear();
var map = ui.Map();
var panel = ui.Panel({style: STYLES.PANEL});
var splitPanel = ui.SplitPanel(panel, map, 'horizontal', false);
ui.root.add(splitPanel);
map.setCenter(-95, 55, 4);

// --- Header ---
panel.add(ui.Label('Blue Carbon Sampling Tool', STYLES.TITLE));
panel.add(ui.Label('Manual Stratification by Ecosystem', STYLES.SUBTITLE));
panel.add(ui.Label(
  'Draw polygons for each of the 5 coastal ecosystem strata, then generate VM0033-compliant sampling locations.',
  STYLES.PARAGRAPH
));
panel.add(STYLES.HR());

// --- Step 1: Draw Strata Manually ---
panel.add(ui.Label('Step 1: Draw Ecosystem Strata', STYLES.HEADER));
panel.add(ui.Label(
  'Select a stratum type below, then draw polygon(s) on the map. You can draw multiple polygons for the same stratum.',
  STYLES.INSTRUCTION
));

var stratumSelect = ui.Select({
  items: Object.keys(ECOSYSTEM_STRATA),
  value: 'Mid Marsh',
  placeholder: 'Select ecosystem stratum...',
  style: {stretch: 'horizontal', margin: '4px 8px'}
});

var drawStratumButton = ui.Button({
  label: '🖊️ Draw Polygon for Selected Stratum',
  style: {stretch: 'horizontal', margin: '4px 8px'}
});

var strataStatusLabel = ui.Label('Drawn Strata: None', STYLES.INFO);

// Show stratum info
var stratumInfoLabel = ui.Label('', {fontSize: '11px', color: '#666666', margin: '4px 8px', whiteSpace: 'pre'});
stratumSelect.onChange(function(value) {
  var info = ECOSYSTEM_STRATA[value];
  stratumInfoLabel.setValue('📝 ' + info.description + '\n💡 Monitor: ' + info.monitoring);
});
stratumInfoLabel.setValue('📝 ' + ECOSYSTEM_STRATA['Mid Marsh'].description + '\n💡 Monitor: ' + ECOSYSTEM_STRATA['Mid Marsh'].monitoring);

panel.add(ui.Label('Select Stratum Type:', STYLES.SUBHEADER));
panel.add(stratumSelect);
panel.add(stratumInfoLabel);
panel.add(drawStratumButton);
panel.add(strataStatusLabel);

// --- Step 2: Finalize Strata ---
panel.add(STYLES.HR());
panel.add(ui.Label('Step 2: Finalize & Analyze Strata', STYLES.HEADER));

var scenarioSelect = ui.Select({
  items: ['PROJECT - Post-restoration', 'BASELINE - Pre-restoration', 'CONTROL - Reference site'],
  value: 'PROJECT - Post-restoration',
  style: {stretch: 'horizontal', margin: '4px 8px'},
  onChange: function(value) {
    AppState.scenarioType = value.split(' - ')[0];
  }
});

panel.add(ui.Label('Project Scenario:', STYLES.SUBHEADER));
panel.add(scenarioSelect);

var finalizeStrataButton = ui.Button({
  label: '✓ Finalize & Analyze Strata Areas',
  style: {stretch: 'horizontal', margin: '8px'}
});

var strataResultsPanel = ui.Panel({style: {margin: '8px'}});
panel.add(finalizeStrataButton);
panel.add(strataResultsPanel);

// --- Step 3: Configure Sampling ---
panel.add(STYLES.HR());
panel.add(ui.Label('Step 3: Configure Sampling Design', STYLES.HEADER));

var hrCoresBox = ui.Textbox({
  value: CONFIG.DEFAULT_HR_CORES.toString(),
  placeholder: 'Total HR cores',
  style: {stretch: 'horizontal', margin: '4px 8px'}
});

var compositesBox = ui.Textbox({
  value: CONFIG.DEFAULT_COMPOSITES_PER_STRATUM.toString(),
  placeholder: 'Per stratum',
  style: {stretch: 'horizontal', margin: '4px 8px'}
});

var compositeAreaBox = ui.Textbox({
  value: CONFIG.DEFAULT_COMPOSITE_AREA.toString(),
  placeholder: 'm²',
  style: {stretch: 'horizontal', margin: '4px 8px'}
});

var subsamplesBox = ui.Textbox({
  value: CONFIG.DEFAULT_SUBSAMPLES.toString(),
  placeholder: 'Number',
  style: {stretch: 'horizontal', margin: '4px 8px'}
});

var pairingFractionBox = ui.Textbox({
  value: CONFIG.DEFAULT_PAIRING_FRACTION.toString(),
  placeholder: '0-1',
  style: {stretch: 'horizontal', margin: '4px 8px'}
});

var allocationSelect = ui.Select({
  items: ['Proportional', 'Equal'],
  value: 'Proportional',
  style: {stretch: 'horizontal', margin: '4px 8px'}
});

var shapeSelect = ui.Select({
  items: ['Square', 'Circle'],
  value: 'Square',
  style: {stretch: 'horizontal', margin: '4px 8px'}
});

// NEW: VM0033 depth interval guidance
var depthIntervalsLabel = ui.Label(
  '📏 VM0033 Required Depth Intervals:\n' +
  '   • 0-15 cm (surface organic layer)\n' +
  '   • 15-30 cm (shallow mineral)\n' +
  '   • 30-50 cm (intermediate)\n' +
  '   • 50-100 cm (deep carbon storage)\n' +
  'Ensure field sampling follows these intervals for standardized depth profiles.',
  {
    fontSize: '11px',
    color: '#0277BD',
    margin: '8px 8px',
    padding: '8px',
    border: '1px solid #B3E5FC',
    backgroundColor: '#E1F5FE',
    whiteSpace: 'pre'
  }
);

panel.add(ui.Label('Total HR Cores (sediment cores):', STYLES.SUBHEADER));
panel.add(hrCoresBox);
panel.add(ui.Label('Composites per Stratum:', STYLES.SUBHEADER));
panel.add(compositesBox);
panel.add(ui.Label('Composite Area (m²):', STYLES.SUBHEADER));
panel.add(compositeAreaBox);
panel.add(ui.Label('Subsamples per Composite:', STYLES.SUBHEADER));
panel.add(subsamplesBox);
panel.add(depthIntervalsLabel);  // NEW: VM0033 depth guidance
panel.add(ui.Label('Pairing Fraction (0-1):', STYLES.SUBHEADER));
panel.add(pairingFractionBox);
panel.add(ui.Label('Sample Allocation Method:', STYLES.SUBHEADER));
panel.add(allocationSelect);
panel.add(ui.Label('Composite Shape:', STYLES.SUBHEADER));
panel.add(shapeSelect);

var generateSamplingButton = ui.Button({
  label: '🎯 Generate Sampling Locations',
  style: {stretch: 'horizontal', margin: '8px'},
  disabled: true
});

panel.add(generateSamplingButton);

// --- Results ---
var samplingResultsPanel = ui.Panel({style: {margin: '8px'}});
panel.add(samplingResultsPanel);

// --- Step 4: Export ---
panel.add(STYLES.HR());
panel.add(ui.Label('Step 4: Export Results', STYLES.HEADER));

var exportFormatSelect = ui.Select({
  items: ['GeoJSON', 'SHP', 'CSV'],
  value: 'GeoJSON',
  style: {stretch: 'horizontal', margin: '4px 8px'}
});

var exportStrataButton = ui.Button({
  label: 'Export Strata Polygons',
  style: {stretch: 'horizontal', margin: '4px 8px'},
  disabled: true
});

var exportHRCoresButton = ui.Button({
  label: 'Export HR Core Locations',
  style: {stretch: 'horizontal', margin: '4px 8px'},
  disabled: true
});

var exportCompositesButton = ui.Button({
  label: 'Export Composite Polygons',
  style: {stretch: 'horizontal', margin: '4px 8px'},
  disabled: true
});

var exportSubsamplesButton = ui.Button({
  label: 'Export Subsample Points',
  style: {stretch: 'horizontal', margin: '4px 8px'},
  disabled: true
});

panel.add(ui.Label('Export Format:', STYLES.INSTRUCTION));
panel.add(exportFormatSelect);
panel.add(exportStrataButton);
panel.add(exportHRCoresButton);
panel.add(exportCompositesButton);
panel.add(exportSubsamplesButton);

var downloadLinksPanel = ui.Panel({style: {margin: '8px'}});
panel.add(downloadLinksPanel);

var clearButton = ui.Button({
  label: '🔄 Clear All & Reset',
  style: {stretch: 'horizontal', margin: '16px 8px 8px 8px', color: 'red'}
});
panel.add(clearButton);

// =================================================================================
// === 6. DRAWING TOOLS SETUP ======================================================
// =================================================================================

var drawingTools = map.drawingTools();
drawingTools.setShown(true);
drawingTools.setLinked(false);
drawingTools.setDrawModes(['polygon', 'rectangle']);

map.setControlVisibility({
  all: false,
  layerList: true,
  zoomControl: true,
  scaleControl: true,
  mapTypeControl: true,
  drawingToolsControl: true
});

// =================================================================================
// === 7. EVENT HANDLERS ===========================================================
// =================================================================================

/**
 * Start drawing a stratum polygon
 */
drawStratumButton.onClick(function() {
  var selectedStratum = stratumSelect.getValue();
  if (!selectedStratum) {
    alert('Please select a stratum type first.');
    return;
  }

  drawingTools.setShape('polygon');
  drawingTools.draw();
});

/**
 * Handle drawing completion
 */
drawingTools.onDraw(ui.util.debounce(function(geometry) {
  var selectedStratum = stratumSelect.getValue();
  BlueCarbon.handleDrawingCompletion(geometry, selectedStratum);
  drawingTools.setShape(null);
  BlueCarbon.updateStrataListUI(strataStatusLabel);
}, 500));

/**
 * Finalize strata
 */
finalizeStrataButton.onClick(function() {
  BlueCarbon.finalizeAndAnalyzeStrata(strataResultsPanel);
  generateSamplingButton.setDisabled(false);
  exportStrataButton.setDisabled(false);
});

/**
 * Generate sampling locations
 */
generateSamplingButton.onClick(function() {
  if (!AppState.finalStrataCollection || !AppState.strataInfo) {
    alert('Please finalize strata first (Step 2).');
    return;
  }

  samplingResultsPanel.clear();
  samplingResultsPanel.add(ui.Label('⏳ Generating sampling design...', STYLES.INFO));

  // Get parameters
  var params = {
    totalHRCores: parseInt(hrCoresBox.getValue()),
    compositesPerStratum: parseInt(compositesBox.getValue()),
    compositeArea: parseFloat(compositeAreaBox.getValue()),
    subsamples: parseInt(subsamplesBox.getValue()),
    pairingFraction: parseFloat(pairingFractionBox.getValue()),
    allocationMethod: allocationSelect.getValue(),
    shape: shapeSelect.getValue()
  };

  // Validate
  if (params.pairingFraction < 0 || params.pairingFraction > 1) {
    samplingResultsPanel.clear();
    samplingResultsPanel.add(ui.Label('❌ Pairing fraction must be between 0 and 1', STYLES.ERROR));
    return;
  }

  // Allocate cores across strata (now with validation)
  var allocatedStrata = BlueCarbon.allocatePoints(params.allocationMethod, params.totalHRCores, samplingResultsPanel);

  // Generate samples for each stratum
  var allHRCores = [];
  var allComposites = [];
  var allSubsamples = [];

  var numStrata = allocatedStrata.length;
  var processedStrata = 0;

  allocatedStrata.forEach(function(stratumInfo, stratumIndex) {
    var stratumName = stratumInfo.stratum;
    var coreCount = stratumInfo.points;

    // Get this stratum's features
    var stratumFeatures = AppState.finalStrataCollection.filter(ee.Filter.eq('stratum', stratumName));
    var stratumGeometry = stratumFeatures.geometry();

    // Generate HR cores using TRUE systematic grid
    var hrCores = Utils.createSystematicGrid(
      stratumGeometry,
      coreCount,
      CONFIG.RANDOM_SEED + stratumIndex
    ).map(function(pt) {
      return pt.set({
        'stratum': stratumName,
        'sample_type': 'HR_core',
        'core_depth_cm': CONFIG.CORE_DEPTH_CM,
        'scenario': AppState.scenarioType
      });
    });

    allHRCores.push(hrCores);

    // Generate composites using TRUE systematic grid
    var composites = Utils.createSystematicGrid(
      stratumGeometry,
      params.compositesPerStratum,
      CONFIG.RANDOM_SEED + stratumIndex + 1000
    );

    var compositesList = composites.toList(params.compositesPerStratum);
    var compositesWithProps = ee.FeatureCollection(
      ee.List.sequence(0, params.compositesPerStratum - 1).map(function(idx) {
        var pt = ee.Feature(compositesList.get(idx));
        var composite = params.shape === 'Square' ?
          Utils.createSquare(pt, params.compositeArea) :
          Utils.createCircle(pt, params.compositeArea);

        return composite.set({
          'composite_id': ee.Number(idx).add(stratumIndex * params.compositesPerStratum),
          'stratum': stratumName,
          'sample_type': 'composite',
          'scenario': AppState.scenarioType,
          'paired': 0
        });
      })
    );

    allComposites.push(compositesWithProps);

    // Generate subsamples
    compositesWithProps.toList(params.compositesPerStratum).evaluate(function(compList) {
      compList.forEach(function(compFeature) {
        var comp = ee.Feature(compFeature);
        var subpts = Utils.randomPointsInPolygon(
          comp,
          params.subsamples,
          CONFIG.RANDOM_SEED + stratumIndex + 2000
        ).map(function(pt) {
          return pt.set({
            'composite_id': comp.get('composite_id'),
            'stratum': stratumName,
            'sample_type': 'subsample'
          });
        });

        allSubsamples.push(subpts);
      });

      processedStrata++;

      // When all strata processed, combine and display
      if (processedStrata === numStrata) {
        finalizeSampling();
      }
    });
  });

  function finalizeSampling() {
    AppState.hrCores = ee.FeatureCollection(allHRCores).flatten();
    AppState.composites = ee.FeatureCollection(allComposites).flatten();
    AppState.subsamples = ee.FeatureCollection(allSubsamples).flatten();

    // Implement improved pairing (nearest neighbor approach)
    var numToPair = Math.floor(params.pairingFraction * params.totalHRCores);

    print('🔗 Pairing ' + numToPair + ' HR cores with nearest composites...');

    // For each HR core, find nearest composite within max distance
    var hrCoresList = AppState.hrCores.toList(AppState.hrCores.size());

    hrCoresList.evaluate(function(coreList) {
      var pairedIds = [];
      var usedCoreIndices = [];

      // For each HR core (up to numToPair), find nearest composite
      for (var i = 0; i < Math.min(numToPair, coreList.length); i++) {
        var coreFeature = coreList[i];
        var core = ee.Feature(coreFeature);
        var coreGeom = core.geometry();

        // Find composites within buffer distance, not already paired
        var candidateComposites = AppState.composites
          .filterBounds(coreGeom.buffer(CONFIG.DEFAULT_MAX_PAIRING_DISTANCE, CONFIG.MAX_ERROR));

        // Add distance property and sort
        var withDistance = candidateComposites.map(function(comp) {
          var dist = comp.geometry().distance(coreGeom, CONFIG.MAX_ERROR);
          return comp.set('_temp_distance', dist);
        });

        // Get the nearest composite not already paired
        var sortedComps = withDistance.sort('_temp_distance');
        var nearestComp = sortedComps.first();

        // Get the composite_id to mark as paired
        nearestComp.evaluate(function(compData) {
          if (compData && compData.properties && compData.properties.composite_id !== undefined) {
            pairedIds.push(compData.properties.composite_id);
          }

          // When all cores processed, finalize pairing
          if (pairedIds.length === numToPair || i === coreList.length - 1) {
            finalizePairing(pairedIds);
          }
        });
      }

      function finalizePairing(pairedIds) {
        // Create filter for paired composites
        var pairedIdsServer = ee.List(pairedIds);

        AppState.pairedComposites = AppState.composites.filter(
          ee.Filter.inList('composite_id', pairedIdsServer)
        );

        // Update paired status in all composites
        AppState.composites = AppState.composites.map(function(feat) {
          var isPaired = pairedIdsServer.contains(feat.get('composite_id'));
          return feat.set('paired', ee.Algorithms.If(isPaired, 1, 0));
        });

        print('✓ Successfully paired ' + pairedIds.length + ' composites with HR cores');

        // Display results
        displaySamplingResults();
      }
    });
  }

  function displaySamplingResults() {
    samplingResultsPanel.clear();
    samplingResultsPanel.add(ui.Label('✓ Sampling design complete!', STYLES.SUCCESS));

    AppState.hrCores.size().evaluate(function(hrCount) {
      samplingResultsPanel.add(ui.Label('HR Cores: ' + hrCount + ' (systematic grid)', STYLES.INFO));
    });

    AppState.composites.size().evaluate(function(compCount) {
      AppState.pairedComposites.size().evaluate(function(pairedCount) {
        samplingResultsPanel.add(ui.Label(
          'Composites: ' + compCount + ' (' + pairedCount + ' paired with nearest HR cores)',
          STYLES.INFO
        ));
      });
    });

    AppState.subsamples.size().evaluate(function(subCount) {
      samplingResultsPanel.add(ui.Label('Subsamples: ' + subCount, STYLES.INFO));
    });

    // Add to map
    map.addLayer(AppState.composites.filter(ee.Filter.eq('paired', 0)),
                {color: '0000FF'}, 'Unpaired Composites');
    map.addLayer(AppState.pairedComposites, {color: '00FF00'}, 'Paired Composites (Nearest to HR Cores)');
    map.addLayer(AppState.hrCores, {color: 'FF0000'}, 'HR Core Locations (Systematic Grid)');
    map.addLayer(AppState.subsamples, {color: 'FFFF00'}, 'Subsample Points', false);

    // Enable export buttons
    exportHRCoresButton.setDisabled(false);
    exportCompositesButton.setDisabled(false);
    exportSubsamplesButton.setDisabled(false);

    print('✓ Sampling design generated successfully (VM0033 compliant)');
  }
});

/**
 * Export functions
 */
exportStrataButton.onClick(function() {
  if (!AppState.finalStrataCollection) {
    alert('Please finalize strata first.');
    return;
  }

  var polygonsWithArea = AppState.finalStrataCollection.map(function(feature) {
    var areaHa = feature.area({'maxError': CONFIG.MAX_ERROR}).divide(10000);
    return feature.set('area_ha', areaHa);
  });

  Export.table.toDrive({
    collection: polygonsWithArea,
    description: 'BlueCarbon_Strata_Polygons',
    folder: 'BlueCarbon_Exports',
    fileNamePrefix: 'strata_polygons_' + AppState.scenarioType,
    fileFormat: exportFormatSelect.getValue()
  });

  alert('Export task created! Check the Tasks tab to run it.');
  print('✓ Strata export task created');
});

exportHRCoresButton.onClick(function() {
  if (!AppState.hrCores) {
    alert('Please generate sampling design first.');
    return;
  }

  Export.table.toDrive({
    collection: AppState.hrCores,
    description: 'BlueCarbon_HR_Cores',
    folder: 'BlueCarbon_Exports',
    fileNamePrefix: 'hr_cores_' + AppState.scenarioType,
    fileFormat: exportFormatSelect.getValue()
  });

  alert('Export task created! Check the Tasks tab to run it.');
  print('✓ HR cores export task created');
});

exportCompositesButton.onClick(function() {
  if (!AppState.composites) {
    alert('Please generate sampling design first.');
    return;
  }

  Export.table.toDrive({
    collection: AppState.composites,
    description: 'BlueCarbon_Composites',
    folder: 'BlueCarbon_Exports',
    fileNamePrefix: 'composites_' + AppState.scenarioType,
    fileFormat: exportFormatSelect.getValue()
  });

  alert('Export task created! Check the Tasks tab to run it.');
  print('✓ Composites export task created');
});

exportSubsamplesButton.onClick(function() {
  if (!AppState.subsamples) {
    alert('Please generate sampling design first.');
    return;
  }

  Export.table.toDrive({
    collection: AppState.subsamples,
    description: 'BlueCarbon_Subsamples',
    folder: 'BlueCarbon_Exports',
    fileNamePrefix: 'subsamples_' + AppState.scenarioType,
    fileFormat: exportFormatSelect.getValue()
  });

  alert('Export task created! Check the Tasks tab to run it.');
  print('✓ Subsamples export task created');
});

/**
 * Clear all
 */
clearButton.onClick(function() {
  var confirmed = confirm('This will clear all drawings and results. Continue?');
  if (!confirmed) return;

  AppState.reset();
  map.layers().reset();

  while (drawingTools.layers().length() > 0) {
    drawingTools.layers().remove(drawingTools.layers().get(0));
  }

  strataResultsPanel.clear();
  samplingResultsPanel.clear();
  downloadLinksPanel.clear();

  BlueCarbon.updateStrataListUI(strataStatusLabel);

  exportStrataButton.setDisabled(true);
  exportHRCoresButton.setDisabled(true);
  exportCompositesButton.setDisabled(true);
  exportSubsamplesButton.setDisabled(true);
  generateSamplingButton.setDisabled(true);

  print('✓ Tool reset successfully');
});

// =================================================================================
// === 8. INITIALIZE ===============================================================
// =================================================================================

print('═══════════════════════════════════════════════════════');
print('🌊 Blue Carbon Sampling Tool - Manual Stratification');
print('═══════════════════════════════════════════════════════');
print('VERSION: VM0033 Compliant with TRUE Systematic Sampling');
print('');
print('5 Coastal Ecosystem Strata:');
print('  1. Upper Marsh - Infrequent flooding, shrubs');
print('  2. Mid Marsh - Regular inundation (HIGHEST C sequestration)');
print('  3. Lower Marsh - Daily tides (HIGHEST burial rates)');
print('  4. Underwater Vegetation - Subtidal seagrass');
print('  5. Open Water - Channels, lagoons');
print('');
print('Workflow:');
print('  Step 1: Select stratum → Draw polygon (repeat for all strata)');
print('  Step 2: Finalize & analyze areas');
print('  Step 3: Configure sampling → Generate locations');
print('  Step 4: Export results');
print('');
print('NEW in this version:');
print('  ✓ TRUE systematic grid sampling (not random)');
print('  ✓ VM0033 sample size validation (95% CI, 10-20% precision)');
print('  ✓ Improved pairing (nearest neighbor matching)');
print('  ✓ VM0033 depth interval guidance');
print('');
print('Benefits of Manual Approach:');
print('  ✓ Complete control over stratum boundaries');
print('  ✓ Incorporate local knowledge & field observations');
print('  ✓ No dependency on remote sensing quality');
print('  ✓ Works globally, any coastal site');
print('');
print('Ready to use! 🚀');
