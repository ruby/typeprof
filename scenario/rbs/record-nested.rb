## update: test.rbs
class NestedRecord
  def get_company: -> { name: String, owner: { name: String, age: Integer } }
end

## update: test.rb
class NestedRecord
  def get_owner_name
    company = get_company
    company[:owner][:name]
  end
end

## assert: test.rb
class NestedRecord
  def get_owner_name: -> String
end
