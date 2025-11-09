/// Performance benchmark harness for WireTuner rendering pipeline.
///
/// This benchmark measures rendering performance across varying document
/// complexities and zoom levels. It captures FPS, frame time, memory usage,
/// and cache statistics.
///
/// Usage:
///   flutter test dev/benchmarks/render_bench.dart --dart-define=DATASET=medium
///
/// Options (via --dart-define):
///   DATASET=[small|medium|large|xlarge]  Dataset size (default: medium)
///   ITERATIONS=<count>                    Number of iterations (default: 30)
///   OUTPUT=<path>                         Output file path (default: results)
///   FORMAT=[json|csv|both]                Output format (default: json)
///
/// Examples:
///   flutter test dev/benchmarks/render_bench.dart
///   flutter test dev/benchmarks/render_bench.dart --dart-define=DATASET=large --dart-define=ITERATIONS=60
///   flutter test dev/benchmarks/render_bench.dart --dart-define=FORMAT=both --dart-define=OUTPUT=bench
///
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/models/anchor_point.dart';
import 'package:wiretuner/domain/models/path.dart' as domain;
import 'package:wiretuner/domain/models/segment.dart';
import 'package:wiretuner/domain/models/shape.dart';
import 'package:wiretuner/presentation/canvas/paint_styles.dart';
import 'package:wiretuner/presentation/canvas/painter/path_renderer.dart';
import 'package:wiretuner/presentation/canvas/render_pipeline.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';

void main() {
  // Parse configuration from dart-define
  final config = BenchmarkConfig.fromEnvironment();

  test('WireTuner Rendering Benchmark', () async {
    print('WireTuner Rendering Benchmark');
    print('=============================\n');
    print('Configuration:');
    print('  Dataset: ${config.datasetName}');
    print('  Object count: ${config.objectCount}');
    print('  Iterations: ${config.iterations}');
    print('  Output format: ${config.format}');
    print('  Output path: ${config.outputPath}\n');

    // Run benchmarks
    final runner = BenchmarkRunner(config: config);
    final results = await runner.runAll();

    // Export results
    final exporter = ResultsExporter(config: config);
    await exporter.export(results);

    // Print summary
    _printSummary(results);

    print('\nBenchmark complete!');
    print('Results written to: ${config.outputPath}');
  });
}

/// Benchmark configuration parsed from dart-define environment variables.
class BenchmarkConfig {
  BenchmarkConfig({
    required this.datasetName,
    required this.objectCount,
    required this.iterations,
    required this.format,
    required this.outputPath,
  });

  factory BenchmarkConfig.fromEnvironment() {
    const datasetName = String.fromEnvironment('DATASET', defaultValue: 'medium');
    const iterations = int.fromEnvironment('ITERATIONS', defaultValue: 30);
    const format = String.fromEnvironment('FORMAT', defaultValue: 'json');
    const outputPath = String.fromEnvironment('OUTPUT', defaultValue: 'dev/benchmarks/results');

    final objectCount = _getObjectCount(datasetName);

    return BenchmarkConfig(
      datasetName: datasetName,
      objectCount: objectCount,
      iterations: iterations,
      format: format,
      outputPath: outputPath,
    );
  }

  final String datasetName;
  final int objectCount;
  final int iterations;
  final String format;
  final String outputPath;

  static int _getObjectCount(String datasetName) {
    switch (datasetName.toLowerCase()) {
      case 'small':
        return 100;
      case 'medium':
        return 500;
      case 'large':
        return 1000;
      case 'xlarge':
        return 2500;
      default:
        print('Warning: Unknown dataset "$datasetName", using medium (500)');
        return 500;
    }
  }
}

/// Generates synthetic documents for benchmarking.
class SyntheticDocumentGenerator {
  SyntheticDocumentGenerator({required this.seed});

  final int seed;
  late final math.Random _random = math.Random(seed);

  /// Generates a list of random paths for performance testing.
  List<domain.Path> generateRandomPaths(int count) {
    final paths = <domain.Path>[];

    for (var i = 0; i < count; i++) {
      // Generate 3-8 anchors per path
      final anchorCount = 3 + _random.nextInt(6);
      final anchors = <AnchorPoint>[];

      for (var j = 0; j < anchorCount; j++) {
        final x = _random.nextDouble() * 2000;
        final y = _random.nextDouble() * 2000;

        // 30% chance of Bezier curve
        if (_random.nextDouble() < 0.3) {
          anchors.add(
            AnchorPoint(
              position: Point(x: x, y: y),
              handleOut: Point(
                x: (_random.nextDouble() - 0.5) * 50,
                y: (_random.nextDouble() - 0.5) * 50,
              ),
              handleIn: Point(
                x: (_random.nextDouble() - 0.5) * 50,
                y: (_random.nextDouble() - 0.5) * 50,
              ),
            ),
          );
        } else {
          anchors.add(AnchorPoint.corner(Point(x: x, y: y)));
        }
      }

      // Create segments connecting anchors
      final segments = <Segment>[];
      for (var j = 0; j < anchorCount - 1; j++) {
        final isBezier =
            anchors[j].handleOut != null || anchors[j + 1].handleIn != null;
        segments.add(
          isBezier
              ? Segment.bezier(startIndex: j, endIndex: j + 1)
              : Segment.line(startIndex: j, endIndex: j + 1),
        );
      }

      paths.add(
        domain.Path(
          anchors: anchors,
          segments: segments,
          closed: _random.nextBool(),
        ),
      );
    }

    return paths;
  }

  /// Generates a mix of random shapes for performance testing.
  List<Shape> generateRandomShapes(int count) {
    final shapes = <Shape>[];

    for (var i = 0; i < count; i++) {
      final x = _random.nextDouble() * 2000;
      final y = _random.nextDouble() * 2000;
      final center = Point(x: x, y: y);

      final shapeType = _random.nextInt(4);

      switch (shapeType) {
        case 0: // Rectangle
          shapes.add(
            Shape.rectangle(
              center: center,
              width: 20 + _random.nextDouble() * 80,
              height: 20 + _random.nextDouble() * 80,
              cornerRadius: _random.nextDouble() * 10,
            ),
          );
          break;
        case 1: // Ellipse
          shapes.add(
            Shape.ellipse(
              center: center,
              width: 20 + _random.nextDouble() * 80,
              height: 20 + _random.nextDouble() * 80,
            ),
          );
          break;
        case 2: // Polygon
          shapes.add(
            Shape.polygon(
              center: center,
              radius: 20 + _random.nextDouble() * 50,
              sides: 3 + _random.nextInt(8),
            ),
          );
          break;
        case 3: // Star
          final outerRadius = 20 + _random.nextDouble() * 50;
          shapes.add(
            Shape.star(
              center: center,
              outerRadius: outerRadius,
              innerRadius: outerRadius * (0.3 + _random.nextDouble() * 0.4),
              pointCount: 3 + _random.nextInt(8),
            ),
          );
          break;
      }
    }

    return shapes;
  }
}

/// A single benchmark scenario configuration.
class BenchmarkScenario {
  BenchmarkScenario({
    required this.name,
    required this.objectCount,
    required this.pathCount,
    required this.shapeCount,
    required this.zoomLevel,
    required this.enableCulling,
    required this.enableCaching,
  });

  final String name;
  final int objectCount;
  final int pathCount;
  final int shapeCount;
  final double zoomLevel;
  final bool enableCulling;
  final bool enableCaching;

  Map<String, dynamic> toJson() => {
        'name': name,
        'objectCount': objectCount,
        'pathCount': pathCount,
        'shapeCount': shapeCount,
        'zoomLevel': zoomLevel,
        'enableCulling': enableCulling,
        'enableCaching': enableCaching,
      };
}

/// Results from a single benchmark run.
class BenchmarkResult {
  BenchmarkResult({
    required this.scenario,
    required this.frameTimeMs,
    required this.fps,
    required this.objectsRendered,
    required this.objectsCulled,
    required this.cacheSize,
    required this.memoryUsedMB,
  });

  final BenchmarkScenario scenario;
  final double frameTimeMs;
  final double fps;
  final int objectsRendered;
  final int objectsCulled;
  final int cacheSize;
  final double memoryUsedMB;

  Map<String, dynamic> toJson() => {
        'scenario': scenario.toJson(),
        'frameTimeMs': frameTimeMs,
        'fps': fps,
        'objectsRendered': objectsRendered,
        'objectsCulled': objectsCulled,
        'cacheSize': cacheSize,
        'memoryUsedMB': memoryUsedMB,
      };
}

/// Benchmark runner that executes all scenarios.
class BenchmarkRunner {
  BenchmarkRunner({required this.config});

  final BenchmarkConfig config;

  Future<List<BenchmarkResult>> runAll() async {
    final results = <BenchmarkResult>[];

    // Generate synthetic document once
    print('Generating synthetic document...');
    final generator = SyntheticDocumentGenerator(seed: 42);
    final pathCount = (config.objectCount * 0.7).round();
    final shapeCount = config.objectCount - pathCount;
    final paths = generator.generateRandomPaths(pathCount);
    final shapes = generator.generateRandomShapes(shapeCount);

    print('  Paths: $pathCount');
    print('  Shapes: $shapeCount\n');

    // Define benchmark scenarios
    final scenarios = _createScenarios(config.objectCount, pathCount, shapeCount);

    for (final scenario in scenarios) {
      print('Running: ${scenario.name}...');
      final result = await _runScenario(scenario, paths, shapes);
      results.add(result);
      _printScenarioResult(result);
    }

    return results;
  }

  List<BenchmarkScenario> _createScenarios(
    int totalCount,
    int pathCount,
    int shapeCount,
  ) {
    return [
      // Baseline: Normal zoom, no optimizations
      BenchmarkScenario(
        name: 'Baseline (zoom 1.0, no opts)',
        objectCount: totalCount,
        pathCount: pathCount,
        shapeCount: shapeCount,
        zoomLevel: 1.0,
        enableCulling: false,
        enableCaching: false,
      ),
      // With caching enabled
      BenchmarkScenario(
        name: 'With caching (zoom 1.0)',
        objectCount: totalCount,
        pathCount: pathCount,
        shapeCount: shapeCount,
        zoomLevel: 1.0,
        enableCulling: false,
        enableCaching: true,
      ),
      // With culling enabled
      BenchmarkScenario(
        name: 'With culling (zoom 1.0)',
        objectCount: totalCount,
        pathCount: pathCount,
        shapeCount: shapeCount,
        zoomLevel: 1.0,
        enableCulling: true,
        enableCaching: false,
      ),
      // All optimizations enabled
      BenchmarkScenario(
        name: 'All optimizations (zoom 1.0)',
        objectCount: totalCount,
        pathCount: pathCount,
        shapeCount: shapeCount,
        zoomLevel: 1.0,
        enableCulling: true,
        enableCaching: true,
      ),
      // Zoomed out (LOD stress test)
      BenchmarkScenario(
        name: 'Zoomed out (zoom 0.1, all opts)',
        objectCount: totalCount,
        pathCount: pathCount,
        shapeCount: shapeCount,
        zoomLevel: 0.1,
        enableCulling: true,
        enableCaching: true,
      ),
      // Zoomed in
      BenchmarkScenario(
        name: 'Zoomed in (zoom 2.0, all opts)',
        objectCount: totalCount,
        pathCount: pathCount,
        shapeCount: shapeCount,
        zoomLevel: 2.0,
        enableCulling: true,
        enableCaching: true,
      ),
    ];
  }

  Future<BenchmarkResult> _runScenario(
    BenchmarkScenario scenario,
    List<domain.Path> paths,
    List<Shape> shapes,
  ) async {
    // Setup rendering infrastructure
    final pathRenderer = PathRenderer();
    final viewportController = ViewportController(initialZoom: scenario.zoomLevel);
    final pipeline = RenderPipeline(
      pathRenderer: pathRenderer,
      config: RenderPipelineConfig(
        enablePathCaching: scenario.enableCaching,
        enableViewportCulling: scenario.enableCulling,
      ),
    );

    // Convert to renderable objects
    final renderablePaths = paths
        .asMap()
        .entries
        .map(
          (e) => RenderablePath(
            id: 'path-${e.key}',
            path: e.value,
            style: const PaintStyle.stroke(color: Colors.black, strokeWidth: 1),
          ),
        )
        .toList();

    final renderableShapes = shapes
        .asMap()
        .entries
        .map(
          (e) => RenderableShape(
            id: 'shape-${e.key}',
            shape: e.value,
            style: const PaintStyle.fill(color: Colors.blue),
          ),
        )
        .toList();

    const canvasSize = Size(1920, 1080); // Full HD

    // Warm-up pass (to populate caches)
    final warmupRecorder = ui.PictureRecorder();
    final warmupCanvas = Canvas(warmupRecorder);
    pipeline.render(
      canvas: warmupCanvas,
      size: canvasSize,
      viewportController: viewportController,
      paths: renderablePaths,
      shapes: renderableShapes,
    );
    warmupRecorder.endRecording();

    // Run benchmark iterations
    final frameTimes = <double>[];
    final memoryBefore = _getMemoryUsageMB();

    for (var i = 0; i < config.iterations; i++) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Measure render time
      final stopwatch = Stopwatch()..start();

      pipeline.render(
        canvas: canvas,
        size: canvasSize,
        viewportController: viewportController,
        paths: renderablePaths,
        shapes: renderableShapes,
      );

      stopwatch.stop();
      frameTimes.add(stopwatch.elapsedMicroseconds / 1000.0);

      recorder.endRecording();
    }

    final memoryAfter = _getMemoryUsageMB();
    final memoryUsed = memoryAfter - memoryBefore;

    // Calculate statistics
    final avgFrameTime = frameTimes.reduce((a, b) => a + b) / frameTimes.length;
    final avgFps = 1000.0 / avgFrameTime;

    final metrics = pipeline.lastMetrics!;

    // Cleanup
    viewportController.dispose();
    pathRenderer.invalidateAll();

    return BenchmarkResult(
      scenario: scenario,
      frameTimeMs: avgFrameTime,
      fps: avgFps,
      objectsRendered: metrics.objectsRendered,
      objectsCulled: metrics.objectsCulled,
      cacheSize: metrics.cacheSize,
      memoryUsedMB: memoryUsed.isNegative ? 0 : memoryUsed,
    );
  }

  double _getMemoryUsageMB() {
    try {
      final info = ProcessInfo.currentRss;
      return info / (1024 * 1024);
    } catch (e) {
      return 0.0; // Fallback if not available
    }
  }

  void _printScenarioResult(BenchmarkResult result) {
    print('  Frame time: ${result.frameTimeMs.toStringAsFixed(2)}ms');
    print('  FPS: ${result.fps.toStringAsFixed(1)}');
    print('  Rendered: ${result.objectsRendered}, '
        'Culled: ${result.objectsCulled}');
    print('  Cache size: ${result.cacheSize}');
    print('  Memory: ${result.memoryUsedMB.toStringAsFixed(2)}MB\n');
  }
}

/// Exports benchmark results to JSON and/or CSV format.
class ResultsExporter {
  ResultsExporter({required this.config});

  final BenchmarkConfig config;

  Future<void> export(List<BenchmarkResult> results) async {
    final format = config.format.toLowerCase();

    if (format == 'json' || format == 'both') {
      await _exportJson(results);
    }

    if (format == 'csv' || format == 'both') {
      await _exportCsv(results);
    }
  }

  Future<void> _exportJson(List<BenchmarkResult> results) async {
    final outputPath = config.format == 'both'
        ? '${config.outputPath}.json'
        : config.outputPath.endsWith('.json')
            ? config.outputPath
            : '${config.outputPath}.json';

    final data = {
      'benchmark': 'WireTuner Rendering Performance',
      'timestamp': DateTime.now().toIso8601String(),
      'configuration': {
        'dataset': config.datasetName,
        'objectCount': config.objectCount,
        'iterations': config.iterations,
      },
      'results': results.map((r) => r.toJson()).toList(),
    };

    final file = File(outputPath);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
    );
  }

  Future<void> _exportCsv(List<BenchmarkResult> results) async {
    final outputPath = config.format == 'both'
        ? '${config.outputPath}.csv'
        : config.outputPath.endsWith('.csv')
            ? config.outputPath
            : '${config.outputPath}.csv';

    final buffer = StringBuffer();

    // Header
    buffer.writeln(
      'Scenario,ObjectCount,ZoomLevel,Culling,Caching,'
      'FrameTimeMs,FPS,ObjectsRendered,ObjectsCulled,CacheSize,MemoryMB',
    );

    // Data rows
    for (final result in results) {
      buffer.writeln(
        '${result.scenario.name},'
        '${result.scenario.objectCount},'
        '${result.scenario.zoomLevel},'
        '${result.scenario.enableCulling},'
        '${result.scenario.enableCaching},'
        '${result.frameTimeMs.toStringAsFixed(2)},'
        '${result.fps.toStringAsFixed(1)},'
        '${result.objectsRendered},'
        '${result.objectsCulled},'
        '${result.cacheSize},'
        '${result.memoryUsedMB.toStringAsFixed(2)}',
      );
    }

    final file = File(outputPath);
    await file.writeAsString(buffer.toString());
  }
}

void _printSummary(List<BenchmarkResult> results) {
  print('\n=============================');
  print('Benchmark Summary');
  print('=============================\n');

  final bestFps = results.reduce(
    (a, b) => a.fps > b.fps ? a : b,
  );
  final worstFps = results.reduce(
    (a, b) => a.fps < b.fps ? a : b,
  );

  print('Best FPS: ${bestFps.fps.toStringAsFixed(1)} '
      '(${bestFps.scenario.name})');
  print('Worst FPS: ${worstFps.fps.toStringAsFixed(1)} '
      '(${worstFps.scenario.name})');

  final avgFps =
      results.map((r) => r.fps).reduce((a, b) => a + b) / results.length;
  print('Average FPS: ${avgFps.toStringAsFixed(1)}');

  final framesUnder60 = results.where((r) => r.fps < 60).length;
  final framesUnder30 = results.where((r) => r.fps < 30).length;

  print('\nFrame Budget Analysis:');
  print('  60 FPS target: ${results.length - framesUnder60}/${results.length} scenarios passed');
  print('  30 FPS minimum: ${results.length - framesUnder30}/${results.length} scenarios passed');
}
