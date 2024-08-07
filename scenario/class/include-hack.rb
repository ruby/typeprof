## update
module Foo
  module Bar
  end
end

module Baz
  include Foo
  include Bar
end

## assert
module Foo
  module Foo::Bar
  end
end
module Baz
end
