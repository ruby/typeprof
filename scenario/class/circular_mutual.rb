## update
class Foo
end

class Bar
  class Baz < Foo
  end
  class Foo < Baz
  end
end

## assert
class Foo
end
class Bar
  class Baz < Bar::Foo
  end
  class Foo # failed to identify its superclass
  end
end

## diagnostics
(7,14)-(7,17): circular inheritance
