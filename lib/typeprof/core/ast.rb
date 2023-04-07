module TypeProf::Core
  class AST
    def self.parse_rb(path, src)
      begin
        verbose_back, $VERBOSE = $VERBOSE, nil
        raw_scope = RubyVM::AbstractSyntaxTree.parse(src, keep_tokens: true)
      rescue
        $VERBOSE = verbose_back
      end

      raise unless raw_scope.type == :SCOPE

      Fiber[:tokens] = raw_scope.all_tokens.map do |_idx, type, str, cr|
        row1, col1, row2, col2 = cr
        code_range = TypeProf::CodeRange[row1, col1, row2, col2]
        [type, str, code_range]
      end.compact.sort_by {|_type, _str, code_range| code_range.first }

      cref = CRef::Toplevel
      lenv = LocalEnv.new(path, cref, {})

      ProgramNode.new(raw_scope, lenv)
    end

    def self.create_node(raw_node, lenv)
      case raw_node.type

      # definition
      when :BLOCK then BLOCK.new(raw_node, lenv)
      when :MODULE then MODULE.new(raw_node, lenv)
      when :CLASS then CLASS.new(raw_node, lenv)
      when :DEFN then DEFN.new(raw_node, lenv)
      when :DEFS then DEFS.new(raw_node, lenv)
      when :ALIAS then ALIAS.new(raw_node, lenv)
      when :BEGIN then BEGIN_.new(raw_node, lenv)

      # control
      when :IF then IF.new(raw_node, lenv)
      when :UNLESS then UNLESS.new(raw_node, lenv)
      when :WHILE then WHILE.new(raw_node, lenv)
      when :UNTIL then UNTIL.new(raw_node, lenv)
      when :BREAK then BREAK.new(raw_node, lenv)
      when :NEXT then NEXT.new(raw_node, lenv)
      when :REDO then REDO.new(raw_node, lenv)
      when :CASE then CASE.new(raw_node, lenv)
      when :AND then AND.new(raw_node, lenv)
      when :OR then OR.new(raw_node, lenv)
      when :RETURN then RETURN.new(raw_node, lenv)
      when :RESCUE then RESCUE.new(raw_node, lenv)

      # variable
      when :CONST, :COLON2, :COLON3
        create_const_node(raw_node, lenv)
      when :CDECL then CDECL.new(raw_node, lenv)
      when :GVAR then GVAR.new(raw_node, lenv)
      when :GASGN then GASGN.new(raw_node, lenv)
      when :IVAR then IVAR.new(raw_node, lenv)
      when :IASGN then IASGN.new(raw_node, lenv)
      when :LVAR, :DVAR then LVAR.new(raw_node, lenv)
      when :LASGN, :DASGN then LASGN.new(raw_node, lenv)
      when :MASGN then MASGN.new(raw_node, lenv)
      when :OP_ASGN_OR then OP_ASGN_OR.new(raw_node, lenv)

      # value
      when :SELF then SELF.new(raw_node, lenv)
      when :LIT then LIT.new(raw_node, lenv, raw_node.children.first)
      when :NIL then LIT.new(raw_node, lenv, nil)
      when :TRUE then LIT.new(raw_node, lenv, true) # Using LIT is OK?
      when :FALSE then LIT.new(raw_node, lenv, false) # Using LIT is OK?
      when :STR, :DSTR then STR.new(raw_node, lenv)
      when :ZLIST, :LIST then LIST.new(raw_node, lenv)
      when :HASH then HASH.new(raw_node, lenv)
      when :DOT2 then DOT2.new(raw_node, lenv)

      # misc
      when :DEFINED then DEFINED.new(raw_node, lenv)

      # call
      when :YIELD then YIELD.new(raw_node, lenv)
      when :OP_ASGN1 then OP_ASGN_AREF.new(raw_node, lenv)
      when :ITER
        raw_call, raw_block = raw_node.children
        AST.create_call_node(raw_node, raw_call, raw_block, lenv)
      else
        create_call_node(raw_node, raw_node, nil, lenv)
      end
    end

    def self.create_const_node(raw_node, lenv)
      case raw_node.type
      when :CONST
        cname, = raw_node.children
        CONST.new(raw_node, lenv, cname, false)
      when :COLON2
        cbase_raw, cname = raw_node.children
        if cbase_raw
          COLON2.new(raw_node, lenv)
        else
          # "C" of "class C" is not CONST but COLON2, but cbase is null.
          # This could be handled as CONST.
          CONST.new(raw_node, lenv, cname, false)
        end
      when :COLON3
        cname, = raw_node.children
        CONST.new(raw_node, lenv, cname, true)
      else
        raise "should not reach" # annotation
      end
    end

    def self.create_call_node(raw_node, raw_call, raw_block, lenv)
      if raw_call.type == :FCALL
        case raw_call.children[0]
        when :include
          return META_INCLUDE.new(raw_call, lenv)
        when :attr_reader
          return META_ATTR_READER.new(raw_call, lenv)
        when :attr_accessor
          return META_ATTR_ACCESSOR.new(raw_call, lenv)
        end
      end

      case raw_call.type
      when :CALL then CALL.new(raw_node, raw_call, raw_block, lenv)
      when :VCALL then VCALL.new(raw_node, raw_call, raw_block, lenv)
      when :FCALL then FCALL.new(raw_node, raw_call, raw_block, lenv)
      when :OPCALL then OPCALL.new(raw_node, raw_call, raw_block, lenv)
      when :ATTRASGN then ATTRASGN.new(raw_node, raw_call, raw_block, lenv)
      when :SUPER, :ZSUPER then SUPER.new(raw_node, raw_call, raw_block, lenv)
      else
        pp raw_node
        raise "not supported yet: #{ raw_node.type }"
      end
    end

    def self.parse_cpath(raw_node, base_cpath)
      names = []
      while raw_node
        case raw_node.type
        when :CONST
          name, = raw_node.children
          names << name
          break
        when :COLON2
          raw_node, name = raw_node.children
          names << name
        when :COLON3
          name, = raw_node.children
          names << name
          return names.reverse
        else
          return nil
        end
      end
      return base_cpath + names.reverse
    end

    def self.find_sym_code_range(start_pos, sym)
      return nil if sym == :[] || sym == :[]=
      tokens = Fiber[:tokens]
      i = tokens.bsearch_index {|_type, _str, code_range| start_pos <= code_range.first }
      if i
        while tokens[i]
          type, str, code_range = tokens[i]
          return code_range if (type == :tIDENTIFIER || type == :tFID) && str == sym.to_s
          i += 1
        end
      end
      return nil
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
      when RBS::AST::Declarations::Constant
        SIG_CONST.new(raw_decl, lenv)
      when RBS::AST::Declarations::AliasDecl
      when RBS::AST::Declarations::TypeAlias
        SIG_TYPE_ALIAS.new(raw_decl, lenv)
        # TODO: check
      when RBS::AST::Declarations::Interface
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

    def self.create_rbs_method_type(raw_decl, lenv)
      SIG_METHOD_TYPE.new(raw_decl, lenv)
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
        SIG_TY_MODULE.new(raw_decl, lenv)
      when RBS::Types::ClassInstance
        SIG_TY_INSTANCE.new(raw_decl, lenv)
      when RBS::Types::Tuple
        SIG_TY_TUPLE.new(raw_decl, lenv)
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
      when RBS::Types::Function::Param
        SIG_TY_PARAM.new(raw_decl, lenv)
      else
        raise "unknown RBS type: #{ raw_decl.class }"
      end
    end
  end
end