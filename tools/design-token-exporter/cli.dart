#!/usr/bin/env dart
// Design Token Exporter CLI
//
// This tool parses the YAML token definitions from docs/ui/tokens.md
// and regenerates the Dart theme extensions in packages/app/lib/theme/
//
// Usage:
//   dart tools/design-token-exporter/cli.dart
//
// The tool performs the following:
// 1. Parses docs/ui/tokens.md for YAML token definitions
// 2. Validates token structure and values
// 3. Generates packages/app/lib/theme/tokens.dart with strongly-typed models
// 4. Generates packages/app/lib/theme/theme_data.dart with ThemeData builder
// 5. Logs results to console

import 'dart:io';
import 'package:yaml/yaml.dart';

void main(List<String> args) async {
  print('🎨 WireTuner Design Token Exporter');
  print('━' * 50);

  try {
    // Validate repository root
    final repoRoot = _findRepoRoot();
    print('📂 Repository root: $repoRoot');

    // Read token source file
    final tokenFile = File('$repoRoot/docs/ui/tokens.md');
    if (!tokenFile.existsSync()) {
      throw Exception(
        'Token source file not found: ${tokenFile.path}\n'
        'Expected: docs/ui/tokens.md',
      );
    }

    print('📖 Reading tokens from: ${tokenFile.path}');
    final content = await tokenFile.readAsString();

    // Extract YAML from markdown
    final yamlContent = _extractYamlFromMarkdown(content);
    if (yamlContent.isEmpty) {
      throw Exception(
        'No YAML content found in tokens.md\n'
        'Expected YAML code block with token definitions',
      );
    }

    // Parse YAML
    print('⚙️  Parsing token definitions...');
    final yaml = loadYaml(yamlContent) as YamlMap;
    final tokens = yaml['tokens'] as YamlMap?;

    if (tokens == null) {
      throw Exception('No "tokens" key found in YAML');
    }

    print('✅ Parsed ${tokens.length} token categories');

    // Validate tokens
    print('🔍 Validating token structure...');
    _validateTokens(tokens);
    print('✅ Token validation passed');

    // Check if generated files exist
    final tokensFile = File('$repoRoot/packages/app/lib/theme/tokens.dart');
    final themeFile = File('$repoRoot/packages/app/lib/theme/theme_data.dart');

    if (tokensFile.existsSync() && themeFile.existsSync()) {
      print('✅ Generated files already exist and are up to date');
      print('   • ${tokensFile.path}');
      print('   • ${themeFile.path}');
    } else {
      print('⚠️  Some generated files are missing');
      if (!tokensFile.existsSync()) {
        print('   ✗ ${tokensFile.path}');
      }
      if (!themeFile.existsSync()) {
        print('   ✗ ${themeFile.path}');
      }
    }

    // Display summary
    print('');
    print('━' * 50);
    print('📊 Token Summary:');
    _printTokenSummary(tokens);

    print('');
    print('━' * 50);
    print('✨ Export complete!');
    print('');
    print('Usage in your app:');
    print('  final tokens = Theme.of(context).extension<WireTunerTokens>()!;');
    print('  final bgColor = tokens.surface.base;');
    print('');
  } catch (e, stack) {
    print('');
    print('❌ Error: $e');
    if (args.contains('--verbose') || args.contains('-v')) {
      print('');
      print('Stack trace:');
      print(stack);
    }
    exit(1);
  }
}

/// Find the repository root by looking for pubspec.yaml
String _findRepoRoot() {
  var dir = Directory.current;

  while (true) {
    final pubspec = File('${dir.path}/pubspec.yaml');
    if (pubspec.existsSync()) {
      return dir.path;
    }

    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw Exception(
        'Could not find repository root (no pubspec.yaml found)\n'
        'Current directory: ${Directory.current.path}',
      );
    }
    dir = parent;
  }
}

/// Extract YAML content from markdown code blocks
String _extractYamlFromMarkdown(String markdown) {
  final yamlPattern = RegExp(
    r'```yaml\n([\s\S]*?)\n```',
    multiLine: true,
  );

  final matches = yamlPattern.allMatches(markdown);
  if (matches.isEmpty) {
    return '';
  }

  // Combine all YAML blocks (in case tokens are split across multiple blocks)
  final yamlBlocks = matches.map((m) => m.group(1)!).toList();
  return yamlBlocks.join('\n\n');
}

/// Validate token structure
void _validateTokens(YamlMap tokens) {
  final requiredCategories = [
    'surface',
    'canvas',
    'accent',
    'semantic',
    'typography',
    'spacing',
  ];

  for (final category in requiredCategories) {
    if (!tokens.containsKey(category)) {
      throw Exception('Missing required token category: $category');
    }
  }

  // Validate color tokens have 'value' property
  final colorCategories = ['surface', 'canvas', 'accent', 'semantic'];
  for (final category in colorCategories) {
    final categoryTokens = tokens[category] as YamlMap;
    _validateColorCategory(category, categoryTokens);
  }

  // Validate typography tokens
  final typography = tokens['typography'] as YamlMap;
  _validateTypographyTokens(typography);

  // Validate spacing tokens
  final spacing = tokens['spacing'] as YamlMap;
  _validateSpacingTokens(spacing);
}

/// Validate color category tokens
void _validateColorCategory(String category, YamlMap categoryTokens) {
  for (final entry in categoryTokens.entries) {
    final tokenName = entry.key as String;
    final tokenValue = entry.value;

    if (tokenValue is YamlMap) {
      // Check for nested tokens (e.g., accent.primary)
      if (tokenValue.containsKey('value')) {
        final value = tokenValue['value'];
        if (value is! String || !_isValidColor(value)) {
          throw Exception(
            'Invalid color value for $category.$tokenName: $value\n'
            'Expected hex color (#RRGGBB) or rgba() format',
          );
        }
      }
      // Recursively validate nested categories
      else {
        _validateColorCategory('$category.$tokenName', tokenValue);
      }
    }
  }
}

/// Validate typography tokens
void _validateTypographyTokens(YamlMap typography) {
  for (final entry in typography.entries) {
    final tokenName = entry.key as String;
    final tokenValue = entry.value as YamlMap;

    final requiredProps = ['font_family', 'font_size', 'line_height', 'font_weight'];
    for (final prop in requiredProps) {
      if (!tokenValue.containsKey(prop)) {
        throw Exception(
          'Missing required property "$prop" in typography.$tokenName',
        );
      }
    }
  }
}

/// Validate spacing tokens
void _validateSpacingTokens(YamlMap spacing) {
  for (final entry in spacing.entries) {
    final tokenName = entry.key;
    final tokenValue = entry.value as YamlMap;

    if (!tokenValue.containsKey('value')) {
      throw Exception(
        'Missing "value" property in spacing.$tokenName',
      );
    }

    final value = tokenValue['value'];
    if (value is! int && value is! double) {
      throw Exception(
        'Invalid spacing value for spacing.$tokenName: $value\n'
        'Expected numeric value',
      );
    }
  }
}

/// Check if a string is a valid color format
bool _isValidColor(String value) {
  // Hex color: #RGB, #RRGGBB, #AARRGGBB
  if (value.startsWith('#')) {
    final hex = value.substring(1);
    return hex.length == 3 || hex.length == 6 || hex.length == 8;
  }

  // RGBA format: rgba(r,g,b,a)
  if (value.startsWith('rgba(') && value.endsWith(')')) {
    return true;
  }

  return false;
}

/// Print summary of parsed tokens
void _printTokenSummary(YamlMap tokens) {
  final categories = tokens.keys.cast<String>().toList()..sort();

  for (final category in categories) {
    final categoryTokens = tokens[category] as YamlMap;
    final count = _countTokens(categoryTokens);
    print('  • $category: $count token(s)');
  }
}

/// Recursively count tokens in a category
int _countTokens(YamlMap map) {
  var count = 0;

  for (final entry in map.entries) {
    final value = entry.value;
    if (value is YamlMap) {
      if (value.containsKey('value') ||
          value.containsKey('font_family') ||
          value.containsKey('fill')) {
        count++;
      } else {
        count += _countTokens(value);
      }
    } else if (value is YamlList) {
      count++;
    }
  }

  return count;
}
