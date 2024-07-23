## update
def nth_group_of_last_match
  [$1, $2, $3, $4, $5, $6, $7, $8, $9, $10]
end

def back_reference
  $&
end

## assert
class Object
  def nth_group_of_last_match: -> [String, String, String, String, String, String, String, String, String, String]
  def back_reference: -> String
end
