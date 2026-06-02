# frozen_string_literal: true

module WebHelper
  def kbmemo_home_url
    ENV.fetch("KBMEMO_HOME_URL", "http://localhost:3000")
  end
end
