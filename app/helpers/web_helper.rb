# frozen_string_literal: true

module WebHelper
  def kbmemo_home_url
    ENV.fetch("KBMEMO_HOME_URL", "http://localhost:3000")
  end

  # Header seal mark (app/assets/images/tsuzura1.svg).
  def tsuzura_brand_icon
    path = Rails.root.join("app/assets/images/tsuzura1.svg")
    svg = File.read(path)
    svg = svg.sub(
      /<svg\b[^>]*>/,
      '<svg class="app-brand-icon" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 380 373" role="img" aria-hidden="true">'
    )
    raw svg
  end
end
