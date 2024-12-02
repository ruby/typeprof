Gem::Specification.new do |spec|
  spec.name          = "my_dummy_gem"
  spec.version       = "1.0.0"
  spec.authors       = ["Yusuke Endoh"]
  spec.email         = ["mame@ruby-lang.org"]

  spec.summary       = %q{A dummy gem for testing TypePRof}
  spec.description   = %q{A dummy gem for testing TypePRof}
  spec.homepage      = "https://github.com/ruby/typeprof"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 3.3")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/ruby/typeprof"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = ["lib/my_dummy_gem.rb"]
  spec.executables   = []
  spec.require_paths = ["lib"]
end
