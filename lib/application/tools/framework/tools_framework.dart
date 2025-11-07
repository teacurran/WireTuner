/// Tool Framework - Extensible tool system for WireTuner
///
/// This library provides the core infrastructure for implementing interactive
/// tools in the WireTuner vector drawing application.
///
/// ## Components
///
/// - [ITool]: Abstract interface that all tools must implement
/// - [ToolManager]: Central orchestrator for tool lifecycle and event routing
/// - [CursorService]: Service for managing mouse cursor state
///
/// ## Usage
///
/// ```dart
/// import 'package:wiretuner/application/tools/framework/tools_framework.dart';
///
/// // Create services
/// final cursorService = CursorService();
/// final toolManager = ToolManager(
///   cursorService: cursorService,
///   eventRecorder: eventRecorder,
/// );
///
/// // Register tools
/// toolManager.registerTool(MyTool());
///
/// // Activate a tool
/// toolManager.activateTool('my_tool');
/// ```
///
/// See README.md in this directory for detailed documentation.
library tools_framework;

export 'cursor_service.dart';
export 'tool_interface.dart';
export 'tool_manager.dart';
