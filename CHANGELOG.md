# Changelog

## [2.1.4] 2026-10-03
- chore: add missing mod thumbnail

## [2.1.3] 2026-10-03
- fix: re-disable debug logging

## [2.1.2] 2026-10-03
- feat: add user-submitted RU translation and two LLM-made translations (FR, DE)

## [2.1.1] 2026-10-03
### Fixed
- Right-drag destruction now removes wall ghosts by default, plus other player-placeable entity ghosts when "Destroy buildings" is enabled.
- Right-drag destruction now includes the bottom and right edges of cursor-coordinate selections.
- Shift+right-drag destruction now uses the alternate wall thickness.

## [2.1.0] - 2026-09-30
### Added
- Undo support: ghost placement and deconstruction marks made with the tool are grouped per drag and can be undone with Ctrl+Z (trees/rocks are not restorable by the game, same as with the vanilla deconstruction planner).
- Destruction mode: right-click-drag with the tool marks trees/rocks (and with the "Destroy buildings" setting, default on, also player-built entities) for deconstruction only inside the exact wall footprint, without placing new wall ghosts.

### Changed
- Shift+drag now builds walls with the alternate thickness (it previously shared the normal selection); right-drag is the destructive clear.

### Fixed
- Wall ghosts are now placed on wall tiles whose trees/rocks are being cleared. A build-check value that was removed back in Factorio 1.1.6 had been left in place, so the ghost placement test failed whenever anything stood on the wall tile and those spots were silently skipped. Each spot is now decided from the entities that really overlap that one tile, and only entity types that can actually obstruct a wall count - so a robot flying over the line, the character, or an item on the ground no longer leaves a hole in it. A spot holding anything this drag will not clear (a building during left-drag) is skipped rather than ghosted, and no bot is ever left hovering over a blocked build.

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
