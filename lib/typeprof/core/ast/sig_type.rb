module TypeProf::Core
  class AST
    class SIG_FUNC_TYPE < Node
      def initialize(raw_decl, raw_type_params, raw_block, lenv)
        super(raw_decl, lenv)
        if raw_block
          @block_required = raw_block.required
          @block = AST.create_rbs_func_type(raw_block, nil, nil, lenv)
        else
          @block_required = false
          @block = nil
        end

        # TODO?: param.variance, param.unchecked, param.upper_bound
        @type_params = raw_type_params ? raw_type_params.map {|param| param.name } : nil

        @req_positionals = raw_decl.type.required_positionals.map do |ty|
          raise "unsupported argument type: #{ ty.class }" if !ty.is_a?(RBS::Types::Function::Param)
          AST.create_rbs_type(ty.type, lenv)
        end
        @post_positionals = raw_decl.type.trailing_positionals.map do |ty|
          raise "unsupported argument type: #{ ty.class }" if !ty.is_a?(RBS::Types::Function::Param)
          AST.create_rbs_type(ty.type, lenv)
        end
        @opt_positionals = raw_decl.type.optional_positionals.map do |ty|
          raise "unsupported argument type: #{ ty.class }" if !ty.is_a?(RBS::Types::Function::Param)
          AST.create_rbs_type(ty.type, lenv)
        end
        param = raw_decl.type.rest_positionals
        @rest_positionals = param ? AST.create_rbs_type(param.type, lenv) : nil
        #@required_keywords = func.required_keywords
        #@optional_keywords = func.optional_keywords
        #@rest_keywords = func.rest_keywords
        @return_type = AST.create_rbs_type(raw_decl.type.return_type, lenv)
      end

      attr_reader :type_params, :block, :block_required
      attr_reader :req_positionals
      attr_reader :post_positionals
      attr_reader :opt_positionals
      attr_reader :rest_positionals
      attr_reader :return_type

      def subnodes = {
        block:,
        req_positionals:,
        post_positionals:,
        opt_positionals:,
        rest_positionals:,
        return_type:,
      }
      def attrs = { type_params:, block_required: }
    end

    class TypeNode < Node
      def covariant_vertex(genv, changes, subst)
        vtx = changes.new_vertex(genv, self, subst)
        covariant_vertex0(genv, changes, vtx, subst)
        vtx
      end

      def contravariant_vertex(genv, changes, subst)
        vtx = Vertex.new("rbs_type", self)
        contravariant_vertex0(genv, changes, vtx, subst)
        vtx
      end
    end

    class SIG_TY_BASE_BOOL < TypeNode
      def covariant_vertex0(genv, changes, vtx, subst)
        changes.add_edge(Source.new(genv.true_type, genv.false_type), vtx)
      end

      def contravariant_vertex0(genv, changes, vtx, subst)
        Source.new(genv.true_type, genv.false_type).add_edge(genv, vtx)
      end
    end

    class SIG_TY_BASE_NIL < TypeNode
      def covariant_vertex0(genv, changes, vtx, subst)
        changes.add_edge(Source.new(genv.nil_type), vtx)
      end

      def contravariant_vertex0(genv, changes, vtx, subst)
        Source.new(genv.nil_type).add_edge(genv, vtx)
      end
    end

    class SIG_TY_BASE_SELF < TypeNode
      def covariant_vertex0(genv, changes, vtx, subst)
        changes.add_edge(subst[:"*self"], vtx)
      end

      def contravariant_vertex0(genv, changes, vtx, subst)
        subst[:"*self"].add_edge(genv, vtx)
      end
    end

    class SIG_TY_BASE_VOID < TypeNode
      def covariant_vertex0(genv, changes, vtx, subst)
        changes.add_edge(Source.new(genv.obj_type), vtx)
      end

      def contravariant_vertex0(genv, changes, vtx, subst)
        Source.new(genv.obj_type).add_edge(genv, vtx)
      end
    end

    class SIG_TY_BASE_ANY < TypeNode
      def covariant_vertex0(genv, changes, vtx, subst)
      end

      def contravariant_vertex0(genv, changes, vtx, subst)
        Source.new(genv.obj_type).add_edge(genv, vtx) # TODO
      end
    end

    class SIG_TY_BASE_TOP < TypeNode
      def covariant_vertex0(genv, changes, vtx, subst)
        # TODO
      end

      def contravariant_vertex0(genv, changes, vtx, subst)
        # TODO
      end
    end

    class SIG_TY_BASE_BOTTOM < TypeNode
      def covariant_vertex0(genv, changes, vtx, subst)
        changes.add_edge(Source.new(Type::Bot.new(genv)), vtx)
      end

      def contravariant_vertex0(genv, changes, vtx, subst)
        Source.new(Type::Bot.new(genv)).add_edge(genv, vtx)
      end
    end

    class SIG_TY_BASE_INSTANCE < TypeNode
      def covariant_vertex0(genv, changes, vtx, subst)
        changes.add_edge(subst[:"*instance"], vtx)
      end

      def contravariant_vertex0(genv, changes, vtx, subst)
        subst[:"*instance"].add_edge(genv, vtx)
      end
    end

    class SIG_TY_BASE_CLASS < TypeNode
      def covariant_vertex0(genv, changes, vtx, subst)
        changes.add_edge(subst[:"*class"], vtx)
      end

      def contravariant_vertex0(genv, changes, vtx, subst)
        subst[:"*class"].add_edge(genv, vtx)
      end
    end

    class SIG_TY_ALIAS < TypeNode
      def initialize(raw_decl, lenv)
        super
        name = raw_decl.name
        @cpath = name.namespace.path
        @toplevel = name.namespace.absolute?
        @name = name.name
        @args = raw_decl.args.map {|arg| AST.create_rbs_type(arg, lenv) }
      end

      attr_reader :cpath, :toplevel, :name, :args
      def subnodes = { args: }
      def attrs = { cpath:, toplevel:, name: }

      def define0(genv)
        @args.each {|arg| arg.define(genv) }

        static_reads = []
        if @cpath.empty?
          static_reads << BaseTypeAliasRead.new(genv, @name, @toplevel ? CRef::Toplevel : @lenv.cref)
        else
          static_reads << BaseConstRead.new(genv, @cpath.first, @toplevel ? CRef::Toplevel : @lenv.cref)
          @cpath[1..].each do |cname|
            static_reads << ScopedConstRead.new(cname, static_reads.last)
          end
          static_reads << ScopedTypeAliasRead.new(@name, static_reads.last)
        end
        static_reads
      end

      def undefine0(genv)
        @static_ret.each do |static_read|
          static_read.destroy(genv)
        end
        @args.each {|arg| arg.undefine(genv) }
      end

      def covariant_vertex0(genv, changes, vtx, subst)
        changes.add_depended_static_read(@static_ret.last)
        tae = @static_ret.last.type_alias_entity
        if tae && tae.exist?
          tae.type.covariant_vertex0(genv, changes, vtx, subst)
        end
      end

      def contravariant_vertex0(genv, changes, vtx, subst)
        changes.add_depended_static_read(@static_ret.last)
        tae = @static_ret.last.type_alias_entity
        if tae && tae.exist?
          tae.type.contravariant_vertex0(genv, changes, vtx, subst)
        end
        # TODO: report?
      end
    end

    class SIG_TY_UNION < TypeNode
      def initialize(raw_decl, lenv)
        super
        @types = raw_decl.types.map {|type| AST.create_rbs_type(type, lenv) }
      end

      attr_reader :types

      def subnodes = { types: }

      def covariant_vertex0(genv, changes, vtx, subst)
        @types.each do |type|
          type.covariant_vertex0(genv, changes, vtx, subst)
        end
      end

      def contravariant_vertex0(genv, changes, vtx, subst)
        @types.each do |type|
          type.contravariant_vertex0(genv, changes, vtx, subst)
        end
      end
    end

    class SIG_TY_INTERSECTION < TypeNode
      def covariant_vertex0(genv, changes, vtx, subst)
        #raise NotImplementedError
      end

      def contravariant_vertex0(genv, changes, vtx, subst)
        #raise NotImplementedError
      end
    end

    class SIG_TY_SINGLETON < TypeNode
      def initialize(raw_decl, lenv)
        super
        name = raw_decl.name
        @cpath = name.namespace.path + [name.name]
        @toplevel = name.namespace.absolute?
      end

      attr_reader :cpath, :toplevel
      def attrs = { cpath:, toplevel: }

      def define0(genv)
        const_reads = []
        const_read = BaseConstRead.new(genv, @cpath.first, @toplevel ? CRef::Toplevel : @lenv.cref)
        const_reads << const_read
        unless @cpath.empty?
          @cpath[1..].each do |cname|
            const_read = ScopedConstRead.new(cname, const_read)
            const_reads << const_read
          end
        end
        const_reads
      end

      def undefine0(genv)
        @static_ret.each do |const_read|
          const_read.destroy(genv)
        end
      end

      def covariant_vertex0(genv, changes, vtx, subst)
        # TODO: type.args
        changes.add_depended_static_read(@static_ret.last)
        cpath = @static_ret.last.cpath
        return unless cpath
        mod = genv.resolve_cpath(cpath)
        changes.add_edge(Source.new(Type::Singleton.new(genv, mod)), vtx)
      end

      def contravariant_vertex0(genv, changes, vtx, subst)
        # TODO: type.args
        changes.add_depended_static_read(@static_ret.last)
        cpath = @static_ret.last.cpath
        return unless cpath
        mod = genv.resolve_cpath(cpath)
        Source.new(Type::Singleton.new(genv, mod)).add_edge(genv, vtx)
      end
    end

    class SIG_TY_INSTANCE < TypeNode
      def initialize(raw_decl, lenv)
        super
        name = raw_decl.name
        @cpath = name.namespace.path + [name.name]
        @toplevel = name.namespace.absolute?
        @args = raw_decl.args.map {|arg| AST.create_rbs_type(arg, lenv) }
      end

      attr_reader :cpath, :toplevel, :args
      def subnodes = { args: }
      def attrs = { cpath:, toplevel: }

      def define0(genv)
        @args.each {|arg| arg.define(genv) }
        const_reads = []
        const_read = BaseConstRead.new(genv, @cpath.first, @toplevel ? CRef::Toplevel : @lenv.cref)
        const_reads << const_read
        unless @cpath.empty?
          @cpath[1..].each do |cname|
            const_read = ScopedConstRead.new(cname, const_read)
            const_reads << const_read
          end
        end
        const_reads
      end

      def undefine0(genv)
        @static_ret.each do |const_read|
          const_read.destroy(genv)
        end
        @args.each {|arg| arg.undefine(genv) }
      end

      def covariant_vertex0(genv, changes, vtx, subst)
        changes.add_depended_static_read(@static_ret.last)
        cpath = @static_ret.last.cpath
        return unless cpath
        mod = genv.resolve_cpath(cpath)
        args = @args.map {|arg| arg.covariant_vertex(genv, changes, subst) }
        changes.add_edge(Source.new(Type::Instance.new(genv, mod, args)), vtx)
      end

      def contravariant_vertex0(genv, changes, vtx, subst)
        changes.add_depended_static_read(@static_ret.last)
        cpath = @static_ret.last.cpath
        return unless cpath
        mod = genv.resolve_cpath(cpath)
        args = @args.map {|arg| arg.contravariant_vertex(genv, changes, subst) }
        Source.new(Type::Instance.new(genv, mod, args)).add_edge(genv, vtx)
      end
    end

    class SIG_TY_TUPLE < TypeNode
      def initialize(raw_decl, lenv)
        super
        @types = raw_decl.types.map {|type| AST.create_rbs_type(type, lenv) }
      end

      attr_reader :types
      def subnodes = { types: }

      def covariant_vertex0(genv, changes, vtx, subst)
        unified_elem = Vertex.new("ary-unified", self) # TODO
        elems = @types.map do |type|
          nvtx = type.covariant_vertex(genv, changes, subst)
          nvtx.add_edge(genv, unified_elem)
          nvtx
        end
        changes.add_edge(Source.new(Type::Array.new(genv, elems, genv.gen_ary_type(unified_elem))), vtx)
      end

      def contravariant_vertex0(genv, changes, vtx, subst)
        unified_elem = Vertex.new("ary-unified", self)
        elems = @types.map do |type|
          nvtx = type.contravariant_vertex(genv, changes, subst)
          nvtx.add_edge(genv, unified_elem)
          nvtx
        end
        Source.new(Type::Array.new(genv, elems, genv.gen_ary_type(unified_elem))).add_edge(genv, vtx)
      end
    end

    class SIG_TY_VAR < TypeNode
      def initialize(raw_decl, lenv)
        super
        @var = raw_decl.name
      end

      attr_reader :var

      def attrs = { var: }

      def covariant_vertex0(genv, changes, vtx, subst)
        raise "unknown type variable: #{ @var }" unless subst[@var]
        changes.add_edge(subst[@var], vtx)
      end

      def contravariant_vertex0(genv, changes, vtx, subst)
        raise "unknown type variable: #{ @var }" unless subst[@var]
        Source.new(Type::Var.new(genv, @var, subst[@var])).add_edge(genv, vtx)
      end
    end

    class SIG_TY_OPTIONAL < TypeNode
      def initialize(raw_decl, lenv)
        super
        @type = AST.create_rbs_type(raw_decl.type, lenv)
      end

      attr_reader :type
      def subnodes = { type: }

      def covariant_vertex0(genv, changes, vtx, subst)
        @type.covariant_vertex0(genv, changes, vtx, subst)
        changes.add_edge(Source.new(genv.nil_type), vtx)
      end

      def contravariant_vertex0(genv, changes, vtx, subst)
        @type.contravariant_vertex0(genv, changes, vtx, subst)
        Source.new(genv.nil_type).add_edge(genv, vtx)
      end
    end

    class SIG_TY_LITERAL < TypeNode
      def initialize(raw_decl, lenv)
        super
        @lit = raw_decl.literal
      end

      attr_reader :lit
      def attrs = { lit: }

      def get_type(genv)
        case @lit
        when ::Symbol
          Type::Symbol.new(genv, @lit)
        when ::Integer then genv.int_type
        when ::String then genv.str_type
        when ::TrueClass then genv.true_type
        when ::FalseClass then genv.false_type
        else
          raise "unknown RBS literal: #{ @lit.inspect }"
        end
      end

      def covariant_vertex0(genv, changes, vtx, subst)
        changes.add_edge(Source.new(get_type(genv)), vtx)
      end

      def contravariant_vertex0(genv, changes, vtx, subst)
        Source.new(get_type(genv)).add_edge(genv, vtx)
      end
    end

    class SIG_TY_PROC < TypeNode
      def covariant_vertex0(genv, changes, vtx, subst)
        raise NotImplementedError
      end

      def contravariant_vertex0(genv, changes, vtx, subst)
        raise NotImplementedError
      end
    end

    class SIG_TY_INTERFACE < TypeNode
      def covariant_vertex0(genv, changes, vtx, subst)
        #raise NotImplementedError
      end

      def contravariant_vertex0(genv, changes, vtx, subst)
        #raise NotImplementedError
      end
    end
  end
end