require_relative "../helper"

module TypeProf::Core
  class ASTInputTest < Test::Unit::TestCase
    def dump(service, path)
      service.dump_declarations(path)
    end

    def test_update_rb_ast_matches_update_rb_file
      src = "def foo(x) = x + 1\nfoo(1)\n"

      from_text = TypeProf::Core::Service.new({})
      from_text.update_rb_file("t.rb", src)

      from_ast = TypeProf::Core::Service.new({})
      assert_true(from_ast.update_rb_ast("t.rb", Prism.parse(src)))

      assert_equal(dump(from_text, "t.rb"), dump(from_ast, "t.rb"))
      assert_match(/def foo: \(Integer\) -> Integer/, dump(from_ast, "t.rb"))
    end

    def test_update_rb_ast_replaces_previous_analysis
      service = TypeProf::Core::Service.new({})
      service.update_rb_file("t.rb", "def foo = 1\n")
      assert_match(/def foo: -> Integer/, dump(service, "t.rb"))

      service.update_rb_ast("t.rb", Prism.parse("def foo = \"str\"\n"))
      assert_match(/def foo: -> String/, dump(service, "t.rb"))
      assert_not_match(/Integer/, dump(service, "t.rb"))
    end

    def test_update_rb_ast_keeps_comments
      src = <<~RUBY
        #: (String) -> Integer
        def foo(x) = x.size

        def bar
          foo(1) # typeprof:ignore
        end
      RUBY
      service = TypeProf::Core::Service.new({})
      service.update_rb_ast("t.rb", Prism.parse(src))

      assert_match(/def foo: \(String\) -> Integer/, dump(service, "t.rb"))
      diags = []
      service.diagnostics("t.rb") {|d| diags << d }
      assert_empty(diags)
    end

    def test_update_rb_ast_with_syntax_error_returns_false
      service = TypeProf::Core::Service.new({})
      assert_false(service.update_rb_ast("t.rb", Prism.parse("def foo(\n")))
    end

    def test_update_rb_ast_rejects_non_parse_result
      service = TypeProf::Core::Service.new({})
      assert_raise(ArgumentError) { service.update_rb_ast("t.rb", Prism.parse("1").value) }
      assert_raise(ArgumentError) { service.update_rb_ast("t.rb", "1") }
    end

    def test_update_rb_ast_honors_position_encoding
      service = TypeProf::Core::Service.new(position_encoding: Encoding::UTF_8)
      service.update_rb_ast("t.rb", Prism.parse("𐐀x = 1\n"))
      node = service.instance_variable_get(:@rb_text_nodes)["t.rb"]
      # "𐐀x = 1" ends at UTF-8 byte column 9 (4+1+1+1+1+1)
      assert_equal(9, node.body.stmts.first.code_range.last.column)
    end
  end
end
