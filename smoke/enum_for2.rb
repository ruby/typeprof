class Foo
  def int_and_str_enum
    return enum_for(:int_and_str_enum) unless block_given?

    yield 1
    yield 2
    yield 3

    1.0
  end
end

__END__
# Errors
smoke/enum_for2.rb:5: [warning] non-proc is passed as a block
smoke/enum_for2.rb:6: [warning] non-proc is passed as a block
smoke/enum_for2.rb:7: [warning] non-proc is passed as a block

# Classes
class Foo
  def int_and_str_enum: ?{ (Integer) -> untyped } -> (Enumerator[Integer, untyped] | Float)
end
