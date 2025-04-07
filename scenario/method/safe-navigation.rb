## update
def return_optional
  if rand < 0.5
    "str"
  else
    nil
  end
end

def check
  return_optional&.to_i
end

## diagnostics

## assert
class Object
  def return_optional: -> String?
  def check: -> Integer?
end
