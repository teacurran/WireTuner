# T018: Tool Framework

## Status
- **Phase**: 4 - Tool System
- **Priority**: Critical
- **Estimated Effort**: 1 day
- **Dependencies**: T014

## Overview
Create the tool system architecture for handling different drawing and editing tools.

## Objectives
- Base Tool interface
- ToolManager for active tool management
- Tool lifecycle (activate, deactivate, handle events)
- Tool state management

## Implementation
```dart
abstract class Tool {
  String get name;
  IconData get icon;

  void onActivate();
  void onDeactivate();
  void onTapDown(TapDownDetails details, ViewportTransform viewport);
  void onTapUp(TapUpDetails details, ViewportTransform viewport);
  void onDragStart(DragStartDetails details, ViewportTransform viewport);
  void onDragUpdate(DragUpdateDetails details, ViewportTransform viewport);
  void onDragEnd(DragEndDetails details, ViewportTransform viewport);
}

class ToolManager extends ChangeNotifier {
  Tool? _activeTool;
  Tool? get activeTool => _activeTool;

  void setTool(Tool tool) {
    _activeTool?.onDeactivate();
    _activeTool = tool;
    _activeTool?.onActivate();
    notifyListeners();
  }
}
```

## Success Criteria
- [ ] Can switch between tools
- [ ] Tools receive gesture events
- [ ] Tool state persists during usage

## References
- Dissipate tools: `/Users/tea/dev/github/dissipate/lib/models/drawing_tool.dart`
