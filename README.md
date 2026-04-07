# Clean Screen

Raycast extension plus native macOS helper for temporarily locking the keyboard and showing a dark cleaning screen while you clean your display.

When launched from Raycast, it:

- covers every display with a pure black overlay
- shows an `End Cleaning Session` button in the center of the primary screen
- blocks keyboard input while the session is active
- keeps mouse input available so you can end the session by clicking
- keeps emergency fallback shortcut: `Control-U`

It is designed to bring the functionality of existing standalone keyboard-cleaning tools into a Raycast workflow.

## Project Layout

- `src/index.ts`: Raycast command entry point with dynamic Swift compilation
- `assets/clean-screen-helper/`: Swift package source code for the native overlay helper

## Requirements

- macOS 13+
- Raycast
- Node.js and npm for Raycast extension development
- Swift / Xcode Command Line Tools (for automatic compilation)
- Accessibility permission when the helper launches

## Build

The Swift helper is automatically compiled on first run and when source files change.

```bash
cd clean-screen
npm install
npm run dev
```

Then open Raycast and run `Start Cleaning Session`. The extension will build the Swift helper automatically on first launch.

## Publishing Checklist

- Run `npm install` so `package-lock.json` is generated.
- Run `npm run build` to validate the extension.
- Run `npm run publish` to submit it to Raycast.

## Notes

- Keyboard blocking on macOS is permission-sensitive. Users must grant Accessibility access to `CleanScreenHelper.app` on first use.
- Some hardware or system-level keys may still bypass the blocker depending on macOS behavior.
