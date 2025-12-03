# OG-TargetTool

Improved targeting utilities for Turtle WoW (World of Warcraft 1.12 client).

## Features

### Simple Toggle (2 Targets)
- Quickly toggle between your last two targets
- Keybind: **Target Last Target**

### Target Pool System (2-10 Targets)
- Track up to 10 targets in a circular pool
- Cycle backward through your target history: **Target Last Pool Target**
- Cycle forward through your target history: **Target Next Pool Target**
- Adjust pool size on the fly with keybinds or the widget

### On-Screen Widget
- Draggable UI widget to display and adjust pool size
- +/- buttons to change pool size (2-10 targets)
- Toggle widget visibility with `/ott widget` or minimap menu
- Lock/unlock widget position
- Show/hide +/- buttons
- Widget remembers position and visibility across sessions

### Minimap Button
- Convenient minimap button with "TT" overlay
- Right-click to open configuration menu
- Draggable around the minimap edge

## Installation

1. Download or clone this repository
2. Place the `OG-TargetTool` folder in your `Interface\AddOns` directory
3. Restart WoW or reload UI (`/reload`)

## Dependencies

**Required:**
- World of Warcraft 1.12 client (Vanilla)
- Turtle WoW server with SuperWoW extensions

**SuperWoW API Used:**
- `UnitExists(unit)` - Returns `(exists, guid)` for GUID-based targeting
- `TargetUnit(guid)` - Targets units by GUID instead of name

## Keybinds

Configure keybindings in **ESC Menu → Key Bindings → OG-TargetTool**:

- **Target Last Target** - Toggle between last 2 targets (simple mode)
- **Target Last Pool Target** - Cycle backward through target pool
- **Target Next Pool Target** - Cycle forward through target pool
- **Increase Pool Size** - Increase pool size (2-10)
- **Decrease Pool Size** - Decrease pool size (2-10)

## Slash Commands

- `/ott widget` - Toggle widget visibility
- `/ott reset` - Reset widget position to center of screen
- `/ott <number>` - Set pool size (2-10)

## Configuration

Right-click the minimap button or use slash commands to:
- Show/hide the widget
- Show/hide +/- buttons on widget
- Lock/unlock widget position

All settings persist across sessions and reloads.

## How It Works

### Target Tracking
- Automatically captures your target each time it changes (PLAYER_TARGET_CHANGED event)
- Stores target GUIDs in a circular pool
- Pool maintains most recent targets up to configured size
- Simple toggle system maintains last 2 targets separately

### GUID-Based Targeting
- Uses SuperWoW's GUID system for reliable targeting
- Targets work even when units have identical names
- Handles target validity checking automatically

## Technical Details

- **Client:** WoW 1.12 (Vanilla)
- **Lua Version:** 5.0
- **Server:** Turtle WoW
- **SavedVariables:** `OGTT_Settings`
- **Event System:** ADDON_LOADED, PLAYER_TARGET_CHANGED

## Known Limitations

- Pool only tracks units you've actually targeted
- Dead or despawned units remain in pool until cycled out
- Requires SuperWoW for GUID-based targeting

## Author

Tankmedady

## Version

1.0

## License

Feel free to modify and distribute.
