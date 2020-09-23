class A
  class B
    def foo
      unknown
    end
  end
end

def bar
  A::B.new.foo + 1
end

__END__
# Errors
smoke/manual-rbs2.rb:4: [error] undefined method: A::B.class#unknown

# Classes
class Object
  def bar : -> untyped
end
