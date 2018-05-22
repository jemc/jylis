require "open3"
require "redis"

require_relative "util"

class Jylis
  BIN = File.join(File.dirname(__FILE__), "../../bin/jylis")
  
  attr_reader :opts
  attr_reader :addr # filled during start of run
  attr_reader :port # filled during start of run
  
  # Prepare to run a Jylis server with the given options,
  # which will be translated into CLI options for the binary.
  def initialize(**opts)
    opts[:port] ||= Util.random_port
    opts[:addr] ||= "127.0.0.1:#{Util.random_port}"
    @opts = opts
    
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
      
      begin
        Timeout.timeout timeout do
          begin
            @port = await_line(%r{server listener ready on port (\d+)})[1]
            @addr = await_line(%r{cluster listener ready with address (\S+)})[1]
            
            @client = Redis.new(host: "127.0.0.1", port: @port)
            
            yield if block_given?
          ensure
            # Kill the client and the server now that the block is done.
            @client.close
            Process.kill("INT", status_thread.pid)
            @status_thread.join unless $!
          end
        end
      rescue Timeout::Error
        fail Timeout::Error, Thread.current[:timeout_hint]
      end
    end
  end
  
  # Print stdout of the server process to stdout of the test process.
  # For debugging purposes only.
  def show_output
    # Fill stdout with any bytes currently available to read.
    begin
      @stdout_io
        .read_nonblock(2 ** 32)
        .each_line { |line| @stdout << line.rstrip }
    rescue IO::WaitReadable
    end
    
    # Print the lines captured from stdout.
    @stdout.each { |line| puts line }
  end
  
  # Return a Match object or true if the given pattern matches the given line.
  # The pattern may be a String or a Regexp
  def _match_line(line, pattern)
    case pattern
    when Regexp then pattern.match(line)
    when String then line.include?(pattern)
    else fail NotImplementedError, "don't know how to match on #{pattern}"
    end
  end
  
  # Wait for a line matching the given String or Regexp to appear in stdout,
  # and return the first match as a Match object (Regexp) or true (String).
  # The line may appear anywhere in stdout, including lines that have already
  # been matched in the past.
  # Multi-line Strings and Regexps are not supported patterns.
  def await_line(pattern)
    @stdout.each do |line|
      match = _match_line(line, pattern)
      return match if match
    end
    
    loop do
      Thread.current[:timeout_hint] = \
        "Timed out waiting to read line with pattern: #{pattern.inspect}"
      
      line = @stdout_io.readline.rstrip
      @stdout << line
      
      match = _match_line(line, pattern)
      return match if match
      
      if line.start_with?("(E)")
        show_output
        fail "database had an unexpected runtime error: #{line}"
      end
    end
  rescue EOFError
    show_output
    fail "database exited while we were awaiting line: #{pattern.inspect}"
  end
  
  # Invoke a Redis-style command on the server.
  def call(command)
    @client.call(*command)
  end
  
  # Invoke a Redis-style command on the server until the result of the call
  # matches the given expected result, with exponential backoff.
  def await_call_result(command, expected_result)
    start_time = Time.now
    result     = nil
    
    loop do
      result = call(command)
      break if result == expected_result
      
      Thread.current[:timeout_hint] = \
        "Timed out waiting for result: #{expected_result}; got: #{result}"
      
      sleep(Time.now - start_time)
    end
  end
  
  # Return a Hash whose keys are file names in the disk directory,
  # and whose values are File objects, opened and ready for reading.
  def disk
    Dir.glob("#{@opts.fetch(:disk_dir)}/*").map do |path|
      [File.basename(path), File.open(path)]
    end.to_h
  end
end
