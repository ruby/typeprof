module TypeProf::Core
  class ChangeSet
    def initialize(target)
      @target = target
      @covariant_types = {}
      @edges = []
      @new_edges = []
      @sites = {}
      @new_sites = {}
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

    attr_reader :sites, :diagnostics

    def new_vertex(genv, sig_type_node)
      # This is used to avoid duplicated vertex generation for the same sig node
      @covariant_types[sig_type_node] ||= Vertex.new("rbs_type", sig_type_node)
    end

    def add_edge(genv, src, dst)
      raise unless src.is_a?(BasicVertex)
      src.add_edge(genv, dst) if !@edges.include?([src, dst]) && !@new_edges.include?([src, dst])
      @new_edges << [src, dst]
    end

    # TODO: if an edge is removed during one analysis, we may need to remove sub-sites?

    def add_callsite(genv, node, recv, mid, a_args, subclasses)
      key = [:callsite, node, recv, mid, a_args, subclasses]
      return if @new_sites[key]
      @new_sites[key] = CallSite.new(node, genv, recv, mid, a_args, subclasses)
    end

    def add_check_return_site(genv, node, a_ret, f_ret)
      key = [:check_return, node, a_ret, f_ret]
      return if @new_sites[key]
      @new_sites[key] = CheckReturnSite.new(node, genv, a_ret, f_ret)
    end

    def add_masgn_site(genv, node, rhs, lhss)
      key = [:masgn, node, rhs, lhss]
      return if @new_sites[key]
      @new_sites[key] = MAsgnSite.new(node, genv, rhs, lhss)
    end

    def add_method_def_site(genv, node, cpath, singleton, mid, f_args, ret)
      key = [:mdef, node, cpath, singleton, mid, f_args, ret]
      return if @new_sites[key]
      @new_sites[key] = MethodDefSite.new(node, genv, cpath, singleton, mid, f_args, ret)
    end

    def add_method_decl_site(genv, node, cpath, singleton, mid, method_types, overloading)
      key = [:mdecl, node, cpath, singleton, mid, method_types, overloading]
      return if @new_sites[key]
      @new_sites[key] = MethodDeclSite.new(node, genv, cpath, singleton, mid, method_types, overloading)
    end

    def add_method_alias_site(genv, node, cpath, singleton, new_mid, old_mid)
      key = [:mdecl, node, cpath, singleton, new_mid, old_mid]
      return if @new_sites[key]
      @new_sites[key] = MethodAliasSite.new(node, genv, cpath, singleton, new_mid, old_mid)
    end

    def add_const_read_site(genv, node, static_ret)
      key = [:cread, node, static_ret]
      return if @new_sites[key]
      @new_sites[key] = ConstReadSite.new(node, genv, static_ret)
    end

    def add_gvar_read_site(genv, node, var)
      key = [:gvar_read, node, var]
      return if @new_sites[key]
      @new_sites[key] = GVarReadSite.new(node, genv, var)
    end

    def add_ivar_read_site(genv, node, cpath, singleton, name)
      key = [:ivar_read, node, cpath, singleton, name]
      return if @new_sites[key]
      @new_sites[key] = IVarReadSite.new(node, genv, cpath, singleton, name)
    end

    def add_type_read_site(genv, node, type)
      key = [:type_read, node, type]
      return if @new_sites[key]
      @new_sites[key] = TypeReadSite.new(node, genv, type)
    end

    def add_diagnostic(node, meth, msg)
      @new_diagnostics << TypeProf::Diagnostic.new(node, meth, msg)
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

      @sites.each do |key, site|
        site.destroy(genv)
      end
      @sites, @new_sites = @new_sites, @sites
      @new_sites.clear

      @diagnostics, @new_diagnostics = @new_diagnostics, @diagnostics
      @new_diagnostics.clear

      @depended_value_entities.each do |ve|
        ve.readsites.delete(@target) || raise
      end
      @new_depended_value_entities.uniq!
      @new_depended_value_entities.each do |ve|
        ve.readsites << @target
      end
      @depended_value_entities, @new_depended_value_entities = @new_depended_value_entities, @depended_value_entities
      @new_depended_value_entities.clear

      @depended_method_entities.each do |me|
        me.callsites.delete(@target) || raise
      end
      @new_depended_method_entities.uniq!
      @new_depended_method_entities.each do |me|
        me.callsites << @target
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

    def reuse(new_node, old_node)
      @sites.each_value do |site|
        if site.node != old_node
          pp site.node, old_node
          raise site.class.to_s
        end
        site.reuse(new_node)
      end
      @diagnostics.each do |diag|
        if diag.node != old_node
          pp diag.node, old_node
          raise diag.class.to_s
        end
        diag.reuse(new_node)
      end
    end
  end
end
