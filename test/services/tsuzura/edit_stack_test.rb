# frozen_string_literal: true

require "test_helper"

class Tsuzura::EditStackTest < ActiveSupport::TestCase
  test "normalize defaults rotate to 0" do
    stack = Tsuzura::EditStack.normalize({})
    assert_equal 0, stack["rotate"]
    assert_nil stack["crop"]
  end

  test "normalize rejects crop outside bounds" do
    assert_raises Tsuzura::EditStack::ValidationError do
      Tsuzura::EditStack.normalize("crop" => { "x" => 0.5, "y" => 0, "w" => 0.6, "h" => 1 })
    end
  end

  test "normalize keeps blur regions" do
    stack = Tsuzura::EditStack.normalize(
      "blur_regions" => [{ "x" => 0.1, "y" => 0.2, "w" => 0.3, "h" => 0.4, "strength" => 8 }]
    )
    assert_equal 1, stack["blur_regions"].size
    assert_equal 8, stack["blur_regions"].first["strength"]
  end
end
