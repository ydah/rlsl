# frozen_string_literal: true

require_relative "lib/rlsl/version"

Gem::Specification.new do |spec|
  spec.name = "rlsl"
  spec.version = RLSL::VERSION
  spec.authors = ["Yudai Takada"]
  spec.email = ["t.yudai92@gmail.com"]

  spec.summary = "Ruby Like Shading Language - A shader DSL for Ruby"
  spec.description = "RLSL is a Ruby DSL for writing shaders that can be transpiled to GLSL, WGSL, and MSL"
  spec.homepage = "https://github.com/ydah/rlsl"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "prism"

  if RUBY_PLATFORM.include?("darwin")
    spec.add_dependency "metaco"
  end
end
