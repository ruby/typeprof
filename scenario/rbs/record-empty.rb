## update: test.rbs
class EmptyRecord
  def empty_record: -> {  }
end

## update: test.rb
class EmptyRecord
  def get_empty
    empty_record
  end
end

## assert: test.rb
class EmptyRecord
  def get_empty: -> {  }
end
