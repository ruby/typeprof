require_relative "test_helper"
require_relative "../../lib/typeprof"

module TypeProf
  class LSPTest < Test::Unit::TestCase

    def analyze(content)
      config = ConfigData.new
      config.rbs_files = []
      config.rb_files = [["path/to/file", content]]
      config.options[:lsp] = true
      TypeProf.analyze(config)
    end

    test "analyze local variable definition" do
      _, definition_table = TypeProf::ISeq::compile_str(<<~EOS, "path/to/file")
      message = "Hello"
      puts(message) # `message = "Hello"`

      1.times do |n|
        puts(message) # `message = "Hello"`
      end

      ["Goodbye"].each do |message|
        puts(message) # not `message = "Hello"` but a parameter `|message|`
      end
      def foo(message)
        puts(message)
      end

      # getlocal before setlocal
      def scope0
        while (message = gets)
          puts(message)
        end
      end
      EOS
      # same level use
      defs = definition_table[CodeLocation.new(2, 5)].to_a
      assert_equal(defs[0][1].inspect, "(1,0)-(1,17)")
      # nested level use
      defs = definition_table[CodeLocation.new(5, 7)].to_a
      assert_equal(defs[0][1].inspect, "(1,0)-(1,17)")
      # block parameter use
      # FIXME: the range doesn't point the actual param range
      defs = definition_table[CodeLocation.new(9, 7)].to_a
      assert_equal(defs[0][1].inspect, "(8,0)-(8,1)")

      # method parameter use
      defs = definition_table[CodeLocation.new(12, 7)].to_a
      assert_equal(defs[0][1].inspect, "(11,0)-(11,1)")

      # getlocal before setlocal
      defs = definition_table[CodeLocation.new(18, 9)].to_a
      assert_equal(defs[0][1].inspect, "(17,9)-(17,23)")
    end

    test "analyze instance variable definition" do
        iseq, definition_table = analyze(<<~EOS)
        class A
          def get_foo
            @foo
          end
          def set_foo1
            @foo = 1
          end
          def set_foo2
            @foo = 2
          end
        end

        class B < A
          def get_foo_from_b
            @foo
          end
        end
        EOS

        # use in a class that defines the ivar
        defs = definition_table[CodeLocation.new(3, 4)].to_a
        assert_equal(defs[0][1].inspect, "(6,4)-(6,12)")
        assert_equal(defs[1][1].inspect, "(9,4)-(9,12)")

        # use in a class that inherits a class that defines the ivar
        # TODO: analyze ivar definition based on inheritance hierarchy
        # defs = definition_table[CodeLocation.new(15, 4)].to_a
        # assert_equal(defs[0][1].inspect, "(6,4)-(6,12)")
    end
  end
end