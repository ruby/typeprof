## update
class Foo
  def initialize(k:)
  end
end

class Bar < Foo
end

obj = rand < 0.5 ? Foo : Bar
obj.new(k: 1)

## assert
class Foo
  def initialize: (k: Integer) -> nil
end
class Bar < Foo
end

## update
class Foo
  def initialize(k: :default)
  end
end

class Bar < Foo
end

obj = rand < 0.5 ? Foo : Bar
obj.new(k: 1)

## assert
class Foo
  def initialize: (?k: :default | Integer) -> nil
end
class Bar < Foo
end
