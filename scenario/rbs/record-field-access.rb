## update: test.rbs
class RecordFieldAccess
  def get_person: -> { name: String, age: Integer }
end

## update: test.rb
class RecordFieldAccess
  def get_name
    person = get_person
    person[:name]
  end
end

## assert: test.rb
class RecordFieldAccess
  def get_name: -> String
end
