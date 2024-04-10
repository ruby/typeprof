module TypeProf::Core
  class AST
    def self.parse_rb(path, src)
      result = Prism.parse(src)

      return nil unless result.errors.empty?

      # comments, errors, magic_comments
      raw_scope = result.value

      raise unless raw_scope.type == :program_node

      Fiber[:comments] = result.comments

      cref = CRef::Toplevel
      lenv = LocalEnv.new(path, cref, {})

      ProgramNode.new(raw_scope, lenv)
    end

    #: (untyped, TypeProf::Core::LocalEnv) -> TypeProf::Core::AST::Node
    def self.create_node(raw_node, lenv)
      while true
        case raw_node.type
        when :parentheses_node
          raw_node = raw_node.body
        when :implicit_node
          raw_node = raw_node.value
        else
          break
        end
      end

      case raw_node.type

      # definition
      when :statements_node then StatementsNode.new(raw_node, lenv)
      when :module_node then ModuleNode.new(raw_node, lenv)
      when :class_node then ClassNode.new(raw_node, lenv)
      when :def_node then DefNode.new(raw_node, lenv)
      when :alias_method_node then AliasNode.new(raw_node, lenv)

      # control
      when :and_node then AndNode.new(raw_node, lenv)
      when :or_node then OrNode.new(raw_node, lenv)
      when :if_node then IfNode.new(raw_node, lenv)
      when :unless_node then UnlessNode.new(raw_node, lenv)
      when :case_node then CaseNode.new(raw_node, lenv)
      when :while_node then WhileNode.new(raw_node, lenv)
      when :until_node then UntilNode.new(raw_node, lenv)
      when :break_node then BreakNode.new(raw_node, lenv)
      when :next_node then NextNode.new(raw_node, lenv)
      when :redo_node then RedoNode.new(raw_node, lenv)
      when :return_node then ReturnNode.new(raw_node, lenv)
      when :begin_node then BeginNode.new(raw_node, lenv)

      when :RESCUE then RESCUE.new(raw_node, lenv)
      when :ENSURE then ENSURE.new(raw_node, lenv)

      # constants
      when :constant_read_node, :constant_path_node
        ConstantReadNode.new(raw_node, lenv)
      when :constant_write_node, :constant_path_write_node
        ConstantWriteNode.new(raw_node, AST.create_node(raw_node.value, lenv), lenv)
      when :constant_operator_write_node
        read = ConstantReadNode.new(raw_node, lenv)
        rhs = OperatorNode.new(raw_node, read, lenv)
        ConstantWriteNode.new(raw_node, rhs, lenv)
      when :constant_or_write_node
        read = ConstantReadNode.new(raw_node, lenv)
        rhs = OrNode.new(raw_node, read, raw_node.value, lenv)
        ConstantWriteNode.new(raw_node, rhs, lenv)
      when :constant_and_write_node
        read = ConstantReadNode.new(raw_node, lenv)
        rhs = AndNode.new(raw_node, read, raw_node.value, lenv)
        ConstantWriteNode.new(raw_node, rhs, lenv)
      when :constant_path_operator_write_node
        read = ConstantReadNode.new(raw_node.target, lenv)
        rhs = OperatorNode.new(raw_node, read, lenv)
        ConstantWriteNode.new(raw_node, rhs, lenv)
      when :constant_path_or_write_node
        read = ConstantReadNode.new(raw_node.target, lenv)
        rhs = OrNode.new(raw_node, read, raw_node.value, lenv)
        ConstantWriteNode.new(raw_node, rhs, lenv)
      when :constant_path_and_write_node
        read = ConstantReadNode.new(raw_node.target, lenv)
        rhs = AndNode.new(raw_node, read, raw_node.value, lenv)
        ConstantWriteNode.new(raw_node, rhs, lenv)

      # variables
      when :local_variable_read_node
        LocalVariableReadNode.new(raw_node, lenv)
      when :local_variable_write_node
        LocalVariableWriteNode.new(raw_node, AST.create_node(raw_node.value, lenv), lenv)
      when :local_variable_operator_write_node
        read = LocalVariableReadNode.new(raw_node, lenv)
        rhs = OperatorNode.new(raw_node, read, lenv)
        LocalVariableWriteNode.new(raw_node, rhs, lenv)
      when :local_variable_or_write_node
        read = LocalVariableReadNode.new(raw_node, lenv)
        rhs = OrNode.new(raw_node, read, raw_node.value, lenv)
        LocalVariableWriteNode.new(raw_node, rhs, lenv)
      when :local_variable_and_write_node
        read = LocalVariableReadNode.new(raw_node, lenv)
        rhs = AndNode.new(raw_node, read, raw_node.value, lenv)
        LocalVariableWriteNode.new(raw_node, rhs, lenv)
      when :instance_variable_read_node
        InstanceVariableReadNode.new(raw_node, lenv)
      when :instance_variable_write_node
        InstanceVariableWriteNode.new(raw_node, AST.create_node(raw_node.value, lenv), lenv)
      when :instance_variable_operator_write_node
        read = InstanceVariableReadNode.new(raw_node, lenv)
        rhs = OperatorNode.new(raw_node, read, lenv)
        InstanceVariableWriteNode.new(raw_node, rhs, lenv)
      when :instance_variable_or_write_node
        read = InstanceVariableReadNode.new(raw_node, lenv)
        rhs = OrNode.new(raw_node, read, raw_node.value, lenv)
        InstanceVariableWriteNode.new(raw_node, rhs, lenv)
      when :instance_variable_and_write_node
        read = InstanceVariableReadNode.new(raw_node, lenv)
        rhs = AndNode.new(raw_node, read, raw_node.value, lenv)
        InstanceVariableWriteNode.new(raw_node, rhs, lenv)
      #TODO: when :class_variable_read_node...
      when :global_variable_read_node
        GlobalVariableReadNode.new(raw_node, lenv)
      when :global_variable_write_node
        GlobalVariableWriteNode.new(raw_node, AST.create_node(raw_node.value, lenv), lenv)
      when :global_variable_operator_write_node
        read = GlobalVariableReadNode.new(raw_node, lenv)
        rhs = OperatorNode.new(raw_node, read, lenv)
        GlobalVariableWriteNode.new(raw_node, rhs, lenv)
      when :global_variable_or_write_node
        read = GlobalVariableReadNode.new(raw_node, lenv)
        rhs = OrNode.new(raw_node, read, raw_node.value, lenv)
        GlobalVariableWriteNode.new(raw_node, rhs, lenv)
      when :global_variable_and_write_node
        read = GlobalVariableReadNode.new(raw_node, lenv)
        rhs = AndNode.new(raw_node, read, raw_node.value, lenv)
        GlobalVariableWriteNode.new(raw_node, rhs, lenv)

      # assignment targets
      when :index_operator_write_node
        read = IndexReadNode.new(raw_node, lenv)
        rhs = OperatorNode.new(raw_node, read, lenv)
        IndexWriteNode.new(raw_node, rhs, lenv)
      when :index_or_write_node
        read = IndexReadNode.new(raw_node, lenv)
        rhs = OrNode.new(raw_node, read, raw_node.value, lenv)
        IndexWriteNode.new(raw_node, rhs, lenv)
      when :index_and_write_node
        read = IndexReadNode.new(raw_node, lenv)
        rhs = AndNode.new(raw_node, read, raw_node.value, lenv)
        IndexWriteNode.new(raw_node, rhs, lenv)
      when :call_operator_write_node
        read = CallReadNode.new(raw_node, lenv)
        rhs = OperatorNode.new(raw_node, read, lenv)
        CallWriteNode.new(raw_node, rhs, lenv)
      when :call_or_write_node
        read = CallReadNode.new(raw_node, lenv)
        rhs = OrNode.new(raw_node, read, raw_node.value, lenv)
        CallWriteNode.new(raw_node, rhs, lenv)
      when :call_and_write_node
        read = CallReadNode.new(raw_node, lenv)
        rhs = AndNode.new(raw_node, read, raw_node.value, lenv)
        CallWriteNode.new(raw_node, rhs, lenv)
      when :multi_write_node then MultiWriteNode.new(raw_node, lenv)

      # value
      when :self_node then SelfNode.new(raw_node, lenv)
      when :nil_node then NilNode.new(raw_node, lenv)
      when :true_node then TrueNode.new(raw_node, lenv)
      when :false_node then FalseNode.new(raw_node, lenv)
      when :integer_node then IntegerNode.new(raw_node, lenv)
      when :float_node then FloatNode.new(raw_node, lenv)
      when :symbol_node then SymbolNode.new(raw_node, lenv)
      when :string_node then StringNode.new(raw_node, lenv, raw_node.content)
      when :source_file_node then StringNode.new(raw_node, lenv, "")
      when :interpolated_string_node then InterpolatedStringNode.new(raw_node, lenv)
      when :regular_expression_node then RegexpNode.new(raw_node, lenv)
      when :interpolated_regular_expression_node then InterpolatedRegexpNode.new(raw_node, lenv)
      when :range_node then RangeNode.new(raw_node, lenv)
      when :array_node then ArrayNode.new(raw_node, lenv)
      when :hash_node then HashNode.new(raw_node, lenv)

      # misc
      when :defined_node then DefinedNode.new(raw_node, lenv)

      # call
      when :super_node then SuperNode.new(raw_node, lenv)
      when :forwarding_super_node then ForwardingSuperNode.new(raw_node, lenv)
      when :yield_node then YieldNode.new(raw_node, lenv)
      when :call_node
        if !raw_node.receiver
          # TODO: handle them only when it is directly under class or module
          case raw_node.name
          when :include
            return IncludeMetaNode.new(raw_node, lenv)
          when :attr_reader
            return AttrReaderMetaNode.new(raw_node, lenv)
          when :attr_accessor
            return AttrAccessorMetaNode.new(raw_node, lenv)
          end
        end
        CallNode.new(raw_node, lenv)
      else
        pp raw_node
        raise "not supported yet: #{ raw_node.type }"
      end
    end

    def self.create_target_node(raw_node, lenv)
      dummy_node = DummyRHSNode.new(TypeProf::CodeRange.from_node(raw_node.location), lenv)
      case raw_node.type
      when :local_variable_target_node
        LocalVariableWriteNode.new(raw_node, dummy_node, lenv)
      when :instance_variable_target_node
        InstanceVariableWriteNode.new(raw_node, dummy_node, lenv)
      #when :class_variable_target_node
      when :global_variable_target_node
        GlobalVariableWriteNode.new(raw_node, dummy_node, lenv)
      when :constant_target_node
        ConstantWriteNode.new(raw_node, dummy_node, lenv)
      when :constant_path_target_node
        ConstantWriteNode.new(raw_node, dummy_node, lenv)
      when :index_target_node
        IndexWriteNode.new(raw_node, dummy_node, lenv)
      when :call_target_node
        CallWriteNode.new(raw_node, dummy_node, lenv)
      else
        pp raw_node
        raise "not supported yet: #{ raw_node.type }"
      end
    end

    def self.parse_cpath(raw_node, base_cpath)
      names = []
      while raw_node
        case raw_node.type
        when :constant_read_node
          names << raw_node.name
          break
        when :constant_path_node, :constant_path_target_node
          if raw_node.parent
            names << raw_node.child.name
            raw_node = raw_node.parent
          else
            return names.reverse
          end
        else
          return nil
        end
      end
      return base_cpath + names.reverse
    end

    def self.parse_rbs(path, src)
      _buffer, _directives, raw_decls = RBS::Parser.parse_signature(src)

      cref = CRef::Toplevel
      lenv = LocalEnv.new(path, cref, {})

      raw_decls.map do |raw_decl|
        AST.create_rbs_decl(raw_decl, lenv)
      end
    end

    def self.create_rbs_decl(raw_decl, lenv)
      case raw_decl
      when RBS::AST::Declarations::Class
        SIG_CLASS.new(raw_decl, lenv)
      when RBS::AST::Declarations::Module
        SIG_MODULE.new(raw_decl, lenv)
      when RBS::AST::Declarations::Interface
        SIG_INTERFACE.new(raw_decl, lenv)
      when RBS::AST::Declarations::Constant
        SIG_CONST.new(raw_decl, lenv)
      when RBS::AST::Declarations::AliasDecl
      when RBS::AST::Declarations::TypeAlias
        SIG_TYPE_ALIAS.new(raw_decl, lenv)
        # TODO: check
      when RBS::AST::Declarations::Global
        SIG_GVAR.new(raw_decl, lenv)
      else
        raise "unsupported: #{ raw_decl.class }"
      end
    end

    def self.create_rbs_member(raw_decl, lenv)
      case raw_decl
      when RBS::AST::Members::MethodDefinition
        SIG_DEF.new(raw_decl, lenv)
      when RBS::AST::Members::Include
        SIG_INCLUDE.new(raw_decl, lenv)
      when RBS::AST::Members::Extend
      when RBS::AST::Members::Public
      when RBS::AST::Members::Private
      when RBS::AST::Members::Alias
        SIG_ALIAS.new(raw_decl, lenv)
      when RBS::AST::Declarations::Base
        self.create_rbs_decl(raw_decl, lenv)
      else
        raise "unsupported: #{ raw_decl.class }"
      end
    end

    def self.create_rbs_func_type(raw_decl, raw_type_params, raw_block, lenv)
      SIG_FUNC_TYPE.new(raw_decl, raw_type_params, raw_block, lenv)
    end

    def self.create_rbs_type(raw_decl, lenv)
      case raw_decl
      when RBS::Types::Bases::Nil
        SIG_TY_BASE_NIL.new(raw_decl, lenv)
      when RBS::Types::Bases::Bool
        SIG_TY_BASE_BOOL.new(raw_decl, lenv)
      when RBS::Types::Bases::Self
        SIG_TY_BASE_SELF.new(raw_decl, lenv)
      when RBS::Types::Bases::Void
        SIG_TY_BASE_VOID.new(raw_decl, lenv)
      when RBS::Types::Bases::Any
        SIG_TY_BASE_ANY.new(raw_decl, lenv)
      when RBS::Types::Bases::Top
        SIG_TY_BASE_TOP.new(raw_decl, lenv)
      when RBS::Types::Bases::Bottom
        SIG_TY_BASE_BOTTOM.new(raw_decl, lenv)
      when RBS::Types::Bases::Instance
        SIG_TY_BASE_INSTANCE.new(raw_decl, lenv)
      when RBS::Types::Bases::Class
        SIG_TY_BASE_CLASS.new(raw_decl, lenv)

      when RBS::Types::Alias
        SIG_TY_ALIAS.new(raw_decl, lenv)
      when RBS::Types::Union
        SIG_TY_UNION.new(raw_decl, lenv)
      when RBS::Types::Intersection
        SIG_TY_INTERSECTION.new(raw_decl, lenv)
      when RBS::Types::ClassSingleton
        SIG_TY_SINGLETON.new(raw_decl, lenv)
      when RBS::Types::ClassInstance
        SIG_TY_INSTANCE.new(raw_decl, lenv)
      when RBS::Types::Tuple
        SIG_TY_TUPLE.new(raw_decl, lenv)
      when RBS::Types::Record
        SIG_TY_RECORD.new(raw_decl, lenv)
      when RBS::Types::Interface
        SIG_TY_INTERFACE.new(raw_decl, lenv)
      when RBS::Types::Proc
        SIG_TY_PROC.new(raw_decl, lenv)
      when RBS::Types::Variable
        SIG_TY_VAR.new(raw_decl, lenv)
      when RBS::Types::Optional
        SIG_TY_OPTIONAL.new(raw_decl, lenv)
      when RBS::Types::Literal
        SIG_TY_LITERAL.new(raw_decl, lenv)
      else
        raise "unknown RBS type: #{ raw_decl.class }"
      end
    end
  end
end
