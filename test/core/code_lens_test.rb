require_relative "../helper"

module TypeProf::Core
  class CodeLensTest < Test::Unit::TestCase
    def test_code_lens
      core = Service.new

      core.update_file("test.rb", <<-END)
class Foo
  def foo(n)
    1
  end

  def bar(n)
    "str"
  end
end

def test(x)
  x
end

Foo.new.foo(1.0)
test(Foo.new)
      END

      lens = []
      core.code_lens("test.rb") do |cr, hint|
        lens << [cr, hint]
      end
      assert_equal(3, lens.size)
      assert_equal([TypeProf::CodeRange[2, 2, 2, 3], "def foo: (Float) -> Integer"], lens[0])
      assert_equal([TypeProf::CodeRange[6, 2, 6, 3], "def bar: (untyped) -> String"], lens[1])
      assert_equal([TypeProf::CodeRange[11, 0, 11, 1], "def test: (Foo) -> Foo"], lens[2])
    end

    def test_code_lens_updated
      core = Service.new

      core.update_file("test.rb", <<-END)
class Foo
  def foo(n)
    1
  end
end
      END

      lens = []
      core.code_lens("test.rb") do |cr, hint|
        lens << [cr, hint]
      end
      assert_equal(1, lens.size)
      assert_equal([TypeProf::CodeRange[2, 2, 2, 3], "def foo: (untyped) -> Integer"], lens[0])

      core.update_file("test.rb", <<-END)
class Foo
  # a line added
  def foo(n)
    1
  end
end
      END

      lens = []
      core.code_lens("test.rb") do |cr, hint|
        lens << [cr, hint]
      end
      assert_equal(1, lens.size)
      assert_equal([TypeProf::CodeRange[3, 2, 3, 3], "def foo: (untyped) -> Integer"], lens[0])
    end
  end
end