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
  def initialize: (k: Integer) -> void
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
  def initialize: (?k: :default | Integer) -> void
end
class Bar < Foo
end
