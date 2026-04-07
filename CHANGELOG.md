## [Unreleased]

### Changed
- Replaced precompiled binary with dynamic Swift compilation for better compatibility and security
- Swift helper now builds automatically on first run and when source files change
- Removed `build:helper` npm script - no manual compilation needed
- Removed double-Escape exit mechanism to prevent accidental exits

### Fixed
- Resolved Raycast Store requirement to use source code instead of precompiled binaries

## [Initial Release] - {PR_MERGE_DATE}

- Initial release of Clean Screen.
- Adds a dark fullscreen cleaning mode for display cleaning.
- Temporarily blocks keyboard input while keeping mouse interaction enabled.
- Includes an Accessibility permission setup flow and emergency exit with `Control-U`.
