## update: test.rbs
class RecordFieldError
  def get_person: -> { name: String, age: Integer }
end

## update: test.rb
class RecordFieldError
  def get_unknown_field
    person = get_person
    person[:unknown]  # Access non-existent field
  end
end

## assert: test.rb
class RecordFieldError
  def get_unknown_field: -> untyped
end
