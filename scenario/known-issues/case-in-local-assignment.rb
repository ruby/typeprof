## update
def foo(value)
  label = :none
  case value
  in Integer
    label = :integer
  in String
    label = :string
  else
  end
  label
end

foo(1)
foo("str")

## assert
class Object
  def foo: (Integer | String) -> (:integer | :none | :string)
end
