module TypeProf::Core
  class AST
    class Node
      def initialize(raw_node, lenv)
        @raw_node = raw_node
        @lenv = lenv
        @prev_node = nil
        @static_ret = nil
        @ret = nil

        @changes = ChangeSet.new(self, nil)
      end

      attr_reader :lenv
      attr_reader :prev_node
      attr_reader :static_ret
      attr_reader :ret
      attr_reader :changes

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
            subnode.each do |n|
              if n
                if n.is_a?(Array)
                  n.each {|n| yield n }
                else
                  yield n
                end
              end
            end
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

      def code_range
        if @raw_node
          TypeProf::CodeRange.from_node(@raw_node)
        else
          pp self
          raise
        end
      end

      def define(genv)
        @static_ret = define0(genv)
      end

      def define_copy(genv)
        @lenv = @prev_node.lenv
        each_subnode do |subnode|
          subnode.define_copy(genv)
        end
        @prev_node.instance_variable_set(:@reused, true)
        @static_ret = @prev_node.static_ret
      end

      def define0(genv)
        each_subnode do |subnode|
          subnode.define(genv)
        end
        return nil
      end

      def undefine(genv)
        unless @reused
          undefine0(genv)
        end
      end

      def undefine0(genv)
        each_subnode do |subnode|
          subnode.undefine(genv)
        end
      end

      def install(genv)
        @ret = install0(genv)
        @changes.reinstall(genv)
        @ret
      end

      def install_copy(genv)
        @changes.copy_from(@prev_node.changes)
        @changes.reuse(self)
        each_subnode do |subnode|
          subnode.install_copy(genv)
        end
        @ret = @prev_node.ret
      end

      def install0(_)
        raise "should override"
      end

      def uninstall(genv)
        @changes.reinstall(genv)
        each_subnode do |subnode|
          subnode.uninstall(genv)
        end
      end

      def diff(prev_node)
        if prev_node.is_a?(self.class) && attrs.all? {|key, attr| attr == prev_node.send(key) }
          raise unless prev_node # annotation
          s1 = subnodes
          s2 = prev_node.subnodes
          return if s1.keys != s2.keys
          s1.each do |key, subnode|
            prev_subnode = s2[key]
            if subnode && prev_subnode
              subnode = [subnode] if subnode.is_a?(AST::Node)
              prev_subnode = [prev_subnode] if prev_subnode.is_a?(AST::Node)
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

      def boxes(key)
        boxes = []
        @changes.boxes.each do |(k, *), box|
          # TODO: make it recursive
          box.changes.boxes.each do |(k, *), box|
            boxes << box if k == key
          end
          boxes << box if k == key
        end
        boxes
      end

      def diagnostics(genv, &blk)
        @changes.diagnostics.each(&blk)
        @changes.boxes.each_value do |box|
          box.diagnostics(genv, &blk)
        end
        each_subnode do |subnode|
          subnode.diagnostics(genv, &blk)
        end
      end

      def get_vertexes(vtxs)
        return if @reused
        @changes.boxes.each_value do |box|
          vtxs << box.ret
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
        super() - [:@raw_node, :@lenv, :@prev_node, :@static_ret, :@changes]
      end
    end

    class ProgramNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)

        @tbl = raw_node.locals
        raw_body = raw_node.statements

        @body = AST.create_node(raw_body, lenv)
      end

      attr_reader :tbl, :body

      def subnodes = { body: }
      def attrs = { tbl: }

      def install0(genv)
        @tbl.each {|var| @lenv.locals[var] = Source.new(genv.nil_type) }
        @lenv.locals[:"*self"] = Source.new(lenv.cref.get_self(genv))

        @body.install(genv)
      end
    end

    class DummyNilNode < Node
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
    end

    class DummyRHSNode < Node
      def initialize(code_range, lenv)
        @code_range = code_range
        super(nil, lenv)
      end

      def code_range
        @code_range
      end

      def install0(_)
        Vertex.new("dummy_rhs", self)
      end
    end

    class DummySymbolNode
      def initialize(sym, code_range, ret)
        @sym = sym
        @code_range = code_range
        @ret = ret
      end

      attr_reader :lenv, :prev_node, :ret

      def boxes(_)
        []
      end
    end
  end
end
