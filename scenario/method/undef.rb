## update
class Foo
  def foo
    42
  end

  # Currently, TypeProf just ignores undef statements
  undef foo
  undef :foo, :bar
  undef :"foo#{ 42 }"
end

## assert
class Foo
  def foo: -> Integer
end
