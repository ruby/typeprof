module TypeProf::Core
  class AST
    class SigFuncType < Node
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

        if raw_decl.type.is_a?(RBS::Types::Function)
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

          @req_keywords = raw_decl.type.required_keywords.to_h do |key, ty|
            raise "unsupported argument type: #{ ty.class }" if !ty.is_a?(RBS::Types::Function::Param)
            [key, AST.create_rbs_type(ty.type, lenv)]
          end
          @opt_keywords = raw_decl.type.optional_keywords.to_h do |key, ty|
            raise "unsupported argument type: #{ ty.class }" if !ty.is_a?(RBS::Types::Function::Param)
            [key, AST.create_rbs_type(ty.type, lenv)]
          end
          param = raw_decl.type.rest_keywords
          @rest_keywords = param ? AST.create_rbs_type(param.type, lenv) : nil
        else
          # RBS::Types::UntypedFunction
          @req_positionals = []
          @post_positionals = []
          @opt_positionals = []
          @rest_positionals = SigTyBaseAnyNode.new(raw_decl, lenv)
          @req_keywords = {}
          @opt_keywords = {}
          @rest_keywords = nil
        end

        @return_type = AST.create_rbs_type(raw_decl.type.return_type, lenv)
      end

      attr_reader :type_params, :block, :block_required
      attr_reader :req_positionals
      attr_reader :post_positionals
      attr_reader :opt_positionals
      attr_reader :rest_positionals
      attr_reader :req_keywords
      attr_reader :opt_keywords
      attr_reader :rest_keywords
      attr_reader :return_type

      def subnodes = {
        block:,
        req_positionals:,
        post_positionals:,
        opt_positionals:,
        rest_positionals:,
        req_keywords:,
        opt_keywords:,
        rest_keywords:,
        return_type:,
      }
      def attrs = { type_params:, block_required: }
    end

    class SigTyNode < Node
      def covariant_vertex(genv, changes, subst)
        vtx = changes.new_covariant_vertex(genv, self)
        covariant_vertex0(genv, changes, vtx, subst)
        vtx
      end

      def contravariant_vertex(genv, changes, subst)
        vtx = changes.new_contravariant_vertex(genv, self)
        contravariant_vertex0(genv, changes, vtx, subst)
        vtx
      end
    end

    class SigTyBaseBoolNode < SigTyNode
      def covariant_vertex0(genv, changes, vtx, subst)
        changes.add_edge(genv, Source.new(genv.true_type, genv.false_type), vtx)
      end

      def contravariant_vertex0(genv, changes, vtx, subst)
        changes.add_edge(genv, Source.new(genv.true_type, genv.false_type), vtx)
      end

      def show
        "bool"
      end
    end

    class SigTyBaseNilNode < SigTyNode
      def covariant_vertex0(genv, changes, vtx, subst)
        changes.add_edge(genv, Source.new(genv.nil_type), vtx)
      end

      def contravariant_vertex0(genv, changes, vtx, subst)
        changes.add_edge(genv, Source.new(genv.nil_type), vtx)
      end

      def show
        "nil"
      end
    end

    class SigTyBaseSelfNode < SigTyNode
      def covariant_vertex0(genv, changes, vtx, subst)
        changes.add_edge(genv, subst[:"*self"], vtx)
      end

      def contravariant_vertex0(genv, changes, vtx, subst)
        changes.add_edge(genv, subst[:"*self"], vtx)
      end

      def show
        "self"
      end
    end

    class SigTyBaseVoidNode < SigTyNode
      def covariant_vertex0(genv, changes, vtx, subst)
        changes.add_edge(genv, Source.new(genv.obj_type), vtx)
      end

      def contravariant_vertex0(genv, changes, vtx, subst)
        changes.add_edge(genv, Source.new(genv.obj_type), vtx)
      end

      def show
        "void"
      end
    end

    class SigTyBaseAnyNode < SigTyNode
      def covariant_vertex0(genv, changes, vtx, subst)
      end

      def contravariant_vertex0(genv, changes, vtx, subst)
        #Source.new(genv.obj_type).add_edge(genv, vtx) # TODO
      end

      def show
        "untyped"
      end
    end

    class SigTyBaseTopNode < SigTyNode
      def covariant_vertex0(genv, changes, vtx, subst)
        # TODO
      end

      def contravariant_vertex0(genv, changes, vtx, subst)
        # TODO
      end

      def show
        "top"
      end
    end

    class SigTyBaseBottomNode < SigTyNode
      def covariant_vertex0(genv, changes, vtx, subst)
        changes.add_edge(genv, Source.new(Type::Bot.new(genv)), vtx)
      end

      def contravariant_vertex0(genv, changes, vtx, subst)
        changes.add_edge(genv, Source.new(Type::Bot.new(genv)), vtx)
      end

      def show
        "bot"
      end
    end

    class SigTyBaseInstanceNode < SigTyNode
      def covariant_vertex0(genv, changes, vtx, subst)
        changes.add_edge(genv, subst[:"*instance"], vtx)
      end

      def contravariant_vertex0(genv, changes, vtx, subst)
        changes.add_edge(genv, subst[:"*instance"], vtx)
      end

      def show
        "instance"
      end
    end

    class SigTyBaseClassNode < SigTyNode
      def covariant_vertex0(genv, changes, vtx, subst)
        changes.add_edge(genv, subst[:"*class"], vtx)
      end

      def contravariant_vertex0(genv, changes, vtx, subst)
        changes.add_edge(genv, subst[:"*class"], vtx)
      end

      def show
        "class"
      end
    end

    class SigTyAliasNode < SigTyNode
      def initialize(raw_decl, lenv)
        super(raw_decl, lenv)
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
          # need to check tae decls are all consistent?
          decl = tae.decls.each {|decl| break decl }
          subst0 = subst.dup
          # raise if decl.params.size != @args.size # ?
          decl.params.zip(@args) do |param, arg|
            subst0[param] = arg.covariant_vertex(genv, changes, subst0) # passing subst0 is ok?
          end
          tae.type.covariant_vertex0(genv, changes, vtx, subst0)
        end
      end

      def contravariant_vertex0(genv, changes, vtx, subst)
        changes.add_depended_static_read(@static_ret.last)
        tae = @static_ret.last.type_alias_entity
        if tae && tae.exist?
          # need to check tae decls are all consistent?
          decl = tae.decls.each {|decl| break decl }
          subst0 = subst.dup
          # raise if decl.params.size != @args.size # ?
          decl.params.zip(@args) do |param, arg|
            subst0[param] = arg.contravariant_vertex(genv, changes, subst0)
          end
          tae.type.contravariant_vertex0(genv, changes, vtx, subst0)
        end
      end

      def show
        "(...alias...)"
      end
    end

    class SigTyUnionNode < SigTyNode
      def initialize(raw_decl, lenv)
        super(raw_decl, lenv)
        @types = (raw_decl.types || []).map {|type| AST.create_rbs_type(type, lenv) }
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

      def show
        @types.map {|ty| ty.show }.join(" | ")
      end
    end

    class SigTyIntersectionNode < SigTyNode
      def covariant_vertex0(genv, changes, vtx, subst)
        #raise NotImplementedError
      end

      def contravariant_vertex0(genv, changes, vtx, subst)
        #raise NotImplementedError
      end

      def show
        "(...intersection...)"
      end
    end

    class SigTySingletonNode < SigTyNode
      def initialize(raw_decl, lenv)
        super(raw_decl, lenv)
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
        changes.add_edge(genv, Source.new(Type::Singleton.new(genv, mod)), vtx)
      end

      def contravariant_vertex0(genv, changes, vtx, subst)
        # TODO: type.args
        changes.add_depended_static_read(@static_ret.last)
        cpath = @static_ret.last.cpath
        return unless cpath
        mod = genv.resolve_cpath(cpath)
        changes.add_edge(genv, Source.new(Type::Singleton.new(genv, mod)), vtx)
      end

      def show
        s = "::#{ @cpath.join("::") }"
        if !@args.empty?
          s << "[...]"
        end
        "singleton(#{ s })"
      end
    end

    class SigTyInstanceNode < SigTyNode
      def initialize(raw_decl, lenv)
        super(raw_decl, lenv)
        name = raw_decl.name
        @cpath = name.namespace.path + [name.name]
        @toplevel = name.namespace.absolute? # "::Foo" or "Foo"
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
        changes.add_edge(genv, Source.new(Type::Instance.new(genv, mod, args)), vtx)
      end

      def contravariant_vertex0(genv, changes, vtx, subst)
        changes.add_depended_static_read(@static_ret.last)
        cpath = @static_ret.last.cpath
        return unless cpath
        mod = genv.resolve_cpath(cpath)
        args = @args.map {|arg| arg.contravariant_vertex(genv, changes, subst) }
        changes.add_edge(genv, Source.new(Type::Instance.new(genv, mod, args)), vtx)
      end

      def show
        s = "::#{ @cpath.join("::") }"
        if !@args.empty?
          s << "[...]"
        end
        s
      end
    end

    class SigTyTupleNode < SigTyNode
      def initialize(raw_decl, lenv)
        super(raw_decl, lenv)
        @types = raw_decl.types.map {|type| AST.create_rbs_type(type, lenv) }
      end

      attr_reader :types
      def subnodes = { types: }

      def covariant_vertex0(genv, changes, vtx, subst)
        unified_elem = changes.new_covariant_vertex(genv, [self, :Elem]) # TODO
        elems = @types.map do |type|
          nvtx = type.covariant_vertex(genv, changes, subst)
          changes.add_edge(genv, nvtx, unified_elem)
          nvtx
        end
        changes.add_edge(genv, Source.new(Type::Array.new(genv, elems, genv.gen_ary_type(unified_elem))), vtx)
      end

      def contravariant_vertex0(genv, changes, vtx, subst)
        unified_elem = changes.new_contravariant_vertex(genv, [self, :Elem]) # TODO
        elems = @types.map do |type|
          nvtx = type.contravariant_vertex(genv, changes, subst)
          changes.add_edge(genv, nvtx, unified_elem)
          nvtx
        end
        changes.add_edge(genv, Source.new(Type::Array.new(genv, elems, genv.gen_ary_type(unified_elem))), vtx)
      end

      def show
        "[#{ @types.map {|ty| ty.show }.join(", ") }]"
      end
    end

    class SigTyRecordNode < SigTyNode
      def covariant_vertex0(genv, changes, vtx, subst)
        raise NotImplementedError
      end

      def contravariant_vertex0(genv, changes, vtx, subst)
        raise NotImplementedError
      end

      def show
        "(...record...)"
      end
    end

    class SigTyVarNode < SigTyNode
      def initialize(raw_decl, lenv)
        super(raw_decl, lenv)
        @var = raw_decl.name
      end

      attr_reader :var

      def attrs = { var: }

      def covariant_vertex0(genv, changes, vtx, subst)
        raise "unknown type variable: #{ @var }" unless subst[@var]
        changes.add_edge(genv, subst[@var], vtx)
      end

      def contravariant_vertex0(genv, changes, vtx, subst)
        raise "unknown type variable: #{ @var }" unless subst[@var]
        changes.add_edge(genv, Source.new(Type::Var.new(genv, @var, subst[@var])), vtx)
      end

      def show
        "#{ @var }"
      end
    end

    class SigTyOptionalNode < SigTyNode
      def initialize(raw_decl, lenv)
        super(raw_decl, lenv)
        @type = AST.create_rbs_type(raw_decl.type, lenv)
      end

      attr_reader :type
      def subnodes = { type: }

      def covariant_vertex0(genv, changes, vtx, subst)
        @type.covariant_vertex0(genv, changes, vtx, subst)
        changes.add_edge(genv, Source.new(genv.nil_type), vtx)
      end

      def contravariant_vertex0(genv, changes, vtx, subst)
        @type.contravariant_vertex0(genv, changes, vtx, subst)
        changes.add_edge(genv, Source.new(genv.nil_type), vtx)
      end

      def show
        s = @type.show
        if @type.is_a?(SigTyIntersectionNode) || @type.is_a?(SigTyUnionNode)
          s = "(#{ s })"
        end
        s + "?"
      end
    end

    class SigTyLiteralNode < SigTyNode
      def initialize(raw_decl, lenv)
        super(raw_decl, lenv)
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
        changes.add_edge(genv, Source.new(get_type(genv)), vtx)
      end

      def contravariant_vertex0(genv, changes, vtx, subst)
        changes.add_edge(genv, Source.new(get_type(genv)), vtx)
      end

      def show
        @lit.inspect
      end
    end

    class SigTyProcNode < SigTyNode
      def covariant_vertex0(genv, changes, vtx, subst)
        raise NotImplementedError
      end

      def contravariant_vertex0(genv, changes, vtx, subst)
        Source.new()
      end

      def show
        "(...proc...)"
      end
    end

    class SigTyInterfaceNode < SigTyNode
      def initialize(raw_decl, lenv)
        super(raw_decl, lenv)
        name = raw_decl.name
        @cpath = name.namespace.path + [name.name]

        @toplevel = name.namespace.absolute? # "::Foo" or "Foo"
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
        changes.add_edge(genv, Source.new(Type::Instance.new(genv, mod, args)), vtx)
      end

      def contravariant_vertex0(genv, changes, vtx, subst)
        changes.add_depended_static_read(@static_ret.last)
        cpath = @static_ret.last.cpath
        return unless cpath
        mod = genv.resolve_cpath(cpath)
        args = @args.map {|arg| arg.contravariant_vertex(genv, changes, subst) }
        changes.add_edge(genv, Source.new(Type::Instance.new(genv, mod, args)), vtx)
      end

      def show
        s = "::#{ @cpath.join("::") }"
        if !@args.empty?
          s << "[...]"
        end
        s
      end
    end
  end
end
