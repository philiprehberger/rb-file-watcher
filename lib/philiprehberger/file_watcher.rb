# frozen_string_literal: true

require_relative 'file_watcher/version'
require_relative 'file_watcher/change'
require_relative 'file_watcher/watcher'

module Philiprehberger
  module FileWatcher
    class Error < StandardError; end

    # Watch paths for file system changes (blocking).
    #
    # Polls the file system at the given interval and yields arrays of Change
    # objects whenever created, modified, or deleted files are detected.
    #
    # @param paths [Array<String>, String] directories or files to watch
    # @param interval [Float] polling interval in seconds (default: 1.0)
    # @param glob [String] glob pattern for matching files (default: "**/*")
    # @yield [Array<Change>] called with an array of changes on each poll cycle
    # @return [void]
    def self.watch(paths, interval: 1.0, glob: '**/*', &block)
      raise ArgumentError, 'a block is required' unless block

      watcher = Watcher.new(paths, interval: interval, glob: glob)
      watcher.on(:any, &block)
      watcher.start

      # Block the calling thread until interrupted
      sleep
    rescue Interrupt
      watcher.stop
    end
  end
end
