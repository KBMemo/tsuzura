# frozen_string_literal: true

require "test_helper"

class Tsuzura::MediaUrlSignerTest < ActiveSupport::TestCase
  test "sign and validate round trip" do
    media_id = "01JTSUZRM0000000000000001"
    memo_id = 42
    exp = 1.hour.from_now.to_i
    sig = Tsuzura::MediaUrlSigner.signature(media_id: media_id, memo_id: memo_id, exp: exp)

    assert Tsuzura::MediaUrlSigner.valid?(
      media_id: media_id,
      memo_id: memo_id,
      exp: exp,
      sig: sig
    )
  end

  test "sign builds web url with query params" do
    url = Tsuzura::MediaUrlSigner.sign(
      media_id: "01JTSUZRM0000000000000001",
      memo_id: 7
    )

    assert_includes url, "http://media.example.com/v1/media/01JTSUZRM0000000000000001/web"
    assert_includes url, "memo_id=7"
    assert_includes url, "sig="
  end
end
