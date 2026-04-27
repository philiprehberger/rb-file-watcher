# philiprehberger-file_watcher

[![Tests](https://github.com/philiprehberger/rb-file-watcher/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-file-watcher/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-file_watcher.svg)](https://rubygems.org/gems/philiprehberger-file_watcher)
[![Last updated](https://img.shields.io/github/last-commit/philiprehberger/rb-file-watcher)](https://github.com/philiprehberger/rb-file-watcher/commits/main)

File system change detection with polling and callbacks

## Requirements

- Ruby >= 3.1

## Installation

Add to your Gemfile:

```ruby
gem "philiprehberger-file_watcher"
```

Or install directly:

```bash
gem install philiprehberger-file_watcher
```

## Usage

```ruby
require "philiprehberger/file_watcher"

# Block-based watching (blocking, Ctrl+C to stop)
Philiprehberger::FileWatcher.watch("./src", interval: 0.5, glob: "**/*.rb") do |change|
  puts "#{change.type}: #{change.path}"
end
```

### Watcher Instance

```ruby
require "philiprehberger/file_watcher"

watcher = Philiprehberger::FileWatcher::Watcher.new(
  ["./src", "./lib"],
  interval: 1.0,
  glob: "**/*"
)

watcher.on(:created)  { |change| puts "Created: #{change.path}" }
watcher.on(:modified) { |change| puts "Modified: #{change.path}" }
watcher.on(:deleted)  { |change| puts "Deleted: #{change.path}" }

watcher.start
# ... do other work ...
watcher.stop
```

### Exclusion Patterns

```ruby
require "philiprehberger/file_watcher"

watcher = Philiprehberger::FileWatcher::Watcher.new(
  "./src",
  glob: "**/*",
  exclude: ["**/*.log", "**/tmp/**"]
)
watcher.on(:any) { |change| puts change }
watcher.start
```

### Change Debouncing

```ruby
require "philiprehberger/file_watcher"

# Only fire after 0.5 seconds of inactivity per file
watcher = Philiprehberger::FileWatcher::Watcher.new("./src", debounce: 0.5)
watcher.on(:modified) { |change| puts "Settled: #{change.path}" }
watcher.start
```

### Batch Change Reporting

```ruby
require "philiprehberger/file_watcher"

watcher = Philiprehberger::FileWatcher::Watcher.new("./src", interval: 1.0)
watcher.on(:batch) { |changes| puts "#{changes.size} files changed" }
watcher.start
```

### Error Handling

```ruby
require "philiprehberger/file_watcher"

watcher = Philiprehberger::FileWatcher::Watcher.new("./src")
watcher.on(:error) { |exception, path| warn "Error on #{path}: #{exception.message}" }
watcher.on(:any) { |change| puts change }
watcher.start
```

### Pause and Resume

```ruby
require "philiprehberger/file_watcher"

watcher = Philiprehberger::FileWatcher::Watcher.new("./src", interval: 0.5)
watcher.on(:any) { |change| puts change }
watcher.start

# Pause during bulk operations to avoid a flood of events
watcher.pause

FileUtils.cp_r("./backup", "./src")

# Resume with a fresh snapshot — changes during pause are ignored
watcher.resume
```

### Snapshot

```ruby
require "philiprehberger/file_watcher"

watcher = Philiprehberger::FileWatcher::Watcher.new("./src")
watcher.start

snapshot = watcher.snapshot
snapshot.each do |path, info|
  puts "#{path}: mtime=#{info[:mtime]}, size=#{info[:size]}"
end
```

### Stats

```ruby
require "philiprehberger/file_watcher"

watcher = Philiprehberger::FileWatcher::Watcher.new("./src")
watcher.start

stats = watcher.stats
# => { tracked_files: 42, total_changes: 7, last_change_at: 2026-04-26 12:00:00 +0000 }
```

## API

### `FileWatcher.watch(paths, interval:, glob:, exclude:, debounce:, &block)`

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `paths` | `String`, `Array<String>` | required | Directories or files to watch |
| `interval` | `Float` | `1.0` | Polling interval in seconds |
| `glob` | `String` | `"**/*"` | Glob pattern for matching files |
| `exclude` | `Array<String>` | `[]` | Glob patterns to exclude from watching |
| `debounce` | `Float`, `nil` | `nil` | Debounce interval in seconds |
| `&block` | `Block` | required | Called with each `Change` object |

Blocking method. Stops on `Interrupt` (Ctrl+C).

### `FileWatcher::Watcher`

| Method | Description |
|--------|-------------|
| `.new(paths, interval: 1.0, glob: "**/*", exclude: [], debounce: nil)` | Create a new watcher instance |
| `#on(type, &block)` | Register a callback for `:created`, `:modified`, `:deleted`, `:any`, `:error`, or `:batch` |
| `#start` | Start watching in a background thread |
| `#stop` | Stop watching and join the thread |
| `#running?` | Returns `true` if the watcher is active |
| `#pause` | Pause change detection; polling thread stays alive |
| `#resume` | Resume change detection with a fresh snapshot |
| `#paused?` | Returns `true` if the watcher is currently paused |
| `#snapshot` | Returns a hash of `{path => {mtime:, size:}}` for all tracked files |
| `#stats` | Returns a hash with `:tracked_files`, `:total_changes`, and `:last_change_at` |

### `FileWatcher::Change`

| Method | Description |
|--------|-------------|
| `#path` | Absolute path to the changed file |
| `#type` | Change type: `:created`, `:modified`, or `:deleted` |
| `#to_s` | Human-readable string, e.g. `"created: /path/to/file.rb"` |

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## Support

If you find this project useful:

⭐ [Star the repo](https://github.com/philiprehberger/rb-file-watcher)

🐛 [Report issues](https://github.com/philiprehberger/rb-file-watcher/issues?q=is%3Aissue+is%3Aopen+label%3Abug)

💡 [Suggest features](https://github.com/philiprehberger/rb-file-watcher/issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement)

❤️ [Sponsor development](https://github.com/sponsors/philiprehberger)

🌐 [All Open Source Projects](https://philiprehberger.com/open-source-packages)

💻 [GitHub Profile](https://github.com/philiprehberger)

🔗 [LinkedIn Profile](https://www.linkedin.com/in/philiprehberger)

## License

[MIT](LICENSE)
