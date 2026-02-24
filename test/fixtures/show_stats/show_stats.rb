# Typed constant
TYPED_CONST = 1

# Typed global variable
$typed_gvar = 99

class Foo
  # Untyped constant: assigned from unwritten class-level ivar
  UNTYPED_CONST = @unset

  # Typed class variable
  @@typed_cvar = "hello"

  def initialize
    # Typed instance variable
    @typed_ivar = 42
  end

  # Fully typed method: param and return both typed
  def typed_method(n)
    n
  end

  # Partially typed method: params untyped (never called), return typed (nil)
  def untyped_params(a, b)
  end

  # Method with typed block: yields a typed value
  def with_typed_block
    yield 1
  end

  # Method with untyped block: yields an untyped value (unwritten ivar)
  def with_untyped_block
    yield @nonexistent
  end

  # Never called: param 'a' has no type, so ivar/cvar/gvar assigned from it are untyped
  def uncalled_writer(a)
    @untyped_ivar = a
    @@untyped_cvar = a
    $untyped_gvar = a
  end
end

Foo.new.typed_method("str")
Foo.new.with_typed_block {|x| x.to_s }
Foo.new.with_untyped_block {|x| x }
