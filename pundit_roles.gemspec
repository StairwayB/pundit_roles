# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pundit_roles/version'

Gem::Specification.new do |spec|
  spec.name          = "pundit_roles"
  spec.version       = PunditRoles::VERSION
  spec.authors       = ["Daniel Balogh"]
  spec.email         = ["danielferencbalogh@gmail.com"]

  spec.summary       = %q{Extends Pundit with roles, which allow attribute and association level authorizations}
  spec.description   = %q{Extends Pundit with roles}
  spec.homepage      = "https://github.com/StairwayB/pundit_roles"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = '>= 2.3.1'
  spec.add_dependency "activesupport", ">= 3.0.0"
  spec.add_dependency 'pundit', '>=1.1.0'
end
