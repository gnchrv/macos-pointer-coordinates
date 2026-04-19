# Pointer Coordinates

A lightweight macOS menu bar app that displays the current cursor position as a floating label next to the pointer. Coordinates match those shown by the native macOS screenshot tool — origin at the top-left corner of the main screen.

The label adapts to light and dark mode and stays visible on any background via a blurred, translucent pill.

## Usage

The app lives in the menu bar. Click the icon to quit.

## Command Line

### Build and launch

Compiles the app from source, stops any already-running instance, and launches the result.

```bash
bash build.sh
```

### Launch

Starts the pre-built app without recompiling.

```bash
open PointerCoordinates.app
```

### Stop

Terminates the running app process by its exact binary name.

```bash
pkill -x PointerCoordinates
```

### Toggle

Checks whether the app is currently running and either stops it or starts it accordingly. Useful for binding to a keyboard shortcut or a shell alias.

```bash
if pgrep -x PointerCoordinates > /dev/null; then
    pkill -x PointerCoordinates
else
    open /path/to/PointerCoordinates.app
fi
```
