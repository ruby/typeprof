## update: test.rbs
class RecordTypeChecking
  def create_person: -> { name: String, age: Integer }
  def accept_person: ({ name: String, age: Integer }) -> String
  def process_user: ({ id: Integer, name: String, active: bool }) -> String
end

## update: test.rb
class RecordTypeChecking
  # Test case: Exact type matching
  # Record type created by method matches the parameter type exactly
  def test_exact_match
    person = create_person
    accept_person(person)
  end

  # Test case: Untyped parameter
  # Parameter without type annotation is passed to method expecting Record type
  def test_untyped_param(user_data)
    process_user(user_data)
  end
end

## assert: test.rb
class RecordTypeChecking
  def test_exact_match: -> String
  def test_untyped_param: (untyped) -> String
end
