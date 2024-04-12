module TypeProf::Core
  class MethodEntity
    def initialize
      @builtin = nil
      @decls = Set[]
      @defs = Set[]
      @aliases = {}
      @callsites = Set[]
    end

    attr_reader :decls, :defs, :aliases, :callsites
    attr_accessor :builtin

    def add_decl(decl)
      @decls << decl
    end

    def remove_decl(decl)
      @decls.delete(decl) || raise
    end

    def add_def(mdef)
      @defs << mdef
      self
    end

    def remove_def(mdef)
      @defs.delete(mdef) || raise
    end

    def add_alias(node, old_mid)
      @aliases[node] = old_mid
    end

    def remove_alias(node)
      @aliases.delete(node) || raise
    end

    def exist?
      @builtin || !@decls.empty? || !@defs.empty? || !@aliases.empty?
    end

    def add_run_all_mdefs(genv)
      @defs.each do |mdef|
        genv.add_run(mdef)
      end
    end

    def add_run_all_callsites(genv)
      @callsites.each do |callsite|
        genv.add_run(callsite)
      end
    end
  end
end
