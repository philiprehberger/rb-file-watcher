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
      # @param exclude [Array<String>] glob patterns to exclude from watching (default: [])
      # @param debounce [Float, nil] debounce interval in seconds (default: nil)
      def initialize(paths, interval: 1.0, glob: '**/*', exclude: [], debounce: nil)
        @paths = Array(paths)
        @interval = interval
        @glob = glob
        @exclude = Array(exclude)
        @debounce = debounce
        @callbacks = { created: [], modified: [], deleted: [], any: [], error: [], batch: [] }
        @mutex = Mutex.new
        @thread = nil
        @running = false
        @paused = false
        @snapshot = {}
        @pending_debounce = {}
      end

      # Register a callback for a specific change type.
      #
      # @param type [Symbol] one of :created, :modified, :deleted, :any, :error, or :batch
      # @yield [Change] called when a matching change is detected
      # @yield [Exception, String] for :error, called with (exception, path)
      # @yield [Array<Change>] for :batch, called with all changes from one polling cycle
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
        flush_debounced_changes
        self
      end

      # @return [Boolean] true if the watcher is currently running
      def running?
        @mutex.synchronize { @running }
      end

      # Pause change detection. The polling thread stays alive but skips detection.
      #
      # @return [self]
      def pause
        @mutex.synchronize { @paused = true }
        self
      end

      # Resume change detection with a fresh snapshot.
      #
      # Changes that occurred while paused are silently ignored.
      #
      # @return [self]
      def resume
        @mutex.synchronize do
          @snapshot = take_snapshot
          @pending_debounce.clear
          @paused = false
        end
        self
      end

      # @return [Boolean] true if the watcher is currently paused
      def paused?
        @mutex.synchronize { @paused }
      end

      # Return a hash of all currently tracked files with their mtime and size.
      #
      # @return [Hash{String => Hash}] mapping of path to {mtime:, size:}
      def snapshot
        @mutex.synchronize do
          @snapshot.each_with_object({}) do |(path, mtime), result|
            size = begin
              File.size(path)
            rescue StandardError
              0
            end
            result[path] = { mtime: mtime, size: size }
          end
        end
      end

      private

      def poll_loop
        while running?
          sleep @interval
          next unless running?
          next if paused?

          changes = detect_changes
          next if changes.empty?

          if @debounce
            enqueue_debounced(changes)
            flush_ready_debounced
          else
            fire_batch_callbacks(changes)
            fire_callbacks(changes)
          end
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
        @paths.each_with_object({}) do |base_path, snap|
          expanded = File.expand_path(base_path)
          if File.file?(expanded)
            record_file(expanded, snap)
          elsif File.directory?(expanded)
            scan_directory(expanded, snap)
          end
        rescue SystemCallError => e
          fire_error_callbacks(e, expanded || base_path)
        end
      end

      def scan_directory(dir, snap)
        Dir.glob(File.join(dir, @glob)).each do |file|
          next unless File.file?(file)
          next if excluded?(file)

          record_file(file, snap)
        rescue SystemCallError => e
          fire_error_callbacks(e, file)
        end
      end

      def record_file(file, snap)
        snap[file] = File.mtime(file)
      rescue SystemCallError => e
        fire_error_callbacks(e, file)
      end

      def excluded?(file)
        return false if @exclude.empty?

        @exclude.any? do |pattern|
          File.fnmatch?(pattern, file, File::FNM_PATHNAME | File::FNM_DOTMATCH | File::FNM_EXTGLOB)
        end
      end

      def enqueue_debounced(changes)
        now = monotonic_now
        @mutex.synchronize do
          changes.each do |change|
            @pending_debounce[change.path] = { change: change, deadline: now + @debounce }
          end
        end
      end

      def flush_ready_debounced
        now = monotonic_now
        ready = []
        @mutex.synchronize do
          @pending_debounce.each_value do |entry|
            if now >= entry[:deadline]
              ready << entry[:change]
            end
          end
          ready.each { |change| @pending_debounce.delete(change.path) }
        end
        return if ready.empty?

        fire_batch_callbacks(ready)
        fire_callbacks(ready)
      end

      def flush_debounced_changes
        ready = []
        @mutex.synchronize do
          @pending_debounce.each_value { |entry| ready << entry[:change] }
          @pending_debounce.clear
        end
        return if ready.empty?

        fire_batch_callbacks(ready)
        fire_callbacks(ready)
      end

      def fire_callbacks(changes)
        changes.each do |change|
          @mutex.synchronize do
            @callbacks[change.type].each { |cb| cb.call(change) }
            @callbacks[:any].each { |cb| cb.call(change) }
          end
        end
      end

      def fire_batch_callbacks(changes)
        @mutex.synchronize do
          @callbacks[:batch].each { |cb| cb.call(changes) }
        end
      end

      def fire_error_callbacks(exception, path)
        @mutex.synchronize do
          raise exception if @callbacks[:error].empty?

          @callbacks[:error].each { |cb| cb.call(exception, path) }
        end
      end

      def monotonic_now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
