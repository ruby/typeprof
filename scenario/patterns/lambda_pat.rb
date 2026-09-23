## update: test.rb
def check(x)
  case x
  in ->(i) { i == 0 }
    :zero
  in Integer
    :int
  end
end

check(0)

## assert
class Object
  def check: (Integer) -> (:int | :zero)
end
