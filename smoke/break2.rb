def foo
  1.times do |n|
    raise
  rescue
    break "str"
  end
end

foo

__END__
# Classes
class Object
  def foo : -> (Integer | String)
end
