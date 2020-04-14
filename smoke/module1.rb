module M
  def foo
    :foo
  end
end

class C
  include M
end

module M
  def bar
    :bar
  end
end

C.new.foo
C.new.bar

__END__
# Classes
class C
  include M
end
module M
  def foo : () -> :foo
  def bar : () -> :bar
end
