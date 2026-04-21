# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-04-10

### Added

- Pause and resume support via `Watcher#pause`, `Watcher#resume`, and `Watcher#paused?`
- Changes that occur while paused are silently ignored on resume

## [0.2.1] - 2026-03-31

### Changed
- Standardize README badges, support section, and license format

## [0.2.0] - 2026-03-28

### Added

- Exclusion patterns via `exclude:` option to filter out files matching glob patterns
- Change debouncing via `debounce:` option to coalesce rapid consecutive changes
- Error callback via `on(:error)` for graceful handling of filesystem errors
- Snapshot method `Watcher#snapshot` returning tracked files with mtime and size
- Batch change reporting via `on(:batch)` callback receiving all changes per polling cycle

## [0.1.1] - 2026-03-26

### Added

- Add GitHub funding configuration

## [0.1.0] - 2026-03-26

### Added
- Initial release
- `FileWatcher.watch` convenience method for blocking file watching
- `Watcher` class with background thread polling
- `Change` value object with path and type attributes
- Detection of created, modified, and deleted files via mtime snapshots
- Configurable polling interval and glob patterns
- Event callbacks for `:created`, `:modified`, `:deleted`, and `:any`
- Thread-safe operation with Mutex
