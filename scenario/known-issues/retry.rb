## update
def foo
  n = 1
  begin
    raise if rand < 0.5
    n
  rescue
    n = "str"
    retry
  end
end
  
foo
  
## assert
class Object
  def foo: () -> (Integer | String)
end

## diagnostics
