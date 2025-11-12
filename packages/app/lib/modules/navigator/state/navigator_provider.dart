import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../thumbnail_service.dart';

/// Represents a single artboard in the Navigator grid.
///
/// Contains all display state needed to render an artboard card,
/// including thumbnail data, metadata, and selection state.
@immutable
class ArtboardCardState {
  /// Unique identifier for the artboard.
  final String artboardId;

  /// Display name of the artboard.
  final String title;

  /// Artboard dimensions in document units.
  final Size dimensions;

  /// Whether the artboard has unsaved changes.
  final bool isDirty;

  /// Last modification timestamp.
  final DateTime lastModified;

  /// Rendered thumbnail image data (null if not yet loaded).
  final Uint8List? thumbnail;

  /// Whether this card is currently visible in the viewport (for virtualization).
  final bool isVisible;

  const ArtboardCardState({
    required this.artboardId,
    required this.title,
    required this.dimensions,
    this.isDirty = false,
    required this.lastModified,
    this.thumbnail,
    this.isVisible = true,
  });

  ArtboardCardState copyWith({
    String? artboardId,
    String? title,
    Size? dimensions,
    bool? isDirty,
    DateTime? lastModified,
    Uint8List? thumbnail,
    bool? isVisible,
  }) {
    return ArtboardCardState(
      artboardId: artboardId ?? this.artboardId,
      title: title ?? this.title,
      dimensions: dimensions ?? this.dimensions,
      isDirty: isDirty ?? this.isDirty,
      lastModified: lastModified ?? this.lastModified,
      thumbnail: thumbnail ?? this.thumbnail,
      isVisible: isVisible ?? this.isVisible,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArtboardCardState &&
          runtimeType == other.runtimeType &&
          artboardId == other.artboardId &&
          title == other.title &&
          dimensions == other.dimensions &&
          isDirty == other.isDirty &&
          lastModified == other.lastModified &&
          isVisible == other.isVisible;

  @override
  int get hashCode =>
      artboardId.hashCode ^
      title.hashCode ^
      dimensions.hashCode ^
      isDirty.hashCode ^
      lastModified.hashCode ^
      isVisible.hashCode;
}

/// Represents a document tab in the Navigator window.
@immutable
class DocumentTab {
  /// Unique identifier for the document.
  final String documentId;

  /// Display name (usually filename).
  final String name;

  /// Full file path (for tooltip).
  final String path;

  /// Whether the document has unsaved changes.
  final bool isDirty;

  /// List of artboard IDs in this document.
  final List<String> artboardIds;

  const DocumentTab({
    required this.documentId,
    required this.name,
    required this.path,
    this.isDirty = false,
    required this.artboardIds,
  });

  DocumentTab copyWith({
    String? documentId,
    String? name,
    String? path,
    bool? isDirty,
    List<String>? artboardIds,
  }) {
    return DocumentTab(
      documentId: documentId ?? this.documentId,
      name: name ?? this.name,
      path: path ?? this.path,
      isDirty: isDirty ?? this.isDirty,
      artboardIds: artboardIds ?? this.artboardIds,
    );
  }
}

/// Grid layout configuration for the Navigator.
@immutable
class GridConfig {
  /// Number of columns in the grid.
  final int columns;

  /// Spacing between cards.
  final double spacing;

  /// Thumbnail size (square).
  final double thumbnailSize;

  const GridConfig({
    this.columns = 4,
    this.spacing = 16.0,
    this.thumbnailSize = 200.0,
  });

  GridConfig copyWith({
    int? columns,
    double? spacing,
    double? thumbnailSize,
  }) {
    return GridConfig(
      columns: columns ?? this.columns,
      spacing: spacing ?? this.spacing,
      thumbnailSize: thumbnailSize ?? this.thumbnailSize,
    );
  }
}

/// Viewport snapshot for a single artboard (position, zoom).
///
/// This matches the structure expected by Flow C's viewport restoration.
@immutable
class ViewportSnapshot {
  final String artboardId;
  final Offset pan;
  final double zoom;

  const ViewportSnapshot({
    required this.artboardId,
    required this.pan,
    required this.zoom,
  });

  ViewportSnapshot copyWith({
    String? artboardId,
    Offset? pan,
    double? zoom,
  }) {
    return ViewportSnapshot(
      artboardId: artboardId ?? this.artboardId,
      pan: pan ?? this.pan,
      zoom: zoom ?? this.zoom,
    );
  }
}

/// Main state provider for the Navigator window.
///
/// Manages document tabs, artboard cards, selection state, and integrates
/// with existing viewport, snapping, and thumbnail services.
///
/// ## Architecture
///
/// This provider follows the established pattern from `ToolProvider`:
/// - Extends `ChangeNotifier` for reactive UI updates
/// - Composes services (thumbnail refresh, viewport management)
/// - Provides clear state accessors for widgets
/// - Emits telemetry for performance tracking
///
/// ## Usage
///
/// ```dart
/// final navigator = context.watch<NavigatorProvider>();
///
/// // Access state
/// final tabs = navigator.openDocuments;
/// final artboards = navigator.getArtboards(documentId);
///
/// // Mutations
/// navigator.selectArtboard(artboardId);
/// navigator.renameArtboard(artboardId, newName);
/// ```
///
/// Related: Flow C (Multi-Artboard Document Load), Journey H (Manage Artboards)
class NavigatorProvider extends ChangeNotifier {
  /// Open document tabs.
  final List<DocumentTab> _openDocuments = [];

  /// Currently active document ID.
  String? _activeDocumentId;

  /// Artboard cards keyed by artboard ID.
  final Map<String, ArtboardCardState> _artboards = {};

  /// Currently selected artboard IDs (supports multi-select).
  final Set<String> _selectedArtboards = {};

  /// Grid layout configuration.
  GridConfig _gridConfig = const GridConfig();

  /// Viewport snapshots per artboard (for restoration).
  final Map<String, ViewportSnapshot> _viewportStates = {};

  /// Thumbnail service (optional, injected via constructor).
  ThumbnailService? _thumbnailService;

  /// Last refresh timestamp per artboard (for status display).
  /// Made package-private for thumbnail service callback access.
  final Map<String, DateTime> lastRefreshTime = {};

  /// Creates a NavigatorProvider.
  ///
  /// [thumbnailService]: Optional thumbnail service for background refresh.
  ///                     If null, thumbnail refresh features are disabled.
  NavigatorProvider({ThumbnailService? thumbnailService}) {
    _thumbnailService = thumbnailService;
  }

  // Getters

  /// Open document tabs.
  List<DocumentTab> get openDocuments => List.unmodifiable(_openDocuments);

  /// Currently active document ID.
  String? get activeDocumentId => _activeDocumentId;

  /// Currently active document tab.
  DocumentTab? get activeDocument {
    if (_activeDocumentId == null) return null;
    try {
      return _openDocuments.firstWhere((tab) => tab.documentId == _activeDocumentId);
    } catch (_) {
      return null;
    }
  }

  /// Grid configuration.
  GridConfig get gridConfig => _gridConfig;

  /// Selected artboard IDs.
  Set<String> get selectedArtboards => Set.unmodifiable(_selectedArtboards);

  /// Get artboards for a specific document.
  List<ArtboardCardState> getArtboards(String documentId) {
    final tab = _openDocuments.where((t) => t.documentId == documentId).firstOrNull;
    if (tab == null) return [];

    return tab.artboardIds
        .map((id) => _artboards[id])
        .where((card) => card != null)
        .cast<ArtboardCardState>()
        .toList();
  }

  /// Get a specific artboard card state.
  ArtboardCardState? getArtboard(String artboardId) => _artboards[artboardId];

  /// Check if an artboard is selected.
  bool isSelected(String artboardId) => _selectedArtboards.contains(artboardId);

  /// Get viewport state for an artboard.
  ViewportSnapshot? getViewportState(String artboardId) => _viewportStates[artboardId];

  /// Get last refresh time for an artboard.
  DateTime? getLastRefreshTime(String artboardId) => lastRefreshTime[artboardId];

  /// Get time since last refresh for an artboard.
  Duration? getTimeSinceRefresh(String artboardId) {
    final lastRefresh = lastRefreshTime[artboardId];
    if (lastRefresh == null) return null;
    return DateTime.now().difference(lastRefresh);
  }

  // Mutations

  /// Open a new document tab.
  ///
  /// This method is called during Flow C (Multi-Artboard Document Load).
  /// It initializes the tab and prepares artboard cards for display.
  void openDocument(DocumentTab tab) {
    // Avoid duplicates
    if (_openDocuments.any((t) => t.documentId == tab.documentId)) {
      // Switch to existing tab
      _activeDocumentId = tab.documentId;
      notifyListeners();
      return;
    }

    _openDocuments.add(tab);
    _activeDocumentId = tab.documentId;

    // Initialize placeholder artboard cards (thumbnails loaded lazily)
    for (final artboardId in tab.artboardIds) {
      _artboards[artboardId] = ArtboardCardState(
        artboardId: artboardId,
        title: 'Artboard ${artboardId.length > 8 ? artboardId.substring(0, 8) : artboardId}',
        dimensions: const Size(1920, 1080),
        lastModified: DateTime.now(),
      );
    }

    notifyListeners();
  }

  /// Close a document tab.
  void closeDocument(String documentId) {
    final index = _openDocuments.indexWhere((t) => t.documentId == documentId);
    if (index == -1) return;

    final tab = _openDocuments[index];
    _openDocuments.removeAt(index);

    // Clean up artboards
    for (final artboardId in tab.artboardIds) {
      _artboards.remove(artboardId);
      _selectedArtboards.remove(artboardId);
      _viewportStates.remove(artboardId);
      lastRefreshTime.remove(artboardId);

      // Mark artboard as invisible in thumbnail service
      _thumbnailService?.updateVisibility(artboardId, visible: false);
      _thumbnailService?.invalidateCache(artboardId);
    }

    // Switch active document if needed
    if (_activeDocumentId == documentId) {
      _activeDocumentId = _openDocuments.isNotEmpty ? _openDocuments.last.documentId : null;
    }

    notifyListeners();
  }

  /// Switch to a different document tab.
  void switchToDocument(String documentId) {
    if (_openDocuments.any((t) => t.documentId == documentId)) {
      _activeDocumentId = documentId;
      notifyListeners();
    }
  }

  /// Update artboard metadata (from document load or event replay).
  void updateArtboard({
    required String artboardId,
    String? title,
    Size? dimensions,
    bool? isDirty,
    DateTime? lastModified,
    Uint8List? thumbnail,
    bool? isVisible,
  }) {
    final current = _artboards[artboardId];
    if (current == null) return;

    _artboards[artboardId] = current.copyWith(
      title: title,
      dimensions: dimensions,
      isDirty: isDirty,
      lastModified: lastModified,
      thumbnail: thumbnail,
      isVisible: isVisible,
    );

    // Update thumbnail service if visibility or dirty state changed
    if (_thumbnailService != null) {
      if (isDirty != null && isDirty) {
        _thumbnailService!.markDirty(
          artboardId,
          visible: isVisible ?? current.isVisible,
        );
      }
      if (isVisible != null) {
        _thumbnailService!.updateVisibility(artboardId, visible: isVisible);
      }
    }

    notifyListeners();
  }

  /// Select a single artboard (clears previous selection).
  void selectArtboard(String artboardId) {
    _selectedArtboards.clear();
    _selectedArtboards.add(artboardId);
    notifyListeners();
  }

  /// Toggle artboard selection (for Cmd+Click multi-select).
  void toggleArtboard(String artboardId) {
    if (_selectedArtboards.contains(artboardId)) {
      _selectedArtboards.remove(artboardId);
    } else {
      _selectedArtboards.add(artboardId);
    }
    notifyListeners();
  }

  /// Select a range of artboards (for Shift+Click).
  void selectRange(String fromId, String toId) {
    final activeTab = activeDocument;
    if (activeTab == null) return;

    final artboardIds = activeTab.artboardIds;
    final fromIndex = artboardIds.indexOf(fromId);
    final toIndex = artboardIds.indexOf(toId);

    if (fromIndex == -1 || toIndex == -1) return;

    final start = fromIndex < toIndex ? fromIndex : toIndex;
    final end = fromIndex < toIndex ? toIndex : fromIndex;

    _selectedArtboards.clear();
    for (var i = start; i <= end; i++) {
      _selectedArtboards.add(artboardIds[i]);
    }

    notifyListeners();
  }

  /// Clear all selections.
  void clearSelection() {
    _selectedArtboards.clear();
    notifyListeners();
  }

  /// Update grid configuration.
  void updateGridConfig(GridConfig config) {
    _gridConfig = config;
    notifyListeners();
  }

  /// Save viewport state for an artboard (called during tab switches).
  ///
  /// This fulfills Flow C's requirement to persist per-artboard viewport state.
  void saveViewportState(String artboardId, ViewportSnapshot snapshot) {
    _viewportStates[artboardId] = snapshot;
    // Note: Actual persistence to SettingsService would happen here
    // For now, we store in memory
  }

  /// Trigger immediate thumbnail refresh (e.g., on save or manual refresh).
  ///
  /// [trigger]: Type of refresh trigger (manual, save, idle).
  /// Returns true if refresh was scheduled, false if cooldown is active.
  bool refreshThumbnailNow(String artboardId, {required RefreshTrigger trigger}) {
    if (_thumbnailService == null) {
      debugPrint('[NavigatorProvider] Thumbnail service not available');
      return false;
    }

    final refreshed = _thumbnailService!.refreshNow(artboardId, trigger: trigger);

    if (refreshed) {
      // Note: _lastRefreshTime is updated by the service when thumbnail is ready
      notifyListeners(); // Update UI to show refresh in progress
    }

    return refreshed;
  }

  /// Trigger save-based refresh for all dirty artboards in a document.
  void refreshOnSave(String documentId) {
    if (_thumbnailService == null) return;

    final tab = _openDocuments.where((t) => t.documentId == documentId).firstOrNull;
    if (tab == null) return;

    for (final artboardId in tab.artboardIds) {
      final card = _artboards[artboardId];
      if (card != null && card.isDirty) {
        refreshThumbnailNow(artboardId, trigger: RefreshTrigger.save);
      }
    }
  }

  /// Gets cached thumbnail from service.
  Uint8List? getCachedThumbnail(String artboardId) {
    return _thumbnailService?.getCached(artboardId);
  }

  /// Invalidates cached thumbnail for an artboard.
  void invalidateThumbnailCache(String artboardId) {
    _thumbnailService?.invalidateCache(artboardId);
  }

  @override
  void dispose() {
    // Thumbnail service is disposed externally (owned by NavigatorWindow)
    super.dispose();
  }
}
