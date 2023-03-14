require "test/unit"
require_relative "../lib/typeprof"

module TypeProf
  class MetaTest < Test::Unit::TestCase
    def test_attr_reader
      serv = TypeProf::Service.new

      serv.update_file("test0.rb", <<-END)
class Foo
  def initialize(x, y)
    @x = x
    @y = y
  end

  def foo
    x
  end

  attr_reader :x, :y
end
      END

      assert_equal(
        ["def foo: () -> untyped"],
        serv.get_method_sig([:Foo], false, :foo),
      )

      serv.update_file("test1.rb", <<-END)
Foo.new(1, 1.0)
      END

      assert_equal(
        ["def foo: () -> Integer"],
        serv.get_method_sig([:Foo], false, :foo),
      )

      serv.update_file("test1.rb", <<-END)
Foo.new(1.0, 1)
      END

      assert_equal(
        ["def foo: () -> Float"],
        serv.get_method_sig([:Foo], false, :foo),
      )
    end

    def test_attr_accessor
      serv = TypeProf::Service.new

      serv.update_file("test0.rb", <<-END)
class Foo
  attr_accessor :x

  def foo
    x
  end
end

foo = Foo.new
foo.x = "str"
      END

      assert_equal(
        ["def foo: () -> String"],
        serv.get_method_sig([:Foo], false, :foo),
      )
    end
  end
end
