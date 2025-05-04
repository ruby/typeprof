## update: test.rbs
class Foo
  @@foo: String
end

## update: test.rb
class Foo
  def check
    @@foo
  end
end

## assert: test.rb
class Foo
  def check: -> String
end
