## update
def check(x)
end

def foo
  x = 1
  END { check(x) } # TODO: This shoud pass String, but it is not implemented yet
  # See known-issues/post-exec.rb
  x = "str"
end

## assert
class Object
  def check: (Integer) -> nil
  def foo: -> String
end
