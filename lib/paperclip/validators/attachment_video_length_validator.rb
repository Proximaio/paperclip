require 'paperclip/video_duration'

module Paperclip
  module Validators
    class AttachmentVideoLengthValidator < ActiveModel::EachValidator
      AVAILABLE_CHECKS    = %i[min_length max_length].freeze
      VALID_CONTENT_TYPES = %i[video].freeze

      def initialize(options)
        super
      end

      def self.helper_method_name
        :validates_video_length
      end

      def validate_each(record, attr_name, _value)
        asset = record.send(:read_attribute_for_validation, attr_name)
        return unless asset.present?

        file      = asset.queued_for_write[:original]
        base_type = record.send(:"#{attr_name}_content_type")
        return if file.blank? || base_type.blank?

        content_type = base_type.split('/').first.to_sym
        return unless content_type.in?(VALID_CONTENT_TYPES)

        length_in_seconds = Paperclip::VideoDuration.from_file_path(asset.path)

        # this should allow for procs to determine the max_x or max_y values
        # so a user can specify for image/gif that they want 1920x1080 as a max
        # while for image/png it could be nil or something different
        options.slice(*AVAILABLE_CHECKS).each do |option, option_value|
          option_value = option_value.call(record) if option_value.is_a?(Proc)

          # this is to optionally specify that there is no limit for an axis
          next if option_value.blank?

          # validate x value and y value are within x and y range
          if limits_exceeded?(option, option_value, length_in_seconds)
            record.errors.add(attr_name, "Asset cannot exceed #{option_string(option)} of #{option_value}")
          end
        end
      end

      def check_validity!
        unless AVAILABLE_CHECKS.any? { |argument| options.has_key?(argument) }
          raise ArgumentError, "You must pass either :min_length, or :max_length to the validator"
        end
      end

      private

      def limits_exceeded?(option, limit, length_in_seconds)
        # don't enforce blank limits
        return false if limit.blank?

        # automatically fail blank lengths
        return true if length_in_seconds.blank?

        # return true if the length of a video is lower than the min_length value
        return limit < length_in_seconds if option == :min_length

        # return true if the length of a video is higher than the max_length value
        limit > length_in_seconds if option == :max_length
      end

      def option_string(option)
        return 'minimum length' if option == :min_length
        'maximum length' if option == :max_length
      end
    end

    module HelperMethods
      # Places ActiveModel validations on the length of a video.
      # Options:
      # * +min_length+: Minimum Length allowed of a video in seconds
      # * +max_length+: Value that the y dimension of an asset cannot exceed
      def validates_video_length(*attr_names)
        options = _merge_attributes(attr_names)
        validates_with AttachmentDimensionsValidator, options.dup
        validate_before_processing AttachmentDimensionsValidator, options.dup
      end
    end
  end
end
