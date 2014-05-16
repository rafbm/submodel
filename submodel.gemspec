# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'submodel/version'

Gem::Specification.new do |spec|
  spec.name          = 'submodel'
  spec.version       = Submodel::VERSION
  spec.authors       = ['Rafaël Blais Masson']
  spec.email         = ['rafbmasson@gmail.com']
  spec.summary       = 'Submodel maps ActiveRecord columns to ActiveModel models.'
  spec.homepage      = 'http://github.com/rafBM/submodel'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'activerecord', '>= 3.0'

  spec.add_development_dependency 'bundler', '~> 1.6'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec', '>= 3.0.0.beta2'
  spec.add_development_dependency 'pg'
  spec.add_development_dependency 'sqlite3'
  spec.add_development_dependency 'mysql2'
  spec.add_development_dependency 'carmen'
end
