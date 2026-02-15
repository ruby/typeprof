## update: test.rbs
class RecordSymbolAccess
  def get_person: -> { name: String, age: Integer }
end

## update: test.rb
class RecordSymbolAccess
  def get_field(key)
    person = get_person
    person[key]
  end
end

## assert: test.rb
class RecordSymbolAccess
  def get_field: (untyped) -> (Integer | String)?
end
