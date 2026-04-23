## update
class Foo
  def public_method = "public_method"

  private

  def private_method = "private_method"
end

## assert
class Foo
  def public_method: -> String
  private
  def private_method: -> String
end

## update
class Foo
  private def private_method = "private_method"
  public def public_method = "public_method"
end

## assert
class Foo
  private def private_method: -> String
  public def public_method: -> String
end

## update
class Foo
  private def private_method = "private_method"
  public def public_method = "public_method"
  def other_method = "other_method"
end

## assert
class Foo
  private def private_method: -> String
  public def public_method: -> String
  def other_method: -> String
end

## update
class Foo
  def private_method = "private_method"
  def public_method = "public_method"
  private :private_method
end

## assert
class Foo
  private def private_method: -> String
  def public_method: -> String
end
