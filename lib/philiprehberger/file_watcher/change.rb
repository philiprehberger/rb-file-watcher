# frozen_string_literal: true

module Philiprehberger
  module FileWatcher
    # Value object representing a single file system change.
    #
    # @attr_reader path [String] absolute path to the changed file
    # @attr_reader type [Symbol] one of :created, :modified, or :deleted
    class Change
      VALID_TYPES = %i[created modified deleted].freeze

      attr_reader :path, :type

      # @param path [String] the file path that changed
      # @param type [Symbol] the change type (:created, :modified, or :deleted)
      # @raise [ArgumentError] if the type is not valid
      def initialize(path, type)
        unless VALID_TYPES.include?(type)
          raise ArgumentError, "invalid change type: #{type.inspect} (must be one of #{VALID_TYPES.join(', ')})"
        end

        @path = path
        @type = type
      end

      # @return [String] human-readable representation of the change
      def to_s
        "#{type}: #{path}"
      end

      # @return [Boolean] true if path and type match
      def ==(other)
        other.is_a?(Change) && other.path == path && other.type == type
      end
      alias eql? ==

      # @return [Integer] hash code
      def hash
        [path, type].hash
      end
    end
  end
end
