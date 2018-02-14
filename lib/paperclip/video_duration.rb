require 'ffprober'

module Paperclip
  # Get duration of a video
  class VideoDuration
    class << self
      def from_file_path(path)
        probe = Ffprober::Parser.from_file(path)
        return nil if probe.blank?
        video_stream = probe.video_streams.try(:first)
        return nil if video_stream.blank?
        video_stream.try(:duration).try(:to_f)
      end
    end
  end
end
