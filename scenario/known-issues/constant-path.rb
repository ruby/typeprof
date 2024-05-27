## update: test.rb
module Baz
  module Foo
    class Bar < ::Foo::Bar
    end
  end
end

module Foo
  class Bar
  end
end

## assert: test.rb
module Baz
  module Foo
    class Bar < ::Foo::Bar
    end
  end
end

module Foo
  class Bar
  end
end

## update: test.rb
class Foo
end

module Bar
  class Foo < Foo
  end
end

## assert: test.rb
class Foo
end

module Bar
  class Foo < ::Foo
  end
end
