gem "redis", "4.0.1"

require_relative "support/jylis"
require_relative "support/ujson"

Thread.abort_on_exception = true

RSpec.configure do |c|
  # Enable 'should' syntax
  c.expect_with(:rspec) { |c| c.syntax = [:should, :expect] }
  c.mock_with(:rspec)   { |c| c.syntax = [:should, :expect] }
  
  # If any tests are marked with iso: true, only run those tests
  c.filter_run_including(iso: true)
  c.run_all_when_everything_filtered = true
end
