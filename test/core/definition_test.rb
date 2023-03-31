require_relative "../helper"

module TypeProf::Core
  class DefinitionTest < Test::Unit::TestCase
    def test_definition
      core = Service.new

      core.update_file("test.rb", <<-END)
class Foo
  def initialize(n)
  end

  def foo(n)
  end
end

Foo.new(1).foo(1.0)
      END

      defs = core.definitions("test.rb", TypeProf::CodePosition.new(9, 5))
      assert_equal([["test.rb", TypeProf::CodeRange[2, 2, 3, 5]]], defs)

      defs = core.definitions("test.rb", TypeProf::CodePosition.new(9, 12))
      assert_equal([["test.rb", TypeProf::CodeRange[5, 2, 6, 5]]], defs)
    end
  end
end