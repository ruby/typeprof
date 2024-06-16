## update
def elsif_and_block
  if true
  elsif true
  else
    w = 0
  end

  yield_self do
    w = 0
  end

  1
end

## assert
class Object
  def elsif_and_block: -> Integer
end
