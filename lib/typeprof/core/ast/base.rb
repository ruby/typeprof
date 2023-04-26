module TypeProf::Core
  class AST
    class Node
      def initialize(raw_node, lenv)
        @raw_node = raw_node
        @lenv = lenv
        @prev_node = nil
        @static_ret = nil
        @ret = nil
        @sites = {}
        @diagnostics = []
        @reused = false
      end

      attr_reader :lenv, :prev_node, :static_ret, :ret, :sites

      def subnodes = {}
      def attrs = {}
      def code_ranges = {}

      def each_subnode
        subnodes.each_value do |subnode|
          next unless subnode
          case subnode
          when AST::Node
            yield subnode
          when Array
            subnode.each {|n| yield n if n }
          else
            raise subnode.class.to_s
          end
        end
      end

      def traverse(&blk)
        yield :enter, self
        each_subnode do |subnode|
          subnode.traverse(&blk)
        end
        yield :leave, self
      end

      def traverse_children(&blk)
        return unless yield self
        each_subnode do |subnode|
          subnode.traverse_children(&blk)
        end
      end

      def code_range
        if @raw_node
          TypeProf::CodeRange.from_node(@raw_node)
        else
          pp self
          raise
        end
      end

      def add_site(key, site)
        (@sites[key] ||= Set[]) << site
      end

      def remove_site(key, site)
        @sites[key].delete(site) || raise
      end

      def define(genv)
        debug = ENV["TYPEPROF_DEBUG"]
        if debug
          puts "define enter: #{ self.class }@#{ code_range.inspect }"
        end
        @static_ret = define0(genv)
        if debug
          puts "define leave: #{ self.class }@#{ code_range.inspect }"
        end
        @static_ret
      end

      def define0(genv)
        each_subnode do |subnode|
          subnode.define(genv)
        end
        return nil
      end

      def undefine(genv)
        debug = ENV["TYPEPROF_DEBUG"]
        if debug
          puts "undefine enter: #{ self.class }@#{ code_range.inspect }"
        end
        undefine0(genv)
        if debug
          puts "undefine leave: #{ self.class }@#{ code_range.inspect }"
        end
      end

      def undefine0(genv)
        unless @reused
          each_subnode do |subnode|
            subnode.undefine(genv)
          end
        end
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
          @sites.each_value do |sites|
            sites.each do |site|
              site.destroy(genv)
            end
          end
          uninstall0(genv)
        end
        if debug
          puts "uninstall leave: #{ self.class }@#{ code_range.inspect }"
        end
      end

      def uninstall0(genv)
        each_subnode do |subnode|
          subnode.uninstall(genv)
        end
      end

      def diff(prev_node)
        if prev_node.is_a?(self.class) && attrs.all? {|key, attr| attr == prev_node.send(key) }
          s1 = subnodes
          s2 = prev_node.subnodes
          return if s1.keys != s2.keys
          s1.each do |key, subnode|
            next if key == :dummy_rhs
            prev_subnode = s2[key]
            if subnode && prev_subnode
              if subnode.is_a?(AST::Node)
                subnode = [subnode]
                prev_subnode = [prev_subnode]
              end
              subnode.zip(prev_subnode) do |subnode0, prev_subnode0|
                subnode0.diff(prev_subnode0)
                return unless subnode0.prev_node
              end
            else
              return if subnode != prev_subnode
            end
          end
          @prev_node = prev_node
        end
      end

      def copy_code_ranges
        @prev_node.instance_variable_set(:@raw_node, @raw_node)
        code_ranges.each do |key, cr|
          @prev_node.instance_variable_set("@#{ key }".to_sym, cr)
        end
        each_subnode do |subnode|
          subnode.copy_code_ranges
        end
      end

      def retrieve_at(pos, &blk)
        if code_range.include?(pos)
          each_subnode do |subnode|
            subnode.retrieve_at(pos, &blk)
          end
          yield self
        end
      end

      def hover(pos, &blk)
        if code_range.include?(pos)
          each_subnode do |subnode|
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

      def add_diagnostic(msg)
        @diagnostics << TypeProf::Diagnostic.new(self, :code_range, msg)
      end

      def diagnostics(genv, &blk)
        @diagnostics.each(&blk)
        @sites.each_value do |sites|
          sites.each do |site|
            site.diagnostics(genv, &blk)
          end
        end
        each_subnode do |subnode|
          subnode.diagnostics(genv, &blk)
        end
      end

      def get_vertexes(vtxs)
        return if @reused
        @sites.each_value do |sites|
          sites.each do |site|
            vtxs << site.ret
          end
        end
        vtxs << @ret
        each_subnode do |subnode|
          subnode.get_vertexes(vtxs)
        end
      end

      def modified_vars(tbl, vars)
        each_subnode do |subnode|
          subnode.modified_vars(tbl, vars)
        end
      end

      def pretty_print_instance_variables
        super - [:@raw_node, :@lenv, :@prev_node, :@static_ret]
      end
    end

    class ProgramNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)

        @tbl, args, raw_body = raw_node.children
        raise unless args == nil

        @body = AST.create_node(raw_body, lenv)
      end

      attr_reader :tbl, :body

      def subnodes = { body: }
      def attrs = { tbl: }

      def install0(genv)
        @tbl.each {|var| @lenv.locals[var] = Source.new(genv.nil_type) }
        @lenv.locals[:"*self"] = Source.new(lenv.cref.get_self(genv))
        @lenv.locals[:"*ret"] = Source.new() # dummy sink for toplevel return value

        @body.install(genv)
      end

      def dump(dumper)
        @body.dump(dumper)
      end
    end

    class NilNode < Node
      def initialize(code_range, lenv)
        @code_range = code_range
        super(nil, lenv)
      end

      def code_range
        @code_range
      end

      def install0(genv)
        Source.new(genv.nil_type)
      end

      def dump(dumper)
        ""
      end
    end

    class DummyRHSNode < Node
      def initialize(code_range, lenv, vtx)
        @code_range = code_range
        super(nil, lenv)
        @vtx = vtx
      end

      def code_range
        @code_range
      end

      def install0(_)
        @vtx
      end

      def dump(dumper)
        "<DummyRHSNode>"
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
end