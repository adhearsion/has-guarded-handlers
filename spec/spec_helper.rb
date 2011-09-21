require 'rubygems'
require 'has_guarded_handlers'
require 'mocha'

Dir[File.dirname(__FILE__) + "/support/**/*.rb"].each {|f| require f}

RSpec.configure do |config|
  config.mock_with :mocha
  config.filter_run :focus => true
  config.run_all_when_everything_filtered = true
end

class TestObject
  include HasGuardedHandlers
end
