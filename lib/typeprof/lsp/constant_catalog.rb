module TypeProf::LSP
  # Lightweight catalog of constants discovered in stdlib + rbs_collection RBS,
  # without loading them into the type environment. Used by completion to suggest
  # constants that need a `require` to be available, paired with the require name
  # so the editor can auto-insert the require line via additionalTextEdits.
  class ConstantCatalog
    def initialize(rbs_collection: nil)
      @entries = {}
      build_from_stdlib
      build_from_collection(rbs_collection) if rbs_collection
    end

    def each_match(parent_cpath, prefix)
      @entries.each do |cpath, require_name|
        next unless cpath.size == parent_cpath.size + 1
        next unless cpath[0...-1] == parent_cpath
        next unless cpath.last.to_s.start_with?(prefix)
        yield cpath.last, require_name
      end
    end

    def require_name_for(cpath)
      @entries[cpath]
    end

    private

    def build_from_stdlib
      stdlib_root = Pathname(RBS::Repository::DEFAULT_STDLIB_ROOT)
      return unless stdlib_root.directory?
      stdlib_root.each_child do |lib_dir|
        next unless lib_dir.directory?
        register_dir(lib_dir, resolve_require_name(lib_dir.basename.to_s))
      end
    end

    def build_from_collection(lockfile)
      loader = RBS::EnvironmentLoader.new(core_root: nil)
      loader.add_collection(lockfile)
      loader.each_signature do |source, path, _buffer, _decls, _dirs|
        next unless source.is_a?(RBS::EnvironmentLoader::Library)
        register_file(path, resolve_require_name(source.name))
      end
    end

    def resolve_require_name(gem_name)
      # 1. dirname as-is — e.g. `open-uri`
      return gem_name if Gem.find_files(gem_name).any?
      # 2. dash → slash — e.g. `net-http` → `net/http`
      slash_form = gem_name.tr("-", "/")
      return slash_form if Gem.find_files(slash_form).any?
      # 3. fallback (gem not installed in the LSP process); slash form is the
      # more common require convention so use it as a best guess.
      slash_form
    end

    def register_dir(dir, require_name)
      Pathname.glob(dir + "**/*.rbs").each do |path|
        register_file(path, require_name)
      end
    end

    def register_file(path, require_name)
      content = path.read
      buf = RBS::Buffer.new(name: path.to_s, content: content)
      _, _, decls = RBS::Parser.parse_signature(buf)
      walk_decls(decls, [], require_name)
    rescue StandardError, RBS::ParsingError
      # Skip files that fail to parse; the catalog is best-effort.
    end

    def walk_decls(decls, prefix, require_name)
      decls.each do |d|
        case d
        when RBS::AST::Declarations::Class, RBS::AST::Declarations::Module, RBS::AST::Declarations::Interface
          cpath = compute_cpath(prefix, d.name)
          @entries[cpath] ||= require_name
          walk_decls(d.members.grep(RBS::AST::Declarations::Base), cpath, require_name)
        when RBS::AST::Declarations::Constant
          cpath = compute_cpath(prefix, d.name)
          @entries[cpath] ||= require_name
        end
      end
    end

    def compute_cpath(prefix, type_name)
      ns_path = type_name.namespace.path
      if type_name.namespace.absolute?
        ns_path + [type_name.name]
      else
        prefix + ns_path + [type_name.name]
      end
    end
  end
end
