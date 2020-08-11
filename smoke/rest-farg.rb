def foo
  a = ["", ""]
  "".start_with?("", *a)
end

__END__
# Classes
class Object
  def foo : -> bool
end
