import 'package:flutter/foundation.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/domain/document/selection.dart';

/// Manages the mutable document state and notifies listeners of changes.
///
/// DocumentProvider wraps the immutable Document model with a ChangeNotifier
/// to enable reactive UI updates when the document changes. This follows the
/// Provider pattern recommended in Decision 7.
///
/// ## Responsibilities
///
/// 1. **State Management**:
///    - Holds the current document instance
///    - Provides methods to update document properties
///    - Notifies listeners when document changes
///
/// 2. **Viewport Persistence**:
///    - Stores viewport state within the document
///    - Updates viewport when controller changes
///    - Restores viewport when document loads
///
/// 3. **Document Lifecycle**:
///    - Handles document creation and loading
///    - Manages save/restore operations (mock for now)
///    - Tracks unsaved changes
///
/// ## Usage
///
/// ```dart
/// // Create provider
/// final provider = DocumentProvider(
///   initialDocument: Document(id: 'doc-1'),
/// );
///
/// // Update viewport
/// provider.updateViewport(newViewport);
///
/// // Access current document
/// final doc = provider.document;
///
/// // Listen to changes
/// provider.addListener(() {
///   print('Document changed: ${provider.document.title}');
/// });
/// ```
///
/// ## Integration with Provider Package
///
/// This class is designed to be used with the Provider package:
///
/// ```dart
/// ChangeNotifierProvider<DocumentProvider>(
///   create: (_) => DocumentProvider(),
///   child: MyApp(),
/// )
/// ```
class DocumentProvider extends ChangeNotifier {
  /// Creates a document provider with an optional initial document.
  ///
  /// If no initial document is provided, creates a default empty document.
  DocumentProvider({
    Document? initialDocument,
  }) : _document = initialDocument ??
            const Document(
              id: 'default-doc',
              title: 'Untitled',
            );

  /// The current document state.
  Document _document;

  /// Gets the current document.
  Document get document => _document;

  /// Gets the current viewport state from the document.
  Viewport get viewport => _document.viewport;

  /// Gets whether the document has unsaved changes.
  ///
  /// Note: This is a placeholder. In future iterations, this will be
  /// determined by comparing against the last saved snapshot.
  bool get hasUnsavedChanges => _document.hasUnsavedChanges;

  /// Updates the document with a new instance.
  ///
  /// This is the primary method for modifying the document. Since Document
  /// is immutable, any changes require creating a new instance via copyWith.
  ///
  /// Example:
  /// ```dart
  /// provider.updateDocument(
  ///   provider.document.copyWith(title: 'New Title'),
  /// );
  /// ```
  void updateDocument(Document newDocument) {
    if (_document == newDocument) return;
    _document = newDocument;
    notifyListeners();
  }

  /// Updates the viewport state within the document.
  ///
  /// This is called when viewport controller changes (pan, zoom, canvas resize).
  /// The viewport state is persisted within the document so it can be restored
  /// when the document is reopened.
  ///
  /// Example:
  /// ```dart
  /// provider.updateViewport(
  ///   Viewport(
  ///     pan: Point(x: 100, y: 50),
  ///     zoom: 1.5,
  ///     canvasSize: Size(width: 1920, height: 1080),
  ///   ),
  /// );
  /// ```
  void updateViewport(Viewport newViewport) {
    if (_document.viewport == newViewport) return;
    _document = _document.copyWith(viewport: newViewport);
    notifyListeners();
  }

  /// Updates the document title.
  ///
  /// This is a convenience method for updating the title without needing
  /// to use copyWith explicitly.
  void updateTitle(String newTitle) {
    if (_document.title == newTitle) return;
    _document = _document.copyWith(title: newTitle);
    notifyListeners();
  }

  /// Updates the selection state within the document.
  ///
  /// This is called when selection changes via tools or keyboard shortcuts.
  void updateSelection(Selection newSelection) {
    if (_document.selection == newSelection) return;
    _document = _document.copyWith(selection: newSelection);
    notifyListeners();
  }

  /// Updates the layers within the document.
  ///
  /// This is called when layers are added, removed, or modified.
  void updateLayers(List<Layer> newLayers) {
    if (_document.layers == newLayers) return;
    _document = _document.copyWith(layers: newLayers);
    notifyListeners();
  }

  /// Loads a document from JSON.
  ///
  /// This is used for document restore operations. The viewport state
  /// is preserved and can be synced to the viewport controller after loading.
  ///
  /// Example:
  /// ```dart
  /// final json = await loadDocumentJson();
  /// provider.loadFromJson(json);
  ///
  /// // Sync viewport to controller
  /// viewportState.syncFromDomain(provider.viewport);
  /// ```
  void loadFromJson(Map<String, dynamic> json) {
    _document = Document.fromJson(json);
    notifyListeners();
  }

  /// Saves the document to JSON.
  ///
  /// This serializes the current document state including viewport.
  /// The viewport state is preserved across save/restore cycles.
  ///
  /// Example:
  /// ```dart
  /// final json = provider.toJson();
  /// await saveDocumentJson(json);
  /// ```
  Map<String, dynamic> toJson() => _document.toJson();

  /// Creates a new empty document.
  ///
  /// This is used for "New Document" operations. Resets to a clean state
  /// with default viewport.
  void createNew({
    String? id,
    String title = 'Untitled',
  }) {
    _document = Document(
      id: id ?? 'doc-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
    );
    notifyListeners();
  }

  @override
  String toString() => 'DocumentProvider(document: ${_document.id})';
}
