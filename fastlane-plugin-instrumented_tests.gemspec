# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fastlane/plugin/instrumented_tests/version'

Gem::Specification.new do |spec|
  spec.name          = 'fastlane-plugin-instrumented_tests'
  spec.version       = Fastlane::InstrumentedTests::VERSION
  spec.author        = %q{Silviu Paragina}
  spec.email         = %q{silviu.paragina@mready.net}

  spec.summary       = %q{New action to run instrumented tests for android. This basically creates and boots an emulator before running an gradle commands so that you can run instrumented tests against that emulator. After the gradle command is executed, the avd gets shut down and deleted. This is really helpful on CI services, keeping them clean and always having a fresh avd for testing.}
  spec.homepage      = "https://github.com/joshrlesch/fastlane-plugin-instrumented_tests"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*"] + %w(README.md LICENSE)
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  # spec.add_dependency 'your-dependency', '~> 1.0.0'

  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'fastlane', '>= 1.96.0'
end
