module TypeProf::Core
  class MethodEntity
    def initialize
      @builtin = nil
    end

    attr_accessor :builtin

    def decls = @decls ||= Set.empty
    def defs = @defs ||= Set.empty
    def aliases = @aliases ||= {}
    def method_call_boxes = @method_call_boxes ||= Set.empty

    private def overloading_decls = @overloading_decls ||= Set.empty

    def add_decl(decl)
      if decl.overloading
        overloading_decls << decl
      else
        decls << decl
      end
    end

    def remove_decl(decl)
      if decl.overloading
        overloading_decls.delete(decl) || raise
      else
        decls.delete(decl) || raise
      end
    end

    def add_def(mdef)
      defs << mdef
      self
    end

    def remove_def(mdef)
      defs.delete(mdef) || raise
    end

    def add_alias(node, old_mid)
      aliases[node] = old_mid
    end

    def remove_alias(node)
      aliases.delete(node) || raise
    end

    def exist?
      @builtin || (@decls && !@decls.empty?) || (@defs && !@defs.empty?)
    end

    def add_run_all_mdefs(genv)
      return unless @defs
      @defs.each do |mdef|
        genv.add_run(mdef)
      end
    end

    def add_run_all_method_call_boxes(genv)
      return unless @method_call_boxes
      @method_call_boxes.each do |box|
        genv.add_run(box)
      end
    end
  end
end
