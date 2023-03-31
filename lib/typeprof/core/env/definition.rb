module TypeProf::Core
  class ModuleDirectory
    def initialize(cpath, toplevel)
      @cpath = cpath

      @module_decls = Set[]
      @module_defs = Set[]
      @include_defs = Set[]

      @child_modules = {}

      @superclass = toplevel
      @subclasses = Set[]
      @included_modules = {}

      @const_reads = Set[]
      @callsites = Set[]
      @ivar_reads = Set[]

      @consts = {}
      @methods = { true => {}, false => {} }
      @ivars = { true => {}, false => {} }
    end

    attr_reader :cpath

    attr_reader :module_decls
    attr_reader :module_defs
    attr_reader :include_defs

    attr_reader :child_modules

    attr_reader :superclass
    attr_reader :subclasses
    attr_reader :included_modules

    attr_reader :const_reads
    attr_reader :callsites
    attr_reader :ivar_reads

    attr_reader :consts
    attr_reader :methods
    attr_reader :ivars

    def exist?
      !@module_decls.empty? || !@module_defs.empty?
    end

    def get_method(singleton, mid)
      @methods[singleton][mid] ||= MethodEntity.new
    end

    def get_ivar(singleton, name)
      @ivars[singleton][name] ||= Entity.new
    end

    def on_child_modules_updated(genv) # TODO: accept what is a change
      @subclasses.each {|subclass| subclass.on_child_modules_updated(genv) }
      @const_reads.each {|const_read| genv.const_read_changed(const_read) }
    end

    def set_superclass(dir) # for RBS
      @superclass = dir
    end

    def add_included_module(origin, dir) # for RBS
      @included_modules[origin] = dir
    end

    def remove_included_module(origin)
      @included_modules.delete(origin)
    end

    def on_superclass_updated(genv)
      const = nil
      # TODO: check with RBS's superclass if any
      @module_defs.each do |mdef|
        if mdef.is_a?(AST::CLASS) && mdef.superclass_cpath
          const = mdef.superclass_cpath.static_ret
          break
        end
      end

      updated = false

      # TODO: check circular class/module mix, check inconsistent superclass
      new_superclass_cpath = const ? const.cpath : []
      new_superclass = new_superclass_cpath ? genv.resolve_cpath(new_superclass_cpath) : nil
      if @superclass != new_superclass
        @superclass.subclasses.delete(self) if @superclass
        @superclass = new_superclass
        @superclass.subclasses << self if @superclass
        updated = true
      end

      all_args = Set[]
      @include_defs.each do |idef|
        idef.args.each do |arg|
          if arg.is_a?(AST::ConstNode) && arg.static_ret
            all_args << arg
            new_mod_cpath = arg.static_ret
            new_mod_cpath = new_mod_cpath ? new_mod_cpath.cpath : nil
            new_mod = new_mod_cpath ? genv.resolve_cpath(new_mod_cpath) : nil
            old_mod = @included_modules[arg]
            if old_mod != new_mod
              old_mod.subclasses.delete(self) if old_mod
              old_mod = @included_modules[arg] = new_mod
              new_mod.subclasses << self if new_mod
              updated = true
            end
          end
        end
      end
      @included_modules.to_a.each do |arg, old_mod|
        if arg.is_a?(AST::ConstNode) && !all_args.include?(arg)
          old_mod.subclasses.delete(self) if old_mod
          @included_modules.delete(arg)
        end
      end

      on_ancestors_updated(genv) if updated
    end

    def on_ancestors_updated(genv)
      @subclasses.each {|subclass| subclass.on_ancestors_updated(genv) }
      @const_reads.each {|const_read| genv.const_read_changed(const_read) }
      @callsites.each {|callsite| genv.add_run(callsite) }
      @ivar_reads.each {|ivar_read| genv.add_run(ivar_read) }
    end

    def each_subclass_of_ivar(singleton, name, &blk)
      sub_e = @ivars[singleton][name]
      if sub_e
        yield sub_e, @cpath
      else
        @subclasses.each do |subclass|
          subclass.each_subclass_of_ivar(singleton, name, &blk)
        end
      end
    end

    def add_run_all_callsites(genv)
      traverse_subclasses do |subclass_dir|
        subclass_dir.callsites.each do |callsite|
          genv.add_run(callsite)
        end
      end
    end

    def traverse_subclasses(&blk)
      yield self
      @subclasses.each do |subclass|
        subclass.traverse_subclasses(&blk)
      end
    end

    def get_vertexes_and_boxes(vtxs)
      @child_modules.each_value do |dir|
        next if self.equal?(dir) # for Object
        dir.get_vertexes_and_boxes(vtxs)
      end
      @consts.each_value do |cdef|
        vtxs << cdef.vtx
      end
    end
  end

  class MethodEntity
    def initialize
      @builtin = nil
      @decls = Set[]
      @defs = Set[]
      @aliases = {}
    end

    attr_reader :decls, :defs, :aliases
    attr_accessor :builtin

    def add_decl(decl)
      @decls << decl
    end

    def remove_decl(decl)
      @decls.delete(decl)
    end

    def add_def(mdef)
      @defs << mdef
      self
    end

    def remove_def(mdef)
      @defs.delete(mdef)
    end

    def add_alias(node, old_mid)
      @aliases[node] = old_mid
    end

    def remove_alias(mid)
      @aliases.delete(mid)
    end

    def exist?
      @builtin || !@decls.empty? || !@defs.empty? || !@aliases.empty?
    end
  end

  class MethodDecl
    def initialize(rbs_member)
      @rbs_member = rbs_member
    end

    attr_reader :rbs_member

    def resolve_overloads(changes, genv, node, param_map, a_args, block, ret)
      @rbs_member.overloads.each do |overload|
        rbs_func = overload.method_type.type
        # rbs_func.optional_keywords
        # rbs_func.optional_positionals
        # rbs_func.required_keywords
        # rbs_func.rest_keywords
        # rbs_func.rest_positionals
        # rbs_func.trailing_positionals
        param_map0 = param_map.dup
        overload.method_type.type_params.map do |param|
          param_map0[param.name] = Vertex.new("type-param:#{ param.name }", node)
        end
        f_args = rbs_func.required_positionals.map do |f_arg|
          Signatures.type_to_vtx(genv, node, f_arg.type, param_map0)
        end
        next if a_args.size != f_args.size
        next if !f_args.all? # skip interface type
        next if a_args.zip(f_args).any? {|a_arg, f_arg| !a_arg.match?(genv, f_arg) }
        rbs_blk = overload.method_type.block
        next if !!rbs_blk != !!block
        if rbs_blk && block
          rbs_blk_func = rbs_blk.type
          # rbs_blk_func.optional_keywords, ...
          block.types.each do |ty, _source|
            case ty
            when Type::Proc
              blk_a_args = rbs_blk_func.required_positionals.map do |blk_a_arg|
                Signatures.type_to_vtx(genv, node, blk_a_arg.type, param_map0)
              end
              blk_f_args = ty.block.f_args
              if blk_a_args.size == blk_f_args.size # TODO: pass arguments for block
                blk_a_args.zip(blk_f_args) do |blk_a_arg, blk_f_arg|
                  changes.add_edge(blk_a_arg, blk_f_arg)
                end
                blk_f_ret = Signatures.type_to_vtx(genv, node, rbs_blk_func.return_type, param_map0) # TODO: Sink instead of Source
                changes.add_edge(ty.block.ret, blk_f_ret)
              end
            end
          end
        end
        ret_vtx = Signatures.type_to_vtx(genv, node, rbs_func.return_type, param_map0)
        changes.add_edge(ret_vtx, ret)
      end
    end
  end

  class MethodDef
    def initialize(node, f_args, block, ret)
      @node = node
      raise unless f_args
      @f_args = f_args
      @block = block
      @ret = ret
    end

    attr_reader :node, :f_args, :block, :ret

    def call(changes, genv, call_node, a_args, block, ret)
      if a_args.size == @f_args.size
        edges = []
        if block && @block
          changes.add_edge(block, @block)
        end
        # check arity
        a_args.zip(@f_args) do |a_arg, f_arg|
          break unless f_arg
          changes.add_edge(a_arg, f_arg)
        end
        changes.add_edge(@ret, ret)
      else
        changes.add_diagnostic(
          TypeProf::Diagnostic.new(call_node, "wrong number of arguments (#{ a_args.size } for #{ @f_args.size })")
        )
      end
    end

    def show
      block_show = []
      if @block
        @block.types.each_key do |ty|
          case ty
          when Type::Proc
            block_show << "{ (#{ ty.block.f_args.map {|arg| arg.show }.join(", ") }) -> #{ ty.block.ret.show } }"
          else
            puts "???"
          end
        end
      end
      s = []
      s << "(#{ @f_args.map {|arg| Type.strip_parens(arg.show) }.join(", ") })" unless @f_args.empty?
      s << "#{ block_show.sort.join(" | ") }" unless block_show.empty?
      s << "-> #{ @ret.show }"
      s.join(" ")
    end
  end
end