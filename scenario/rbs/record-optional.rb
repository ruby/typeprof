## update: test.rbs
class OptionalRecord
  def maybe_person: -> { name: String, age: Integer }?
end

## update: test.rb
class OptionalRecord
  def check_optional
    maybe_person
  end
end

## assert: test.rb
class OptionalRecord
  def check_optional: -> { name: String, age: Integer }?
end
