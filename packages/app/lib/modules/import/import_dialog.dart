import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:infrastructure/import/ai_importer.dart';

/// Import dialog for selecting and importing external file formats.
///
/// This dialog provides a unified interface for importing files from various
/// formats (AI, SVG, PDF) with compatibility warnings and progress feedback.
///
/// ## Features
///
/// - Format selection: AI (PDF-compatible), SVG, PDF (future)
/// - File picker integration
/// - Compatibility warnings per format
/// - Import progress and warning display
/// - Tier-1/2/3 feature support indication
///
/// ## Usage
///
/// ```dart
/// final result = await showDialog<ImportResult>(
///   context: context,
///   builder: (context) => const ImportDialog(),
/// );
/// if (result != null) {
///   // Process imported events
///   for (final event in result.events) {
///     eventDispatcher.dispatch(event);
///   }
/// }
/// ```
class ImportDialog extends StatefulWidget {
  const ImportDialog({super.key});

  @override
  State<ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<ImportDialog> {
  ImportFormat _selectedFormat = ImportFormat.ai;
  bool _isImporting = false;
  List<ImportWarning> _importWarnings = [];
  String? _selectedFilePath;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import File'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Format selection
            _buildFormatSection(),
            const SizedBox(height: 24),

            // File selection
            _buildFileSelectionSection(),
            const SizedBox(height: 24),

            // Compatibility warnings
            _buildWarningsSection(),

            // Import warnings (after import completes)
            if (_importWarnings.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildImportWarningsSection(),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isImporting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isImporting || _selectedFilePath == null
              ? null
              : _handleImport,
          child: _isImporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Import'),
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
        SegmentedButton<ImportFormat>(
          segments: const [
            ButtonSegment(
              value: ImportFormat.ai,
              label: Text('AI'),
              icon: Icon(Icons.image_outlined),
            ),
            ButtonSegment(
              value: ImportFormat.svg,
              label: Text('SVG'),
              icon: Icon(Icons.code),
              enabled: false, // Not yet implemented
            ),
            ButtonSegment(
              value: ImportFormat.pdf,
              label: Text('PDF'),
              icon: Icon(Icons.picture_as_pdf_outlined),
              enabled: false, // Not yet implemented
            ),
          ],
          selected: {_selectedFormat},
          onSelectionChanged: (Set<ImportFormat> newSelection) {
            setState(() {
              _selectedFormat = newSelection.first;
              _selectedFilePath = null; // Reset selection on format change
              _importWarnings.clear();
            });
          },
        ),
      ],
    );
  }

  Widget _buildFileSelectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'File',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _selectedFilePath != null
                      ? _getFileName(_selectedFilePath!)
                      : 'No file selected',
                  style: TextStyle(
                    color: _selectedFilePath != null
                        ? Colors.black87
                        : Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _isImporting ? null : _handleSelectFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('Browse'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWarningsSection() {
    final warnings = _getCompatibilityWarnings();
    if (warnings.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                'Import Compatibility',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.blue.shade900,
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
                        color: Colors.blue.shade900,
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

  Widget _buildImportWarningsSection() {
    // Group warnings by severity
    final errors = _importWarnings.where((w) => w.severity == 'error').toList();
    final warnings =
        _importWarnings.where((w) => w.severity == 'warning').toList();
    final infos = _importWarnings.where((w) => w.severity == 'info').toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: errors.isNotEmpty
            ? Colors.red.shade50
            : warnings.isNotEmpty
                ? Colors.amber.shade50
                : Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: errors.isNotEmpty
              ? Colors.red.shade200
              : warnings.isNotEmpty
                  ? Colors.amber.shade200
                  : Colors.green.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                errors.isNotEmpty
                    ? Icons.error_outline
                    : warnings.isNotEmpty
                        ? Icons.warning_amber
                        : Icons.check_circle_outline,
                size: 16,
                color: errors.isNotEmpty
                    ? Colors.red.shade700
                    : warnings.isNotEmpty
                        ? Colors.amber.shade700
                        : Colors.green.shade700,
              ),
              const SizedBox(width: 8),
              Text(
                'Import Warnings',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: errors.isNotEmpty
                          ? Colors.red.shade900
                          : warnings.isNotEmpty
                              ? Colors.amber.shade900
                              : Colors.green.shade900,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Errors
          if (errors.isNotEmpty) ...[
            Text(
              '❌ ${errors.length} error(s)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red.shade900,
              ),
            ),
            ...errors.take(3).map((w) => _buildWarningItem(w)),
            if (errors.length > 3)
              Text(
                '   ... and ${errors.length - 3} more',
                style: TextStyle(fontSize: 12, color: Colors.red.shade700),
              ),
            const SizedBox(height: 8),
          ],

          // Warnings
          if (warnings.isNotEmpty) ...[
            Text(
              '⚠️ ${warnings.length} warning(s)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.amber.shade900,
              ),
            ),
            ...warnings.take(3).map((w) => _buildWarningItem(w)),
            if (warnings.length > 3)
              Text(
                '   ... and ${warnings.length - 3} more',
                style: TextStyle(fontSize: 12, color: Colors.amber.shade700),
              ),
            const SizedBox(height: 8),
          ],

          // Infos
          if (infos.isNotEmpty)
            Text(
              'ℹ️ ${infos.length} informational note(s)',
              style: TextStyle(
                fontSize: 13,
                color: Colors.blue.shade900,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWarningItem(ImportWarning warning) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 4),
      child: Text(
        '• ${warning.message}',
        style: const TextStyle(fontSize: 12),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  List<String> _getCompatibilityWarnings() {
    final warnings = <String>[];

    switch (_selectedFormat) {
      case ImportFormat.ai:
        warnings.add(
          'AI import uses PDF layer only. Illustrator-specific features (effects, live paint, symbols) are not supported.',
        );
        warnings.add(
          'Tier-1: Full support for basic paths (moveto, lineto, curveto, closepath, rectangle).',
        );
        warnings.add(
          'Tier-2: Gradients converted to solid fills. CMYK colors converted to RGB.',
        );
        warnings.add(
          'Tier-3: Text objects skipped. Convert text to outlines in Illustrator before importing.',
        );
        break;

      case ImportFormat.svg:
        warnings.add(
          'SVG import is not yet implemented. Coming in Milestone 0.2.',
        );
        break;

      case ImportFormat.pdf:
        warnings.add(
          'PDF import is not yet implemented. Coming in Milestone 0.2.',
        );
        break;
    }

    return warnings;
  }

  Future<void> _handleSelectFile() async {
    // TODO: Implement file picker using platform-specific APIs
    // For now, this is a placeholder that demonstrates the pattern
    // In production, this would use file_selector package or platform channels
    throw UnimplementedError(
      'File picker not yet implemented. '
      'This requires integration with platform file I/O services.',
    );
  }

  Future<void> _handleImport() async {
    if (_selectedFilePath == null) {
      _showError('Please select a file to import.');
      return;
    }

    setState(() {
      _isImporting = true;
      _importWarnings.clear();
    });

    try {
      final result = await _performImport(_selectedFilePath!);
      if (mounted) {
        setState(() {
          _importWarnings = result.warnings.toList();
          _isImporting = false;
        });

        // Show success message
        _showSuccess(
          'Import completed: ${result.events.length} events generated, '
          '${result.warnings.length} warnings',
        );

        // Close dialog and return result after a short delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pop(result);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
        _showError('Import failed: $e');
      }
    }
  }

  Future<ImportResult> _performImport(String filePath) async {
    switch (_selectedFormat) {
      case ImportFormat.ai:
        return await _importAi(filePath);

      case ImportFormat.svg:
        throw UnimplementedError('SVG import not yet implemented');

      case ImportFormat.pdf:
        throw UnimplementedError('PDF import not yet implemented');
    }
  }

  Future<ImportResult> _importAi(String filePath) async {
    final importer = AIImporter();

    // Read file bytes
    // Note: In production, this would use proper file I/O abstraction
    // For now, we'll use a placeholder that demonstrates the pattern
    final fileBytes = await _readFileBytes(filePath);

    final aiResult = await importer.importFromBytes(
      fileBytes,
      fileName: _getFileName(filePath),
    );

    return ImportResult(
      format: ImportFormat.ai,
      events: aiResult.events,
      warnings: aiResult.warnings,
      metadata: ImportMetadata(
        sourceFile: filePath,
        pageCount: aiResult.metadata.pageCount,
        pageWidth: aiResult.metadata.pageWidth,
        pageHeight: aiResult.metadata.pageHeight,
      ),
    );
  }

  Future<Uint8List> _readFileBytes(String filePath) async {
    // TODO: Implement proper file reading using platform-specific APIs
    // For now, throw to indicate implementation needed
    throw UnimplementedError(
      'File reading not yet implemented. '
      'This requires integration with platform file I/O services.',
    );
  }

  String _getFileName(String path) {
    return path.split('/').last.split('\\').last;
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

/// Available import formats.
enum ImportFormat {
  ai('ai'),
  svg('svg'),
  pdf('pdf');

  const ImportFormat(this.extension);
  final String extension;
}

/// Result of an import operation.
class ImportResult {
  const ImportResult({
    required this.format,
    required this.events,
    required this.warnings,
    required this.metadata,
  });

  final ImportFormat format;
  final List<Map<String, dynamic>> events;
  final List<ImportWarning> warnings;
  final ImportMetadata metadata;
}

/// Metadata about the imported file.
class ImportMetadata {
  const ImportMetadata({
    required this.sourceFile,
    required this.pageCount,
    required this.pageWidth,
    required this.pageHeight,
  });

  final String sourceFile;
  final int pageCount;
  final double pageWidth;
  final double pageHeight;
}
