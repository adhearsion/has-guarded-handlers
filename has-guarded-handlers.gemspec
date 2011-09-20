# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "has_guarded_handlers/version"

Gem::Specification.new do |s|
  s.name        = "has-guarded-handlers"
  s.version     = HasGuardedHandlers::VERSION
  s.authors     = ["Ben Langfeld", "Jeff Smick"]
  s.email       = ["ben@langfeld.me"]
  s.homepage    = "http://github.com/adhearsion/has-guarded-handlers"
  s.summary     = %q{A library for associating a set of event handlers, complete with guards, with a Ruby object}
  s.description = %q{Allow an object's API to provide flexible handler registration, storage and matching to arbitrary events.}

  s.rubyforge_project = "has-guarded-handlers"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_development_dependency %q<bundler>, ["~> 1.0.0"]
  s.add_development_dependency %q<rspec>, ["~> 2.3.0"]
  s.add_development_dependency %q<mocha>, [">= 0"]
  s.add_development_dependency %q<ci_reporter>, [">= 1.6.3"]
  s.add_development_dependency %q<yard>, ["~> 0.7.0"]
  s.add_development_dependency %q<rake>, [">= 0"]
end
