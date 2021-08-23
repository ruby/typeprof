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

      def scope1(param0)
        var0 = 1
        puts var0
      end

      def scope1(param0, param1, param2)
        var0 = 1
        var1 = 1
        puts var0
        puts var1
        puts param0
        puts param1
        puts param2
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

      # param with local var
      defs = definition_table[CodeLocation.new(24, 7)].to_a
      assert_equal(defs[0][1].inspect, "(23,2)-(23,10)")

      defs = definition_table[CodeLocation.new(30, 7)].to_a
      assert_equal(defs[0][1].inspect, "(28,2)-(28,10)")
      defs = definition_table[CodeLocation.new(30, 7)].to_a
      assert_equal(defs[0][1].inspect, "(28,2)-(28,10)")
      defs = definition_table[CodeLocation.new(31, 7)].to_a
      assert_equal(defs[0][1].inspect, "(29,2)-(29,10)")
    end

    test "analyze instance variable definition" do
        _, definition_table = analyze(<<~EOS)
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

        class C
          def read_write
            _ = @bar
            @bar = 1
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

        # use before def
        defs = definition_table[CodeLocation.new(21, 9)].to_a
        assert_equal(defs[0][1].inspect, "(22,4)-(22,12)")
    end

    test "analyze const definition" do
      _, definition_table = analyze(<<~EOS)
      class A
      end
      def get_a
        A
      end

      class B
        class C; end
      end
      def get_c
        B::C
      end

      def get_undef
        Undef
      end

      FOO = 1
      def get_foo
        FOO
      end
      class D
        BAR = 2
        class E
          BAR
          BAR = 3
          def get_bar
            BAR
          end
        end
      end
      class F; end
      class F; end
      def get_f
        F
      end
      EOS

      # get a single const def
      defs = definition_table[CodeLocation.new(4, 2)].to_a
      assert_equal(defs[0][1].inspect, "(1,0)-(2,3)")

      # get nested const def
      defs = definition_table[CodeLocation.new(11, 2)].to_a
      assert_equal(defs[0][1].inspect, "(7,0)-(9,3)")
      defs = definition_table[CodeLocation.new(11, 5)].to_a
      assert_equal(defs[0][1].inspect, "(8,2)-(8,14)")

      # get undefined const
      defs = definition_table[CodeLocation.new(15, 2)].to_a
      assert_empty(defs)

      # get non-class const
      defs = definition_table[CodeLocation.new(20, 2)].to_a
      assert_equal(defs[0][1].inspect, "(18,0)-(18,7)")

      # cref chain resolution
      defs = definition_table[CodeLocation.new(25, 4)].to_a
      assert_equal(defs[0][1].inspect, "(23,2)-(23,9)")
      defs = definition_table[CodeLocation.new(28, 6)].to_a
      assert_equal(defs[0][1].inspect, "(26,4)-(26,11)")

      # multi-opened class ref
      defs = definition_table[CodeLocation.new(35, 2)].to_a
      assert_equal(defs[0][1].inspect, "(32,0)-(32,12)")
      assert_equal(defs[1][1].inspect, "(33,0)-(33,12)")
    end

    test "analyze method callers" do
      _, _, caller_table = analyze(<<~EOS)
      class A
        def callee0
        end

        def callee1
        end

        def callee3
        end

        def callee4
        end

        def callee5
        end

        def caller0
          self.callee0
        end

        def caller5_0
          self.callee5
        end

        def caller5_1
          self.callee5
        end
      end

      class B < A
        def callee1
        end

        def caller1
          self.callee1
        end

        def callee4
        end
      end

      def caller3
        a = A.new
        a.callee3
      end

      def has_some_candidates(a)
        a.callee4
      end
      has_some_candidates(A.new)
      has_some_candidates(B.new)

      class C
        def callee6
        end
        define_method :caller6 do
          self.callee6
        end

        define_method :callee7 do
        end
        def caller7
          self.callee7
        end
      end

      class D
        def self.callee8
        end
        def self   .   callee9
        end
        class << self
          def caller8
            callee8
            callee9
          end
        end
      end
      EOS

      # single caller from the same class method
      callers = caller_table[CodeLocation.new(2, 7)].to_a
      assert_equal(callers[0][1].inspect, "(18,4)-(18,16)")
      # calee range should include only method name
      assert_empty(caller_table[CodeLocation.new(3, 4)].to_a)

      # no direct call because it's overridden in the caller class
      callers = caller_table[CodeLocation.new(5, 7)].to_a
      assert_empty(callers)

      # direct call from an outer method
      callers = caller_table[CodeLocation.new(8, 7)].to_a
      assert_equal(callers[0][1].inspect, "(44,2)-(44,11)")

      # indirect call due to some candidates
      callers = caller_table[CodeLocation.new(11, 7)].to_a
      assert_equal(callers[0][1].inspect, "(48,2)-(48,11)")
      callers = caller_table[CodeLocation.new(38, 7)].to_a
      assert_equal(callers[0][1].inspect, "(48,2)-(48,11)")

      # multiple callers
      callers = caller_table[CodeLocation.new(14, 7)].to_a
      assert_equal(callers.length, 2)
      assert_equal(callers[0][1].inspect, "(22,4)-(22,16)")
      assert_equal(callers[1][1].inspect, "(26,4)-(26,16)")

      # call from a method defined by define_method
      callers = caller_table[CodeLocation.new(54, 7)].to_a
      assert_equal(callers[0][1].inspect, "(57,4)-(57,16)")

      # call to a method defined by define_method
      callers = caller_table[CodeLocation.new(60, 17)].to_a
      assert_equal(callers[0][1].inspect, "(63,4)-(63,16)")

      # call to a class method
      callers = caller_table[CodeLocation.new(68, 12)].to_a
      assert_equal(callers[0][1].inspect, "(74,6)-(74,13)")
      callers = caller_table[CodeLocation.new(70, 18)].to_a
      assert_equal(callers[0][1].inspect, "(75,6)-(75,13)")
    end

    test "ensure threads write responses exclusively" do
      class Verifier
        def initialize(ctx)
          @rx = Thread::Queue.new
          @ctx = ctx
        end

        def read
          yield ({ id: 0, method: "initialize" })
          yield ({ method: "initialized" })
          yield ({
            method: "textDocument/didOpen",
            params: {
              textDocument: {
                uri: "file:///path/to/file.rb",
                languageId: "ruby",
                version: 1,
                text: <<~EOS
                  class Foo
                    def foo(a, b, c)
                      bar(a)
                    end
                    def bar(a)
                      1
                    end
                  end
                  if $0 == __FILE__
                    obj = Foo.new
                    obj.foo(1, "str", obj)
                    obj.bar(1)
                  end
                EOS
              }
            }
          })
          @ctx.assert_equal(@rx.pop[:id], 0)

          yield ({
            method: "textDocument/didChange",
            params: {
              textDocument: {
                uri: "file:///path/to/file.rb",
                version: 4
              },
              contentChanges: [
                {
                  range: {
                    start: { line: 6, character: 5 },
                    end:   { line: 6, character: 5 }
                  },
                  rangeLength: 0,
                  text: "."
                }
              ]
            }
          })

          @ctx.assert_equal(@rx.pop[:method], "workspace/codeLens/refresh")
          @ctx.assert_equal(@rx.pop[:method], "textDocument/publishDiagnostics")

          # id=1,2 are proceed in parallel
          yield ({
            id: 1,
            method: "textDocument/codeLens",
            params: {
              textDocument: { uri: "file:///path/to/file.rb" },
            }
          })

          yield ({
            id: 2,
            method: "textDocument/completion",
            params: {
              textDocument: { uri: "file:///path/to/file.rb" },
              position: { line: 6, character: 6 },
              context: { triggerKind: 2, triggerCharacter: "." }
            }
          })
          # receive id=1,2
          res1, res2 = @rx.pop, @rx.pop
          res = {
            res1[:id] => res1,
            res2[:id] => res2
          }
          @ctx.assert_not_empty(res[1][:result])
          @ctx.assert_not_empty(res[2][:result])
        end

        def write(**json)
          if @writing
            @ctx.assert(false, "non exclusive call")
          end
          @writing = true
          @rx << json
          @writing = false
        end
      end

      config = ConfigData.new(options: {
        lsp: true
      })
      verifier = Verifier.new(self)
      server = TypeProf::LSP::Server.new(config, verifier, verifier)
      server.run
    end
  end
end