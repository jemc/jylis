require "securerandom"

module Util
  module_function
  
  # Return a random port from the dynamic/private port range.
  def random_port
    SecureRandom.random_number(65535-49152) + 49152
  end
end
