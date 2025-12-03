## update: my_error.rb
MyError = Class.new(StandardError)

## update: test.rb
class C
  def foo
  rescue MyError => e
    raise ArgumentError, e.message
  end
end

## assert: test.rb
class C
  def foo: -> nil
end
