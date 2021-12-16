class Foo
  def initialize(one, two, three, four)
  end

  def another
    1
  end
end
__END__
# Classes
class Foo
# def initialize: (
#                   String? one,
#                   String? two,
#                   String? three,
#                   String? four,
#                 ) -> void
  def another: -> Integer
end
