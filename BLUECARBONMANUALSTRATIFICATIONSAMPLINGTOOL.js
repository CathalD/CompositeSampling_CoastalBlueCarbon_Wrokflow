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
   * Create systematic grid of points
   */
  createSystematicGrid: function(region, count, seed) {
    return ee.FeatureCollection.randomPoints({
      region: region,
      points: count,
      seed: seed
    });
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
   */
  allocatePoints: function(method, totalPoints) {
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

panel.add(ui.Label('Total HR Cores (sediment cores):', STYLES.SUBHEADER));
panel.add(hrCoresBox);
panel.add(ui.Label('Composites per Stratum:', STYLES.SUBHEADER));
panel.add(compositesBox);
panel.add(ui.Label('Composite Area (m²):', STYLES.SUBHEADER));
panel.add(compositeAreaBox);
panel.add(ui.Label('Subsamples per Composite:', STYLES.SUBHEADER));
panel.add(subsamplesBox);
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
  
  // Allocate cores across strata
  var allocatedStrata = BlueCarbon.allocatePoints(params.allocationMethod, params.totalHRCores);
  
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
    
    // Generate HR cores
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
    
    // Generate composites
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
    
    // Implement pairing
    var numToPair = Math.floor(AppState.composites.size().getInfo() * params.pairingFraction);
    AppState.pairedComposites = AppState.composites.filterBounds(
      AppState.hrCores.geometry().buffer(CONFIG.DEFAULT_MAX_PAIRING_DISTANCE, CONFIG.MAX_ERROR)
    ).limit(numToPair);
    
    // Update paired status
    var pairedIds = AppState.pairedComposites.aggregate_array('composite_id');
    AppState.composites = AppState.composites.map(function(feat) {
      var isPaired = pairedIds.contains(feat.get('composite_id'));
      return feat.set('paired', ee.Algorithms.If(isPaired, 1, 0));
    });
    
    // Display results
    samplingResultsPanel.clear();
    samplingResultsPanel.add(ui.Label('✓ Sampling design complete!', STYLES.SUCCESS));
    
    AppState.hrCores.size().evaluate(function(hrCount) {
      samplingResultsPanel.add(ui.Label('HR Cores: ' + hrCount, STYLES.INFO));
    });
    
    AppState.composites.size().evaluate(function(compCount) {
      AppState.pairedComposites.size().evaluate(function(pairedCount) {
        samplingResultsPanel.add(ui.Label(
          'Composites: ' + compCount + ' (' + pairedCount + ' paired)',
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
    map.addLayer(AppState.pairedComposites, {color: '00FF00'}, 'Paired Composites');
    map.addLayer(AppState.hrCores, {color: 'FF0000'}, 'HR Core Locations');
    map.addLayer(AppState.subsamples, {color: 'FFFF00'}, 'Subsample Points', false);
    
    // Enable export buttons
    exportHRCoresButton.setDisabled(false);
    exportCompositesButton.setDisabled(false);
    exportSubsamplesButton.setDisabled(false);
    
    print('✓ Sampling design generated successfully');
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
print('Benefits of Manual Approach:');
print('  ✓ Complete control over stratum boundaries');
print('  ✓ Incorporate local knowledge & field observations');
print('  ✓ No dependency on remote sensing quality');
print('  ✓ Works globally, any coastal site');
print('');
print('Ready to use! 🚀');
