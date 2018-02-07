require 'ffprober'

module Paperclip

  # Defines the geometry of a video
  class VideoGeometry
    class << self
      def from_file(file)
        probe = Ffprober::Parser.from_file(file)
        return nil if probe.blank?
        video_stream = probe.video_streams.try(:first)
        return nil if video_stream.blank?
        video_stream
      end
    end
  end
end
