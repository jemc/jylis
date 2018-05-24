require_relative "spec_helper"

describe "Documentation" do
  subject { Jylis.new }
  
  def glob(relative_path)
    Dir.glob(File.join(File.dirname(__FILE__), relative_path)).sort
  end
  
  def interpret_output_lines(output_lines)
    output = nil
    
    output_lines.each do |output_line|
      case output_line
      when /\A\(integer\) (-?\d+)\z/
        # Handle converting from output marked as an integer in the Redis way.
        output = Integer($~[1])
      when /\A"(.*?)"\z/
        # Treat double-quoted output as string output.
        # We probably should (but don't) worry about escape sequences here.
        output = $~[1]
      when /\A'(.*?)'\z/
        # It's a bit hacky, but always treat single-quotes as UJSON.
        output = UJSON.new($~[1])
      when "(empty list)"
        # Handle converting from output notated as an empty list.
        output = []
      when /\A((?:   |\d\) )+)(.+)\z/
        # Handle converting from output notated as an array in the Redis way.
        # This logic is made more complex by the fact that output happens one
        # line at a time, and that it may included nested arrays.
        # It's hacky, but we assume no array indices are more than one digit.
        indices = $~[1].chars.each_slice(3).map(&:first)
        content = $~[2]
        
        output ||= []
        array = output
        indices.each_with_index do |index, iter_index|
          is_final = iter_index == indices.size - 1
          
          if index == " " then
            array = array.last
          else
            if is_final
              array[Integer(index) - 1] = interpret_output_lines([content])
            else
              array[Integer(index) - 1] = array = []
            end
          end
        end
      else
        output = output_line
      end
    end
    
    output
  end
  
  it "provides examples for each data type that work as shown" do
    examples_files = glob("../docs/_docs/types/*.md")
    examples_files.each do |file|
      examples =
        File.read(file)
            .scan(/\n```sh\n(.*?)```/m)
            .map(&:last)
            .map { |string| string.split("\n").slice_before(/\Ajylis> /).to_a }
      
      examples.should_not be_empty,
        "expected to have at least one example block in #{File.basename(file)}"
      
      subject.run do
        examples.each_with_index do |commands, command_idx|
          commands.each do |input, *output_lines|
            expected = interpret_output_lines(output_lines)
            result   = subject.call(Shellwords.split(input)[1..-1])
            
            expected.should eq(result), [
              "In example in #{File.basename(file)}",
              "  for command #{command_idx}: #{input}",
              "  expected:",
              "    " + expected.inspect,
              "  got:",
              "    " + result.inspect
            ].join("\n")
          end
        end
      end
    end
  end
end
