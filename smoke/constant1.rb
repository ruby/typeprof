CONST = 1

class Foo
  CONST = "str"
  class Bar
    def get1
      CONST
    end

    def get2
      ::CONST
    end

    def get3
      Object::CONST
    end
  end
end

class Foo::Bar
  def get4
    CONST
  end
end

Foo::Bar.new.get1 # String
Foo::Bar.new.get2 # Integer
Foo::Bar.new.get3 # Integer
Foo::Bar.new.get4 # Integer

__END__
Foo::Bar#get1 :: () -> String
Foo::Bar#get2 :: () -> Integer
Foo::Bar#get3 :: () -> Integer
Foo::Bar#get4 :: () -> Integer
