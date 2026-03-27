# philiprehberger-file_watcher

[![Tests](https://github.com/philiprehberger/rb-file-watcher/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-file-watcher/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-file_watcher.svg)](https://rubygems.org/gems/philiprehberger-file_watcher)
[![License](https://img.shields.io/github/license/philiprehberger/rb-file-watcher)](LICENSE)
[![Sponsor](https://img.shields.io/badge/sponsor-GitHub%20Sponsors-ec6cb9)](https://github.com/sponsors/philiprehberger)

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

### Catch-All Callback

```ruby
require "philiprehberger/file_watcher"

watcher = Philiprehberger::FileWatcher::Watcher.new("./app")
watcher.on(:any) { |change| puts change }
watcher.start
```

### Custom Glob Patterns

```ruby
require "philiprehberger/file_watcher"

# Only watch Ruby files
watcher = Philiprehberger::FileWatcher::Watcher.new("./lib", glob: "**/*.rb")
watcher.on(:any) { |change| puts change }
watcher.start
```

## API

### `FileWatcher.watch(paths, interval:, glob:, &block)`

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `paths` | `String`, `Array<String>` | required | Directories or files to watch |
| `interval` | `Float` | `1.0` | Polling interval in seconds |
| `glob` | `String` | `"**/*"` | Glob pattern for matching files |
| `&block` | `Block` | required | Called with each `Change` object |

Blocking method. Stops on `Interrupt` (Ctrl+C).

### `FileWatcher::Watcher`

| Method | Description |
|--------|-------------|
| `.new(paths, interval: 1.0, glob: "**/*")` | Create a new watcher instance |
| `#on(type, &block)` | Register a callback for `:created`, `:modified`, `:deleted`, or `:any` |
| `#start` | Start watching in a background thread |
| `#stop` | Stop watching and join the thread |
| `#running?` | Returns `true` if the watcher is active |

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

## License

[MIT](LICENSE)
