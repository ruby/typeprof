## update: test.rbs
class RecordArrays
  def get_users: -> Array[{ id: Integer, name: String }]
end

## update: test.rb
class RecordArrays
  def first_user
    users = get_users
    users.first
  end
end

## assert: test.rb
class RecordArrays
  def first_user: -> { id: Integer, name: String }
end
