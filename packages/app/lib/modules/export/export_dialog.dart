import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/infrastructure/export/svg_exporter.dart';
import 'package:wiretuner/infrastructure/export/json_exporter.dart';
import 'package:wiretuner/infrastructure/export/pdf_exporter_async.dart';
import 'package:wiretuner/modules/export/pdf_status_panel.dart';

/// Export dialog for choosing format and scope of document export.
///
/// This dialog provides a unified interface for exporting documents to
/// various formats (SVG, JSON, PDF) with per-artboard or full-document scope.
///
/// ## Features
///
/// - Format selection: SVG, JSON archival, PDF (future)
/// - Scope selection: Current artboard, all artboards, specific artboards
/// - Compatibility warnings for each format
/// - Export settings (pretty print for JSON, etc.)
///
/// ## Usage
///
/// ```dart
/// final result = await showDialog<ExportResult>(
///   context: context,
///   builder: (context) => ExportDialog(document: document),
/// );
/// if (result != null) {
///   // Handle export result
/// }
/// ```
class ExportDialog extends StatefulWidget {
  const ExportDialog({
    required this.document,
    this.currentArtboardId,
    super.key,
  });

  /// The document to export.
  final Document document;

  /// The currently active artboard ID (for "Current artboard" option).
  final String? currentArtboardId;

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  ExportFormat _selectedFormat = ExportFormat.svg;
  ExportScope _selectedScope = ExportScope.currentArtboard;
  Set<String> _selectedArtboardIds = {};
  bool _prettyPrint = true;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    // Default to current artboard if available
    if (widget.currentArtboardId != null) {
      _selectedArtboardIds = {widget.currentArtboardId!};
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Export Document'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Format selection
            _buildFormatSection(),
            const SizedBox(height: 24),

            // Scope selection
            _buildScopeSection(),
            const SizedBox(height: 24),

            // Format-specific options
            if (_selectedFormat == ExportFormat.json) _buildJsonOptions(),

            // Compatibility warnings
            _buildWarningsSection(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isExporting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isExporting ? null : _handleExport,
          child: _isExporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Export'),
        ),
      ],
    );
  }

  Widget _buildFormatSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Format',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        SegmentedButton<ExportFormat>(
          segments: const [
            ButtonSegment(
              value: ExportFormat.svg,
              label: Text('SVG'),
              icon: Icon(Icons.image_outlined),
            ),
            ButtonSegment(
              value: ExportFormat.json,
              label: Text('JSON'),
              icon: Icon(Icons.code),
            ),
            ButtonSegment(
              value: ExportFormat.pdf,
              label: Text('PDF'),
              icon: Icon(Icons.picture_as_pdf_outlined),
            ),
          ],
          selected: {_selectedFormat},
          onSelectionChanged: (Set<ExportFormat> newSelection) {
            setState(() {
              _selectedFormat = newSelection.first;
            });
          },
        ),
      ],
    );
  }

  Widget _buildScopeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Scope',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        RadioListTile<ExportScope>(
          title: const Text('Current artboard'),
          value: ExportScope.currentArtboard,
          groupValue: _selectedScope,
          onChanged: widget.currentArtboardId != null
              ? (value) {
                  setState(() {
                    _selectedScope = value!;
                    _selectedArtboardIds = {widget.currentArtboardId!};
                  });
                }
              : null,
          dense: true,
        ),
        RadioListTile<ExportScope>(
          title: const Text('All artboards'),
          value: ExportScope.allArtboards,
          groupValue: _selectedScope,
          onChanged: (value) {
            setState(() {
              _selectedScope = value!;
              _selectedArtboardIds = widget.document.artboards
                  .map((ab) => ab.id)
                  .toSet();
            });
          },
          dense: true,
        ),
        RadioListTile<ExportScope>(
          title: const Text('Selected artboards'),
          value: ExportScope.selectedArtboards,
          groupValue: _selectedScope,
          onChanged: (value) {
            setState(() {
              _selectedScope = value!;
            });
          },
          dense: true,
        ),
        if (_selectedScope == ExportScope.selectedArtboards)
          Padding(
            padding: const EdgeInsets.only(left: 32, top: 8),
            child: _buildArtboardSelector(),
          ),
      ],
    );
  }

  Widget _buildArtboardSelector() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 150),
      child: ListView(
        shrinkWrap: true,
        children: widget.document.artboards.map((artboard) {
          return CheckboxListTile(
            title: Text(artboard.name),
            subtitle: Text(
              '${artboard.bounds.width.toInt()} × ${artboard.bounds.height.toInt()}',
            ),
            value: _selectedArtboardIds.contains(artboard.id),
            onChanged: (bool? value) {
              setState(() {
                if (value == true) {
                  _selectedArtboardIds.add(artboard.id);
                } else {
                  _selectedArtboardIds.remove(artboard.id);
                }
              });
            },
            dense: true,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildJsonOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'JSON Options',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          title: const Text('Pretty print'),
          subtitle: const Text('Human-readable formatting'),
          value: _prettyPrint,
          onChanged: (bool? value) {
            setState(() {
              _prettyPrint = value ?? true;
            });
          },
          dense: true,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildWarningsSection() {
    final warnings = _getCompatibilityWarnings();
    if (warnings.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber, size: 16, color: Colors.amber.shade700),
              const SizedBox(width: 8),
              Text(
                'Compatibility Notes',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.amber.shade900,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...warnings.map(
            (warning) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• '),
                  Expanded(
                    child: Text(
                      warning,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getCompatibilityWarnings() {
    final warnings = <String>[];

    switch (_selectedFormat) {
      case ExportFormat.svg:
        warnings.add(
          'SVG export preserves visual content only. Interactive elements and animations are not supported.',
        );
        if (_selectedScope == ExportScope.allArtboards &&
            widget.document.artboards.length > 1) {
          warnings.add(
            'Exporting all artboards will create separate SVG files.',
          );
        }
        break;

      case ExportFormat.json:
        warnings.add(
          'JSON export is snapshot-only. Event history and undo stack are not preserved.',
        );
        warnings.add(
          'JSON files are suitable for archival, version control, and scripting.',
        );
        break;

      case ExportFormat.pdf:
        warnings.add(
          'PDF export is asynchronous. The export will continue in the background.',
        );
        if (_selectedScope == ExportScope.allArtboards &&
            widget.document.artboards.length > 1) {
          warnings.add(
            'Multiple artboards will be combined into a single PDF file.',
          );
        }
        break;
    }

    return warnings;
  }

  Future<void> _handleExport() async {
    if (_selectedArtboardIds.isEmpty &&
        _selectedScope != ExportScope.allArtboards) {
      _showError('Please select at least one artboard to export.');
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      final result = await _performExport();
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } catch (e) {
      if (mounted) {
        _showError('Export failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<ExportResult?> _performExport() async {
    // Get save location from user
    final typeGroup = XTypeGroup(
      label: _selectedFormat.name.toUpperCase(),
      extensions: [_selectedFormat.extension],
    );

    final savePath = await getSavePath(
      acceptedTypeGroups: [typeGroup],
      suggestedName: _getSuggestedFileName(),
    );

    if (savePath == null) {
      // User cancelled
      return null;
    }

    switch (_selectedFormat) {
      case ExportFormat.svg:
        return await _exportSvg(savePath);

      case ExportFormat.json:
        return await _exportJson(savePath);

      case ExportFormat.pdf:
        return await _exportPdf(savePath);
    }
  }

  Future<ExportResult> _exportSvg(String basePath) async {
    final exporter = SvgExporter();
    final exportedFiles = <String>[];

    if (_selectedScope == ExportScope.currentArtboard) {
      // Single artboard export
      final artboard = widget.document.artboards
          .firstWhere((ab) => ab.id == widget.currentArtboardId);
      await exporter.exportArtboardToFile(
        artboard,
        basePath,
        documentTitle: widget.document.title,
      );
      exportedFiles.add(basePath);
    } else {
      // Multiple artboards - create separate files
      final artboards = widget.document.artboards
          .where((ab) => _selectedArtboardIds.contains(ab.id))
          .toList();

      for (var i = 0; i < artboards.length; i++) {
        final artboard = artboards[i];
        final filePath = _getMultiArtboardPath(basePath, artboard.name, i);
        await exporter.exportArtboardToFile(
          artboard,
          filePath,
          documentTitle: widget.document.title,
        );
        exportedFiles.add(filePath);
      }
    }

    return ExportResult(
      format: _selectedFormat,
      filePaths: exportedFiles,
    );
  }

  Future<ExportResult> _exportJson(String filePath) async {
    final exporter = JsonExporter();
    final artboardIds = _selectedScope == ExportScope.allArtboards
        ? null
        : _selectedArtboardIds.toList();

    await exporter.exportToFile(
      widget.document,
      filePath,
      prettyPrint: _prettyPrint,
      artboardIds: artboardIds,
    );

    return ExportResult(
      format: _selectedFormat,
      filePaths: [filePath],
    );
  }

  String _getSuggestedFileName() {
    final baseName = widget.document.title.isEmpty
        ? 'untitled'
        : widget.document.title.toLowerCase().replaceAll(' ', '_');

    if (_selectedScope == ExportScope.currentArtboard &&
        widget.currentArtboardId != null) {
      final artboard = widget.document.artboards
          .firstWhere((ab) => ab.id == widget.currentArtboardId);
      return '${baseName}_${artboard.name.toLowerCase().replaceAll(' ', '_')}.${_selectedFormat.extension}';
    }

    return '$baseName.${_selectedFormat.extension}';
  }

  String _getMultiArtboardPath(String basePath, String artboardName, int index) {
    final dir = basePath.substring(0, basePath.lastIndexOf('/'));
    final baseFileName = basePath.substring(
      basePath.lastIndexOf('/') + 1,
      basePath.lastIndexOf('.'),
    );
    final extension = basePath.substring(basePath.lastIndexOf('.'));

    final sanitizedName = artboardName.toLowerCase().replaceAll(' ', '_');
    return '$dir/${baseFileName}_${sanitizedName}_${index + 1}$extension';
  }

  Future<ExportResult> _exportPdf(String filePath) async {
    // Create PDF exporter with Redis configuration
    // TODO: Read Redis host/port from environment/config
    final exporter = PdfExporterAsync(
      redisHost: 'localhost',
      redisPort: 6379,
    );

    try {
      // Enqueue PDF export job
      final jobId = await exporter.exportToFile(
        widget.document,
        filePath,
        artboardIds: _selectedScope == ExportScope.allArtboards
            ? null
            : _selectedArtboardIds.toList(),
      );

      // Show status panel (non-blocking)
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => PdfStatusPanel(
            jobId: jobId,
            exporter: exporter,
            onComplete: () {
              _showSuccess('PDF export completed successfully');
            },
            onError: (error) {
              _showError('PDF export failed: $error');
            },
          ),
        );
      }

      return ExportResult(
        format: ExportFormat.pdf,
        filePaths: [filePath],
      );
    } catch (e) {
      rethrow;
    } finally {
      exporter.dispose();
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }
}

/// Available export formats.
enum ExportFormat {
  svg('svg'),
  json('json'),
  pdf('pdf');

  const ExportFormat(this.extension);
  final String extension;
}

/// Export scope options.
enum ExportScope {
  currentArtboard,
  allArtboards,
  selectedArtboards,
}

/// Result of an export operation.
class ExportResult {
  const ExportResult({
    required this.format,
    required this.filePaths,
  });

  final ExportFormat format;
  final List<String> filePaths;
}
