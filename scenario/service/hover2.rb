## update: test.rb
class C
  #: () -> Integer
  def foo
    "string"
  end

  def bar
    foo
#\
    ^[A]
  end
end

## hover: [A]
C#foo : -> Integer

## diagnostics
(4,4)-(4,12): expected: Integer; actual: String

## update: test.rb
class C
  #: () -> Integer?
  def foo
    "string"
  end

  def bar
    foo
#\
    ^[B]
  end
end

## hover: [B]
C#foo : -> Integer?

## update: test.rb
class C
  #: () -> (Integer | String)?
  def foo
    "string"
  end

  def bar
    foo
#\
    ^[C]
  end
end

# TODO: The above test is mainly for SIG_TYPE#show

## hover: [C]
C#foo : -> (Integer | String)?
