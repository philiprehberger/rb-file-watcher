# frozen_string_literal: true

require 'mutex_m'

module Philiprehberger
  module FileWatcher
    # Watches file system paths for changes using polling.
    #
    # Detects created, modified, and deleted files by comparing mtime snapshots
    # at a configurable interval.
    class Watcher
      # @param paths [Array<String>, String] directories or files to watch
      # @param interval [Float] polling interval in seconds (default: 1.0)
      # @param glob [String] glob pattern for matching files (default: "**/*")
      def initialize(paths, interval: 1.0, glob: '**/*')
        @paths = Array(paths)
        @interval = interval
        @glob = glob
        @callbacks = { created: [], modified: [], deleted: [], any: [] }
        @mutex = Mutex.new
        @thread = nil
        @running = false
        @snapshot = {}
      end

      # Register a callback for a specific change type.
      #
      # @param type [Symbol] one of :created, :modified, :deleted, or :any
      # @yield [Change] called when a matching change is detected
      # @return [self]
      # @raise [ArgumentError] if the type is not valid
      def on(type, &block)
        unless @callbacks.key?(type)
          raise ArgumentError,
                "invalid event type: #{type.inspect} (must be one of #{@callbacks.keys.join(', ')})"
        end

        @mutex.synchronize { @callbacks[type] << block }
        self
      end

      # Start watching in a background thread.
      #
      # Takes an initial snapshot and begins polling for changes.
      #
      # @return [self]
      def start
        @mutex.synchronize do
          return self if @running

          @running = true
          @snapshot = take_snapshot
          @thread = Thread.new { poll_loop }
        end
        self
      end

      # Stop the watcher and join the background thread.
      #
      # @return [self]
      def stop
        @mutex.synchronize { @running = false }
        @thread&.join
        @thread = nil
        self
      end

      # @return [Boolean] true if the watcher is currently running
      def running?
        @mutex.synchronize { @running }
      end

      private

      def poll_loop
        while running?
          sleep @interval
          next unless running?

          changes = detect_changes
          fire_callbacks(changes) unless changes.empty?
        end
      end

      def detect_changes
        current = take_snapshot
        @mutex.synchronize do
          changes = diff_snapshots(@snapshot, current)
          @snapshot = current
          changes
        end
      end

      def diff_snapshots(previous, current)
        changes = current.map do |path, mtime|
          if previous.key?(path)
            Change.new(path, :modified) if mtime != previous[path]
          else
            Change.new(path, :created)
          end
        end
        previous.each_key { |path| changes << Change.new(path, :deleted) unless current.key?(path) }
        changes.compact
      end

      def take_snapshot
        @paths.each_with_object({}) do |base_path, snapshot|
          expanded = File.expand_path(base_path)
          if File.file?(expanded)
            snapshot[expanded] = File.mtime(expanded)
          elsif File.directory?(expanded)
            scan_directory(expanded, snapshot)
          end
        end
      end

      def scan_directory(dir, snapshot)
        Dir.glob(File.join(dir, @glob)).each do |file|
          next unless File.file?(file)

          snapshot[file] = File.mtime(file)
        end
      end

      def fire_callbacks(changes)
        changes.each do |change|
          @mutex.synchronize do
            @callbacks[change.type].each { |cb| cb.call(change) }
            @callbacks[:any].each { |cb| cb.call(change) }
          end
        end
      end
    end
  end
end
