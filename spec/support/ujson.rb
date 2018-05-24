require "json"
require "set"

class UJSON
  attr_reader :string
  
  def initialize(string)
    @string = string
  end
  
  def ==(other)
    case other
    when UJSON  then self.to_ruby == other.to_ruby
    when String then self.to_ruby == UJSON.new(other).to_ruby
    else fail NotImplementedError
    end
  end
  
  def to_ruby
    _to_ruby(JSON.load(string))
  end
  
  def _to_ruby(obj)
    case obj
    when Array then Set.new(obj.map { |o| _to_ruby(o) })
    when Hash  then obj.map { |k, o| [k, _to_ruby(o)] }.to_h
    else obj
    end
  end
end
