## update
module A
end

module B
  include A
end

module A
  include B
end

class C
  include A
  def foo = bar
end

## assert
module A
end
module B
end
module A
end
class C
  include A
  def foo: -> untyped
end
