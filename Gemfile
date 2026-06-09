source "https://rubygems.org"

gem "rails", "~> 8.1.3"
gem "pg", "~> 1.5"
gem "puma", ">= 5.0"
gem "tzinfo-data", platforms: %i[ windows jruby ]
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"
gem "bootsnap", require: false
gem "kamal", require: false
gem "thruster", require: false
gem "image_processing", "~> 1.2"
gem "exifr", require: false
gem "ruby-ulid", "~> 1.0", require: "ulid"
gem "rodauth-rails", "~> 2.1"
gem "sequel-activerecord_connection", "~> 2.0", require: false
gem "bcrypt", "~> 3.1"
gem "thor", "~> 1.3"
gem "rack-cors"
gem "vite_rails"

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "bundler-audit", require: false
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
end

group :test do
  gem "minitest", "~> 5.25"
  gem "minitest-rails", "~> 8.0"
end
