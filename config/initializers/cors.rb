# frozen_string_literal: true

# Phase 2: kbmemo.net から media API を credentials 付きで呼ぶ場合に備える。
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins lambda { |source, _env|
      next false if source.blank?

      allowed = ENV.fetch("TSUZURA_CORS_ORIGINS", "https://kbmemo.net,https://www.kbmemo.net,http://localhost:3000")
        .split(",")
        .map(&:strip)
        .reject(&:empty?)
      allowed.include?(source)
    }

    resource "/v1/*",
      headers: :any,
      methods: %i[get post options],
      credentials: true,
      max_age: 600
  end
end
