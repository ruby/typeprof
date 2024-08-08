## update
class Array
  def quote
    each {|s| s.quote }
  end
end

## assert
class Array
  def quote: -> Array[untyped]
end
