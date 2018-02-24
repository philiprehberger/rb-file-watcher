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
    # @param exclude [Array<String>] glob patterns to exclude from watching (default: [])
    # @param debounce [Float, nil] debounce interval in seconds (default: nil)
    # @yield [Change] called with a change on each detected file change
    # @return [void]
    def self.watch(paths, interval: 1.0, glob: '**/*', exclude: [], debounce: nil, &block)
      raise ArgumentError, 'a block is required' unless block

      watcher = Watcher.new(paths, interval: interval, glob: glob, exclude: exclude, debounce: debounce)
      watcher.on(:any, &block)
      watcher.start

      # Block the calling thread until interrupted
      sleep
    rescue Interrupt
      watcher.stop
    end
  end
end
