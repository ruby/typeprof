## update: test.rbs
class RecordHashCompat
  def get_symbol_hash: -> Hash[Symbol, String | Integer]
  def accept_record: ({ name: String, age: Integer }) -> void
end

## update: test.rb
class RecordHashCompat
  def test_hash_to_record
    hash_data = get_symbol_hash
    accept_record(hash_data)
  end
end

## assert: test.rb
class RecordHashCompat
  def test_hash_to_record: -> Object
end
