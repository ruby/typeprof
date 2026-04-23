module TypeProf::Core
  class AST
    class IncludeMetaNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        # TODO: error for splat
        @args = raw_node.arguments.arguments.map do |raw_arg|
          next if raw_arg.is_a?(Prism::SplatNode)
          lenv.use_strict_const_scope do
            AST.create_node(raw_arg, lenv)
          end
        end.compact
        # TODO: error for non-LIT
        # TODO: fine-grained hover
      end

      attr_reader :args

      def subnodes = { args: }

      def define0(genv)
        mod = genv.resolve_cpath(@lenv.cref.cpath)
        @args.each do |arg|
          arg.define(genv)
          if arg.static_ret
            arg.static_ret.followers << mod
            mod.add_include_def(genv, arg)
          end
        end
      end

      def undefine0(genv)
        mod = genv.resolve_cpath(@lenv.cref.cpath)
        @args.each do |arg|
          if arg.static_ret
            mod.remove_include_def(genv, arg)
          end
          arg.undefine(genv)
        end
        super(genv)
      end

      def install0(genv)
        @args.each {|arg| arg.install(genv) }
        Source.new
      end
    end

    class AttrReaderMetaNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        @args = []
        raw_node.arguments.arguments.each do |raw_arg|
          @args << raw_arg.value.to_sym if raw_arg.type == :symbol_node
        end

        @rbs_method_type = nil
        inline_members = lenv.file_context.inline_members
        if inline_members
          member = inline_members[raw_node.object_id]
          if member.is_a?(RBS::AST::Ruby::Members::AttrReaderMember) && member.type
            rbs_method_type = RBS::MethodType.new(
              type: RBS::Types::Function.empty(member.type),
              type_params: [],
              block: nil,
              location: member.type.location
            )
            @rbs_method_type = AST.create_rbs_func_type(rbs_method_type, [], nil, lenv)
          end
        end
      end

      attr_reader :args, :rbs_method_type

      def subnodes = { rbs_method_type: }
      def attrs = { args: }

      def req_positionals = []
      def opt_positionals = []
      def post_positionals = []
      def rest_positionals = nil
      def req_keywords = []
      def opt_keywords = []
      def rest_keywords = nil

      def mname_code_range(name)
        idx = @args.index(name.to_sym) # TODO: support string args
        node = @raw_node.arguments.arguments[idx].location
        @lenv.code_range_from_node(node)
      end

      def install0(genv)
        @args.each do |arg|
          if @rbs_method_type
            @changes.add_method_decl_box(genv, @lenv.cref.cpath, false, arg, [@rbs_method_type], false)
          end
          ivar_name = :"@#{ arg }"
          ivar_box = @changes.add_ivar_read_box(genv, @lenv.cref.cpath, false, ivar_name)
          ret_box = @changes.add_escape_box(genv, ivar_box.ret)
          @changes.add_method_def_box(genv, @lenv.cref.cpath, false, arg, FormalArguments::Empty, [ret_box])
        end
        Source.new
      end
    end

    class AttrWriterMetaNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        @args = []
        raw_node.arguments.arguments.each do |raw_arg|
          @args << raw_arg.value.to_sym if raw_arg.type == :symbol_node
        end
      end

      attr_reader :args

      def attrs = { args: }

      def mname_code_range(name)
        idx = @args.index(name.to_sym)
        node = @raw_node.arguments.arguments[idx].location
        @lenv.code_range_from_node(node)
      end

      def define0(genv)
        @args.map do |arg|
          mod = genv.resolve_ivar(lenv.cref.cpath, false, :"@#{ arg }")
          mod.add_def(self)
          mod
        end
      end

      def define_copy(genv)
        @args.map do |arg|
          mod = genv.resolve_ivar(lenv.cref.cpath, false, :"@#{ arg }")
          mod.add_def(self)
          mod.remove_def(@prev_node)
          mod
        end
        super(genv)
      end

      def undefine0(genv)
        @args.each do |arg|
          mod = genv.resolve_ivar(lenv.cref.cpath, false, :"@#{ arg }")
          mod.remove_def(self)
        end
      end

      def install0(genv)
        @args.zip(@static_ret) do |arg, ive|
          vtx = Vertex.new(self)
          @changes.add_edge(genv, vtx, ive.vtx)
          ret_box = @changes.add_escape_box(genv, vtx)
          f_args = FormalArguments.new([vtx], [], nil, [], [], [], nil, nil)
          @changes.add_method_def_box(genv, @lenv.cref.cpath, false, :"#{ arg }=", f_args, [ret_box])
        end
        Source.new
      end
    end

    class AttrAccessorMetaNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        @args = []
        raw_node.arguments.arguments.each do |raw_arg|
          @args << raw_arg.value.to_sym if raw_arg.type == :symbol_node
        end

        @rbs_reader_method_type = nil
        @rbs_writer_method_type = nil
        inline_members = lenv.file_context.inline_members
        if inline_members
          member = inline_members[raw_node.object_id]
          if member.is_a?(RBS::AST::Ruby::Members::AttrAccessorMember) && member.type
            reader_rbs = RBS::MethodType.new(
              type: RBS::Types::Function.empty(member.type),
              type_params: [],
              block: nil,
              location: member.type.location
            )
            @rbs_reader_method_type = AST.create_rbs_func_type(reader_rbs, [], nil, lenv)
            writer_rbs = RBS::MethodType.new(
              type: RBS::Types::Function.new(
                required_positionals: [RBS::Types::Function::Param.new(name: nil, type: member.type, location: member.type.location)],
                optional_positionals: [],
                rest_positionals: nil,
                trailing_positionals: [],
                required_keywords: {},
                optional_keywords: {},
                rest_keywords: nil,
                return_type: member.type
              ),
              type_params: [],
              block: nil,
              location: member.type.location
            )
            @rbs_writer_method_type = AST.create_rbs_func_type(writer_rbs, [], nil, lenv)
          end
        end
      end

      attr_reader :args, :rbs_reader_method_type, :rbs_writer_method_type

      def subnodes = { rbs_reader_method_type:, rbs_writer_method_type: }
      def attrs = { args: }

      def mname_code_range(name)
        idx = @args.index(name.to_sym) # TODO: support string args
        node = @raw_node.arguments.arguments[idx].location
        @lenv.code_range_from_node(node)
      end

      def define0(genv)
        @args.map do |arg|
          mod = genv.resolve_ivar(lenv.cref.cpath, false, :"@#{ arg }")
          mod.add_def(self)
          mod
        end
      end

      def define_copy(genv)
        @args.map do |arg|
          mod = genv.resolve_ivar(lenv.cref.cpath, false, :"@#{ arg }")
          mod.add_def(self)
          mod.remove_def(@prev_node)
          mod
        end
        super(genv)
      end

      def undefine0(genv)
        @args.each do |arg|
          mod = genv.resolve_ivar(lenv.cref.cpath, false, :"@#{ arg }")
          mod.remove_def(self)
        end
      end

      def install0(genv)
        @args.zip(@static_ret) do |arg, ive|
          if @rbs_reader_method_type
            @changes.add_method_decl_box(genv, @lenv.cref.cpath, false, arg, [@rbs_reader_method_type], false)
          end
          if @rbs_writer_method_type
            @changes.add_method_decl_box(genv, @lenv.cref.cpath, false, :"#{ arg }=", [@rbs_writer_method_type], false)
          end

          ivar_box = @changes.add_ivar_read_box(genv, @lenv.cref.cpath, false, :"@#{ arg }")
          ret_box = @changes.add_escape_box(genv, ivar_box.ret)
          @changes.add_method_def_box(genv, @lenv.cref.cpath, false, arg, FormalArguments::Empty, [ret_box])

          vtx = Vertex.new(self)
          @changes.add_edge(genv, vtx, ive.vtx)
          f_args = FormalArguments.new([vtx], [], nil, [], [], [], nil, nil)
          @changes.add_method_def_box(genv, @lenv.cref.cpath, false, :"#{ arg }=", f_args, [ret_box])
        end
        Source.new
      end
    end
    class ModuleFunctionMetaNode < Node
      def install0(genv)
        @lenv.module_function = true
        Source.new
      end
    end

    class StructNewNode < Node
      def initialize(raw_node, members, kind, lenv)
        super(raw_node, lenv)
        case raw_node.type
        when :constant_write_node
          @static_cpath = lenv.cref.cpath + [raw_node.name]
        when :constant_path_write_node
          @static_cpath = AST.parse_cpath(raw_node.target, lenv.cref)
        else
          raise
        end
        @members = members
        @kind = kind # :struct or :data

        # Parse block body if present (Struct.new(:foo) do ... end)
        raw_value = raw_node.value
        if raw_value.block && raw_value.block.type == :block_node && raw_value.block.body
          ncref = CRef.new(@static_cpath, :instance, nil, lenv.cref)
          nlenv = LocalEnv.new(lenv.file_context, ncref, {}, [])
          @block_body = AST.create_node(raw_value.block.body, nlenv)
        end
      end

      attr_reader :static_cpath, :members, :kind, :block_body

      def subnodes = { block_body: }
      def attrs = { static_cpath:, members:, kind: }

      # Interface expected by MethodDefBox
      def req_positionals = @kind == :struct ? @members : []
      def opt_positionals = []
      def rest_positionals = nil
      def post_positionals = []
      def req_keywords = @kind == :data ? @members : []
      def opt_keywords = []
      def rest_keywords = nil
      def no_keywords = @kind == :struct

      def define0(genv)
        mod = genv.resolve_cpath(@static_cpath)
        # add_module_def internally calls get_const(name).add_def(self)
        cdef = mod.add_module_def(genv, self)
        @members.each do |member|
          ive = genv.resolve_ivar(@static_cpath, false, member)
          ive.add_def(self)
        end
        @block_body.define(genv) if @block_body
        cdef
      end

      def define_copy(genv)
        mod = genv.resolve_cpath(@static_cpath)
        mod.add_module_def(genv, self)
        mod.remove_module_def(genv, @prev_node)
        @members.each do |member|
          ive = genv.resolve_ivar(@static_cpath, false, member)
          ive.add_def(self)
          ive.remove_def(@prev_node)
        end
        super(genv)
      end

      def undefine0(genv)
        mod = genv.resolve_cpath(@static_cpath)
        mod.remove_module_def(genv, self)
        @members.each do |member|
          ive = genv.resolve_ivar(@static_cpath, false, member)
          ive.remove_def(self)
        end
        @block_body.undefine(genv) if @block_body
      end

      def install0(genv)
        # Register the class singleton type as the constant value
        mod_val = Source.new(Type::Singleton.new(genv, genv.resolve_cpath(@static_cpath)))
        if @static_cpath
          @changes.add_edge(genv, mod_val, @static_ret.vtx)
        end

        cpath = @static_cpath
        @members.each do |member|
          # Use bare `:member` (not `:@member`) so the slot can't collide with a
          # user-written @member ivar — Struct/Data fields are not real ivars.
          ivar_box = @changes.add_ivar_read_box(genv, cpath, false, member)
          ret_box = @changes.add_escape_box(genv, ivar_box.ret)
          @changes.add_method_def_box(genv, cpath, false, member, FormalArguments::Empty, [ret_box])

          if @kind == :struct
            # attr_writer (Struct only, Data is frozen)
            ive = genv.resolve_ivar(cpath, false, member)
            vtx = Vertex.new(self)
            @changes.add_edge(genv, vtx, ive.vtx)
            writer_ret = @changes.add_escape_box(genv, vtx)
            f_args = FormalArguments.new([vtx], [], nil, [], [], [], nil, nil)
            @changes.add_method_def_box(genv, cpath, false, :"#{ member }=", f_args, [writer_ret])
          end
        end

        # initialize
        init_vtxs = @members.map do |member|
          ive = genv.resolve_ivar(cpath, false, member)
          vtx = Vertex.new(self)
          @changes.add_edge(genv, vtx, ive.vtx)
          vtx
        end
        init_ret = @changes.add_escape_box(genv, Source.new(genv.nil_type))
        if @kind == :struct
          init_f_args = FormalArguments.new(init_vtxs, [], nil, [], [], [], nil, nil)
        else
          # Data.define uses keyword arguments
          init_f_args = FormalArguments.new([], [], nil, [], init_vtxs, [], nil, nil)
        end
        @changes.add_method_def_box(genv, cpath, false, :initialize, init_f_args, [init_ret])

        # Struct.[] is an alias for Struct.new
        if @kind == :struct
          self_ret = @changes.add_escape_box(genv, Source.new(Type::Instance.new(genv, genv.resolve_cpath(cpath), [])))
          @changes.add_method_def_box(genv, cpath, true, :[], init_f_args, [self_ret])
        end

        # Install block body (additional method definitions)
        if @block_body
          @block_body.lenv.locals[:"*self"] = @block_body.lenv.cref.get_self(genv)
          @block_body.install(genv)
        end

        mod_val
      end
    end
  end
end
