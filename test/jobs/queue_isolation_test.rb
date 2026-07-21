# frozen_string_literal: true

require "test_helper"

class QueueIsolationTest < ActiveSupport::TestCase
  test "media jobs use the media-only queue" do
    job_classes = [
      ApplyEditStackJob,
      GenerateWebVariantJob
    ]

    assert_equal [ "kbmemo_media" ], job_classes.map(&:queue_name).uniq
  end
end
