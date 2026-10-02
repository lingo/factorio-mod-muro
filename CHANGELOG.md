# Changelog

## [2.1.0] - 2026-09-30
### Added
- Undo support: ghost placement and deconstruction marks made with the tool are grouped per drag and can be undone with Ctrl+Z (trees/rocks are not restorable by the game, same as with the vanilla deconstruction planner).
- Destruction mode: right-click-drag with the tool clears and rebuilds the wall line: marks trees/rocks (and with the "Destroy buildings" setting, default on, also player-built entities) for deconstruction — but only inside the exact wall footprint, not the whole dragged rectangle — then lays the wall ghosts over the same spots.

### Changed
- Shift+drag now builds walls with the alternate thickness (it previously shared the normal selection); right-drag is the destructive clear.

## [2.0.0] - 2026-09-30
### Changed
Updated for Factorio 2.0: selection tool prototype now uses `select`/`alt_select` mode tables, and entity-ghost creation no longer passes the removed `type` field.

### Fixed
- Removed debug logging that was always enabled.
- Localized accidental global variables (wall geometry, settings lookup) that could misbehave in multiplayer.
- Fixed a crash when placing ghost walls with the deconstruction setting disabled.

## [1.0.3] - 2020-02-29
### Changed
Updated requirements to allow 0.18.x

## [1.0.1] - 2018-03-18
### Removed
- debug logging and obsolete code

## [1.0.0] - 2018-03-17
### Added
- Option for deconstructing trees/rocks etc. in ghost mode

### Changed
- Refactored code to OO-style

### Fixed
- Wall generation bugs fixed when using wall thickness greater than one.

## [0.0.2] - 2018-03-16
### Added
- feature to draw walls directly instead of using ghosts
- option to set wall thickness
