module TypeProf::Core
  class ChangeSet
    def initialize(node, target)
      @node = node
      @target = target
      @covariant_types = {}
      @contravariant_types = {}
      @edges = []
      @new_edges = []
      @boxes = {}
      @new_boxes = {}
      @diagnostics = []
      @new_diagnostics = []
      @depended_value_entities = []
      @new_depended_value_entities = []
      @depended_method_entities = []
      @new_depended_method_entities = []
      @depended_static_reads = []
      @new_depended_static_reads = []
      @depended_superclasses = []
      @new_depended_superclasses = []
    end

    attr_reader :node, :covariant_types, :edges, :boxes, :diagnostics

    def reuse(new_node)
      @node = new_node
      @boxes.each_value do |box|
        box.reuse(new_node)
      end
      @diagnostics.each do |diag|
        diag.reuse(new_node)
      end
    end

    def copy_from(other)
      @covariant_types = other.covariant_types.dup
      @edges = other.edges.dup
      @boxes = other.boxes.dup
      @diagnostics = other.diagnostics.dup

      other.covariant_types.clear
      other.edges.clear
      other.boxes.clear
      other.diagnostics.clear
    end

    def new_covariant_vertex(genv, sig_type_node)
      # This is used to avoid duplicated vertex generation for the same sig node
      @covariant_types[sig_type_node] ||= Vertex.new(sig_type_node)
    end

    def new_contravariant_vertex(genv, sig_type_node)
      # This is used to avoid duplicated vertex generation for the same sig node
      @contravariant_types[sig_type_node] ||= Vertex.new(sig_type_node)
    end

    def add_edge(genv, src, dst)
      raise src.class.to_s unless src.is_a?(BasicVertex)
      src.add_edge(genv, dst) if !@edges.include?([src, dst]) && !@new_edges.include?([src, dst])
      @new_edges << [src, dst]
    end

    # TODO: if an edge is removed during one analysis, we may need to remove sub-boxes?

    def add_method_call_box(genv, recv, mid, a_args, subclasses)
      key = [:mcall, recv, mid, a_args, subclasses]
      return if @new_boxes[key]
      @new_boxes[key] = MethodCallBox.new(@node, genv, recv, mid, a_args, subclasses)
    end

    def add_escape_box(genv, a_ret, f_ret)
      key = [:return, a_ret]
      return if @new_boxes[key]
      @new_boxes[key] = EscapeBox.new(@node, genv, a_ret, f_ret)
    end

    def add_splat_box(genv, arg)
      key = [:splat, arg]
      return if @new_boxes[key]
      @new_boxes[key] = SplatBox.new(@node, genv, arg)
    end

    def add_hash_splat_box(genv, arg, unified_key, unified_val)
      key = [:hash_splat, arg, unified_key, unified_val]
      return if @new_boxes[key]
      @new_boxes[key] = HashSplatBox.new(@node, genv, arg, unified_key, unified_val)
    end

    def add_masgn_box(genv, value, lefts, rest_elem, rights)
      key = [:masgn, value, lefts, rest_elem, rights]
      return if @new_boxes[key]
      @new_boxes[key] = MAsgnBox.new(@node, genv, value, lefts, rest_elem, rights)
    end

    def add_method_def_box(genv, cpath, singleton, mid, f_args, ret_boxes)
      key = [:mdef, cpath, singleton, mid, f_args, ret_boxes]
      return if @new_boxes[key]
      @new_boxes[key] = MethodDefBox.new(@node, genv, cpath, singleton, mid, f_args, ret_boxes)
    end

    def add_method_decl_box(genv, cpath, singleton, mid, method_types, overloading)
      key = [:mdecl, cpath, singleton, mid, method_types, overloading]
      return if @new_boxes[key]
      @new_boxes[key] = MethodDeclBox.new(@node, genv, cpath, singleton, mid, method_types, overloading)
    end

    def add_method_alias_box(genv, cpath, singleton, new_mid, old_mid)
      key = [:mdecl, cpath, singleton, new_mid, old_mid]
      return if @new_boxes[key]
      @new_boxes[key] = MethodAliasBox.new(@node, genv, cpath, singleton, new_mid, old_mid)
    end

    def add_const_read_box(genv, static_ret)
      key = [:cread, static_ret]
      return if @new_boxes[key]
      @new_boxes[key] = ConstReadBox.new(@node, genv, static_ret)
    end

    def add_gvar_read_box(genv, var)
      key = [:gvar_read, var]
      return if @new_boxes[key]
      @new_boxes[key] = GVarReadBox.new(@node, genv, var)
    end

    def add_ivar_read_box(genv, cpath, singleton, name)
      key = [:ivar_read, cpath, singleton, name]
      return if @new_boxes[key]
      @new_boxes[key] = IVarReadBox.new(@node, genv, cpath, singleton, name)
    end

    def add_cvar_read_box(genv, cpath, name)
      key = [:cvar_read, cpath, name]
      return if @new_boxes[key]
      @new_boxes[key] = CVarReadBox.new(@node, genv, cpath, name)
    end

    def add_type_read_box(genv, type)
      key = [:type_read, type]
      return if @new_boxes[key]
      @new_boxes[key] = TypeReadBox.new(@node, genv, type)
    end

    def add_diagnostic(meth, msg)
      @new_diagnostics << TypeProf::Diagnostic.new(@node, meth, msg)
    end

    def add_depended_value_entity(ve)
      @new_depended_value_entities << ve
    end

    def add_depended_method_entity(me)
      @new_depended_method_entities << me
    end

    def add_depended_static_read(static_read)
      @new_depended_static_reads << static_read
    end

    def add_depended_superclass(mod)
      @new_depended_superclasses << mod
    end

    def reinstall(genv)
      @new_edges.uniq!
      @edges.each do |src, dst|
        src.remove_edge(genv, dst) unless @new_edges.include?([src, dst])
      end
      @edges, @new_edges = @new_edges, @edges
      @new_edges.clear

      @boxes.each do |key, box|
        box.destroy(genv)
      end
      @boxes, @new_boxes = @new_boxes, @boxes
      @new_boxes.clear

      @diagnostics, @new_diagnostics = @new_diagnostics, @diagnostics
      @new_diagnostics.clear

      @depended_value_entities.each do |ve|
        ve.read_boxes.delete(@target) || raise
      end
      @new_depended_value_entities.uniq!
      @new_depended_value_entities.each do |ve|
        ve.read_boxes << @target
      end
      @depended_value_entities, @new_depended_value_entities = @new_depended_value_entities, @depended_value_entities
      @new_depended_value_entities.clear

      @depended_method_entities.each do |me|
        me.method_call_boxes.delete(@target) || raise
      end
      @new_depended_method_entities.uniq!
      @new_depended_method_entities.each do |me|
        me.method_call_boxes << @target
      end
      @depended_method_entities, @new_depended_method_entities = @new_depended_method_entities, @depended_method_entities
      @new_depended_method_entities.clear

      @depended_static_reads.each do |static_read|
        static_read.followers.delete(@target)
      end
      @new_depended_static_reads.uniq!
      @new_depended_static_reads.each do |static_read|
        static_read.followers << @target
      end

      @depended_static_reads, @new_depended_static_reads = @new_depended_static_reads, @depended_static_reads
      @new_depended_static_reads.clear

      @depended_superclasses.each do |mod|
        mod.subclass_checks.delete(@target)
      end
      @new_depended_superclasses.uniq!
      @new_depended_superclasses.each do |mod|
        mod.subclass_checks << @target
      end

      @depended_superclasses, @new_depended_superclasses = @new_depended_superclasses, @depended_superclasses
      @new_depended_superclasses.clear
    end
  end
end
