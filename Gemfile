source "https://rubygems.org"

if ENV["RBS_VERSION"]
  gem "rbs", github: "ruby/rbs", ref: ENV["RBS_VERSION"]
else
  # Specify your gem's dependencies in typeprof.gemspec
  gemspec
end

group :development do
  gem "rake"
  gem "stackprof", platforms: :mri
  gem "test-unit"
  gem "simplecov"
  gem "simplecov-html"
  gem "coverage-helpers"
end
