require "open3"
require "redis"

require_relative "util"

class Jylis
  BIN = File.join(File.dirname(__FILE__), "../../bin/jylis")
  
  attr_reader :opts
  
  # Prepare to run a Jylis server with the given options,
  # which will be translated into CLI options for the binary.
  def initialize(**opts)
    opts[:port] ||= Util.random_port
    opts[:addr] ||= "127.0.0.1:#{Util.random_port}"
    @opts = opts
    
    @client = Redis.new(host: "127.0.0.1", port: @opts[:port])
    
    opts_array = opts.map do |key, value|
      "--#{key.to_s.gsub("_", "-")}=#{value}"
    end
    
    @command = [BIN, *opts_array]
  end
  
  # Run the server process with the configured options.
  # This method takes a block, in which the server is already running.
  # At the end of the block, both the server and client will be killed.
  # By default, this method will time out after 10 seconds.
  def run(timeout: 10)
    Open3.popen2 *@command do |stdin, stdout_io, status_thread|
      @status_thread = status_thread
      @stdout_io     = stdout_io
      @stdout        = []
      
      Timeout.timeout timeout do
        begin
          await_line %r(server listener ready)
          await_line %r(cluster listener ready)
          
          yield if block_given?
        ensure
          # Kill the client and the server now that the block is done.
          @client.close
          Process.kill("INT", status_thread.pid)
          @status_thread.join
        end
      end
    end
  end
  
  # Print stdout of the server process to stdout of the test process.
  # For debugging purposes only.
  def show_output
    @stdout.each { |line| puts line }
  end
  
  # Wait for a line matching the given String or Regexp to appear in stdout,
  # and return the first match as a Match object. The line may appear anywhere
  # in stdout, including lines that have already been matched in the past.
  # Multi-line Strings and Regexps are not support patterns.
  def await_line(pattern)
    @stdout.each do |line|
      match = pattern.match(line)
      return match if match
    end
    
    loop do
      line = @stdout_io.readline
      @stdout << line
      
      match = pattern.match(line)
      return match if match
    end
  rescue EOFError
    show_output
    fail "command failed while awaiting line: #{pattern.inspect}"
  end
  
  # Invoke a Redis-style command on the server.
  def call(*command)
    @client.call(*command.flatten)
  end
  
  # Return a Hash whose keys are file names in the disk directory,
  # and whose values are File objects, opened and ready for reading.
  def disk
    Dir.glob("#{@opts.fetch(:disk_dir)}/*").map do |path|
      [File.basename(path), File.open(path)]
    end.to_h
  end
end
