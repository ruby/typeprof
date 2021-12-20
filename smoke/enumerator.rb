def hoge
  [1, 2, 3].map
end
def fuga
  1.then
end
hoge
fuga

__END__
# Classes
class Object
  private
  def hoge: -> Enumerator[Integer, untyped]
  def fuga: -> Enumerator[Integer, untyped]
end
