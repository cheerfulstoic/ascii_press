# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ascii_press/version'

Gem::Specification.new do |spec|
  spec.name          = "ascii_press"
  spec.version       = AsciiPress::VERSION
  spec.authors       = ["Brian Underwood"]
  spec.email         = ["ml+github@semi-sentient.com"]

  spec.summary       = %q{Tools for publishing a set of ASCIIdoc files to WordPress}
  spec.description   = %q{Tools for publishing a set of ASCIIdoc files to WordPress}
  spec.homepage      = "http://github.com/cheerfulstoic/ascii_press"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'rubypress', '~> 1.1.1'
  spec.add_dependency 'asciidoctor', '~> 1.5.4'
  spec.add_dependency 'activesupport', '>= 3.0'
  spec.add_dependency 'colorize', '>= 0.7.7'

  spec.add_development_dependency "bundler", "~> 1.11"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rubocop", "~> 0.36.0"
end
