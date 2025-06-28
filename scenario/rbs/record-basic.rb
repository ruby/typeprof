## update: test.rbs
class BasicRecord
  def simple_record: -> { name: String, age: Integer }
end

## update: test.rb
class BasicRecord
  def get_record
    simple_record
  end
end

## assert: test.rb
class BasicRecord
  def get_record: -> { name: String, age: Integer }
end
