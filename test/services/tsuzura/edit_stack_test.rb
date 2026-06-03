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

  test "normalize defaults blank crop width and height for rotation-only saves" do
    stack = Tsuzura::EditStack.normalize(
      "rotate" => 90,
      "crop" => { "x" => "0", "y" => "0", "w" => "", "h" => "" }
    )
    assert_equal 90, stack["rotate"]
    assert_equal 1, stack["crop"]["w"]
    assert_equal 1, stack["crop"]["h"]
  end

  test "normalize omits crop when crop hash is empty" do
    stack = Tsuzura::EditStack.normalize("rotate" => 180, "crop" => {})
    assert_equal 180, stack["rotate"]
    assert_nil stack["crop"]
  end

  test "normalize blur_regions from indexed hash params" do
    stack = Tsuzura::EditStack.normalize(
      "blur_regions" => {
        "0" => { "x" => 0.1, "y" => 0.2, "w" => 0.3, "h" => 0.4, "strength" => 8 }
      }
    )
    assert_equal 1, stack["blur_regions"].size
  end

  test "normalize keeps blur regions" do
    stack = Tsuzura::EditStack.normalize(
      "blur_regions" => [{ "x" => 0.1, "y" => 0.2, "w" => 0.3, "h" => 0.4, "strength" => 8 }]
    )
    assert_equal 1, stack["blur_regions"].size
    assert_equal 8, stack["blur_regions"].first["strength"]
  end
end
