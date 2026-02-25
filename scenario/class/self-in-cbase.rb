## update
class Foo
  class self::Bar::Baz
  end
end

## assert
class Foo
  class Bar::Baz
  end
end

## update
class self::X
end

## assert

## diagnostics
(1,0)-(2,3): TypeProf cannot analyze a non-static class
