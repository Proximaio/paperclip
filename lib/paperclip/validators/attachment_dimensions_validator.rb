require 'paperclip/video_geometry'

module Paperclip
  module Validators
    class AttachmentDimensionsValidator < ActiveModel::EachValidator
      AVAILABLE_CHECKS    = %i[max_x max_y].freeze
      VALID_CONTENT_TYPES = %i[image video].freeze

      def initialize(options)
        super
      end

      def self.helper_method_name
        :validates_attachment_dimensions
      end

      def validate_each(record, attr_name, _value)
        asset = record.send(:read_attribute_for_validation, attr_name)
        return unless asset.present?

        file      = asset.queued_for_write[:original]
        base_type = record.send(:"#{attr_name}_content_type")
        return if file.blank? || base_type.blank?

        content_type = base_type.split('/').first.to_sym
        return unless content_type.in?(VALID_CONTENT_TYPES)

        asset_x_dim, asset_y_dim = extract_dimensions(content_type, file)

        # this should allow for procs to determine the max_x or max_y values
        # so a user can specify for image/gif that they want 1920x1080 as a max
        # while for image/png it could be nil or something different
        options.slice(*AVAILABLE_CHECKS).each do |option, option_value|
          option_value = option_value.call(record) if option_value.is_a?(Proc)

          # validate x value and y value are within x and y range
          if dimensions_exceeded?(option, option_value, asset_x_dim, asset_y_dim)
            record.errors.add(attr_name, "#{axis_string(option)} cannot exceed #{option_value}")
          end
        end
      end

      def check_validity!
        unless AVAILABLE_CHECKS.any? { |argument| options.has_key?(argument) }
          raise ArgumentError, "You must pass either :max_x, or :max_y to the validator"
        end
      end

      private

      def extract_dimensions(content_type, asset)
        return image_dimensions(asset) if content_type == :image
        return video_dimensions(asset) if content_type == :video
        [0, 0]
      end

      def image_dimensions(asset)
        return [0, 0] if asset.blank?
        geo = Paperclip::Geometry.from_file(asset)
        return [0, 0] if geo.blank?
        [geo.width.to_i, geo.height.to_i]
      end

      def video_dimensions(asset)
        return [0, 0] if asset.blank?
        geo = Paperclip::VideoGeometry.from_file(asset)
        return [0, 0] if geo.blank?
        [geo.width.to_i, geo.height.to_i]
      end

      def dimensions_exceeded?(dim_key, axis_limit, x_val, y_val)
        return x_val >= axis_limit if dim_key == :max_x
        return y_val >= axis_limit if dim_key == :max_y
        true
      end

      def axis_string(dim_key)
        return 'X-axis' if dim_key == :max_x
        'Y-axis' if dim_key == :max_y
      end
    end

    module HelperMethods
      # Places ActiveModel validations on the dimensions of an image or video.
      # Options:
      # * +max_x+: Value that the x dimension of an asset cannot exceed
      # * +max_y+: Value that the y dimension of an asset cannot exceed
      def validates_attachment_dimensions(*attr_names)
        options = _merge_attributes(attr_names)
        validates_with AttachmentDimensionsValidator, options.dup
        validate_before_processing AttachmentDimensionsValidator, options.dup
      end
    end
  end
end
