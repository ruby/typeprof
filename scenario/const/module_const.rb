## update
module M
  C = :test
end

class C
  include M
end

def check
  C::C
end

## diagnostics
## assert
module M
  C: :test
end
class C
  include M
end
class Object
  def check: -> :test
end
