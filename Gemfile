source "https://rubygems.org"

# Specify your gem's dependencies in typeprof.gemspec
gemspec

if ENV["RBS_VERSION"]
  gem "rbs", github: "ruby/rbs", ref: ENV["RBS_VERSION"]
end

group :development do
  gem "rake"
  gem "stackprof", platforms: :mri
  gem "test-unit"
  gem "simplecov"
  gem "simplecov-html"
  gem "coverage-helpers"
end
