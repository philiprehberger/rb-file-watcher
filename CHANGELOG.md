# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
