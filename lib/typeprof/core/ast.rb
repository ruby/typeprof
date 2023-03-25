module TypeProf::Core
  class AST
    def self.parse(src)
      begin
        verbose_back, $VERBOSE = $VERBOSE, nil
        raw_scope = RubyVM::AbstractSyntaxTree.parse(src, keep_tokens: true)
      rescue
        $VERBOSE = verbose_back
      end

      raise unless raw_scope.type == :SCOPE
      tbl, args, raw_body = raw_scope.children
      raise unless args == nil

      cref = CRef.new([], false, nil)
      locals = {}
      tbl.each {|var| locals[var] = Source.new(Type.nil) }
      lenv = LexicalScope.new(nil, cref, locals, nil)
      Fiber[:tokens] = raw_scope.all_tokens.map do |_idx, type, str, cr|
        row1, col1, row2, col2 = cr
        pos1 = TypeProf::CodePosition.new(row1, col1)
        pos2 = TypeProf::CodePosition.new(row2, col2)
        code_range = TypeProf::CodeRange.new(pos1, pos2)
        [type, str, code_range]
      end.compact.sort_by {|_type, _str, code_range| code_range.first }
      AST.create_node(raw_body, lenv)
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
      when :CONST then CONST.new(raw_node, lenv)
      when :COLON2 then COLON2.new(raw_node, lenv)
      when :COLON3 then COLON3.new(raw_node, lenv)
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

    def self.create_call_node(raw_node, raw_call, raw_block, lenv)
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

    class Node
      def initialize(raw_node, lenv)
        @raw_node = raw_node
        @lenv = lenv
        @raw_children = raw_node.children
        @prev_node = nil
        @ret = nil
        @defs = nil
        @sites = nil
      end

      attr_reader :lenv, :prev_node, :ret

      def subnodes = {}
      def attrs = {}

      def traverse(&blk)
        yield :enter, self
        subnodes.each_value do |subnode|
          subnode.traverse(&blk) if subnode
        end
        yield :leave, self
      end

      def code_range
        if @raw_node
          TypeProf::CodeRange.from_node(@raw_node)
        else
          pp self
          nil
        end
      end

      def defs
        @defs ||= Set[]
      end

      def add_def(genv, d)
        defs << d
        case d
        when MethodDef
          genv.add_method_def(d)
        when ConstDef
          genv.add_const_def(d)
        when GVarDef
          genv.add_gvar_def(d)
        when IVarDef
          genv.add_ivar_def(d)
        end
      end

      def sites
        @sites ||= {}
      end

      def add_site(key, site)
        sites[key] = site
      end

      def install(genv)
        debug = ENV["TYPEPROF_DEBUG"]
        if debug
          puts "install enter: #{ self.class }@#{ code_range.inspect }"
        end
        @ret = install0(genv)
        if debug
          puts "install leave: #{ self.class }@#{ code_range.inspect }"
        end
        @ret
      end

      def install0(_)
        raise "should override"
      end

      def uninstall(genv)
        debug = ENV["TYPEPROF_DEBUG"]
        if debug
          puts "uninstall enter: #{ self.class }@#{ code_range.inspect }"
        end
        unless @reused
          defs = @defs # annoation
          if defs
            defs.each do |d|
              case d
              when MethodDef
                genv.remove_method_def(d)
              when ConstDef
                genv.remove_const_def(d)
              when GVarDef
                genv.remove_gvar_def(d)
              when IVarDef
                genv.remove_ivar_def(d)
              end
            end
          end
          sites = @sites # annotation
          if sites
            sites.each_value do |site|
              site.destroy(genv)
            end
          end
        end
        uninstall0(genv)
        if debug
          puts "uninstall leave: #{ self.class }@#{ code_range.inspect }"
        end
      end

      def uninstall0(genv)
        subnodes.each_value do |subnode|
          subnode.uninstall(genv) if subnode
        end
      end

      def diff(prev_node)
        if prev_node.is_a?(self.class) && attrs.all? {|key, attr| attr == prev_node.send(key) }
          subnodes.each do |key, subnode|
            prev_subnode = prev_node.send(key)
            if subnode && prev_subnode
              subnode.diff(prev_subnode)
              return unless subnode.prev_node
            else
              return if subnode != prev_subnode
            end
          end
          @prev_node = prev_node
        end
      end

      def reuse
        prev_node = @prev_node # annotation
        if prev_node
          @lenv = prev_node.lenv
          @ret = prev_node.ret
          @defs = prev_node.defs
          @sites = prev_node.sites
        end

        subnodes.each_value do |subnode|
          subnode.reuse if subnode
        end
      end

      def hover(pos, &blk)
        if code_range.include?(pos)
          subnodes.each_value do |subnode|
            next unless subnode
            subnode.hover(pos, &blk)
          end
          yield self
        end
        return nil
      end

      def dump(dumper)
        s = dump0(dumper)
        sites = @sites # annotation
        if sites
          if !sites.empty? # want to avoid this nesting
            s += "\e[32m:#{ @sites.to_a.join(",") }\e[m"
          end
        end
        s += "\e[34m:#{ @ret.inspect }\e[m"
        s
      end

      def dump0(dumper)
        raise "should override"
      end

      def diagnostics(genv, &blk)
        sites = @sites # annotation
        if sites
          sites.each_value do |site|
            next unless site.respond_to?(:diagnostics) # XXX
            site.diagnostics(genv, &blk)
          end
        end
        subnodes.each_value do |subnode|
          subnode.diagnostics(genv, &blk) if subnode
        end
      end

      def get_vertexes_and_boxes(vtxs, boxes)
        sites = @sites # annotation
        if sites
          sites.each_value do |site|
            vtxs << site.ret
            boxes << site
          end
        end
        vtxs << @ret
        subnodes.each_value do |subnode|
          subnode.get_vertexes_and_boxes(vtxs, boxes) if subnode
        end
      end

      def modified_vars(tbl, vars)
        case self
        when LASGN
          vars << self.var if tbl.include?(self.var)
        when ModuleNode, DefNode
          # skip
        when CallNode
          subnodes.each do |key, subnode|
            if key == :block_body
              subnode.modified_vars(tbl - self.block_tbl, vars) if subnode
            else
              subnode.modified_vars(tbl, vars) if subnode
            end
          end
        else
          subnodes.each_value do |subnode|
            subnode.modified_vars(tbl, vars) if subnode
          end
        end
      end

      def pretty_print_instance_variables
        super - [:@raw_node, :@raw_children, :@lenv, :@prev_node]
      end
    end

    class DummySymbolNode
      def initialize(sym, code_range, ret)
        @sym = sym
        @code_range = code_range
        @ret = ret
      end

      attr_reader :lenv, :prev_node, :ret

      def sites
        {}
      end
    end
  end

  class LexicalScope
    def initialize(node, cref, locals, outer)
      @cref = cref
      @locals = locals
      @outer = outer
      # XXX
      @self = Source.new(@cref.get_self)
      @ret = node ? Vertex.new("ret", node) : nil
    end

    attr_reader :cref, :locals, :outer

    def set_var(name, node)
      @locals[name] = Vertex.new("var:#{ name }", node)
    end

    def update_var(name, vtx)
      @locals[name] = vtx
    end

    def def_alias_var(name, old_name, node)
      @locals[name] = @locals[old_name]
    end

    def get_var(name)
      @locals[name] || raise
    end

    def get_self
      @self
    end

    def get_ret
      @ret
    end
  end

  class CRef
    def initialize(cpath, singleton, outer)
      @cpath = cpath
      @singleton = singleton
      @outer = outer
    end

    attr_reader :cpath, :singleton, :outer

    def extend(cpath, singleton)
      CRef.new(cpath, singleton, self)
    end

    def get_self
      (@singleton ? Type::Module : Type::Instance).new(@cpath || [:Object])
    end
  end
end