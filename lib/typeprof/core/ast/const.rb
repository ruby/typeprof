module TypeProf::Core
  class AST
    class CONST < Node
      def initialize(raw_node, lenv)
        super
        @cname, = raw_node.children
        @cdef = nil
      end

      attr_reader :cname, :cdef

      def attrs = { cname:, cdef: }

      def define0(genv)
        const = BaseConstRead.new(self, @cname, @lenv.cref)
        genv.add_const_read(const)
        const
      end

      def undefine0(genv)
        genv.remove_const_read(@static_ret)
      end

      def install0(genv)
        @cdef = @static_ret.cdef
        if @cdef
          ret = Vertex.new("const-read", self)
          @cdef.vtx.add_edge(genv, ret)
          ret
        else
          Source.new()
        end
      end

      def uninstall0(genv)
        @cdef.vtx.remove_edge(genv, @ret) if @cdef
        super
      end

      def hover(pos)
        yield self if code_range.include?(pos)
      end

      def dump0(dumper)
        "#{ @cname }"
      end
    end

    class COLON2 < Node
      def initialize(raw_node, lenv)
        super
        cbase_raw, @cname = raw_node.children
        @cbase = cbase_raw ? AST.create_node(cbase_raw, lenv) : nil
      end

      def define0(genv)
        if @cbase
          ScopedConstRead.new(self, @cname, @cbase.define(genv))
        else
          nil
        end
      end

      attr_reader :cbase, :cname

      def subnodes = { cbase: }
      def attrs = { cname: }

      def install0(genv)
        @cbase.install(genv) if @cbase
        if @static_ret
          @cdef = @static_ret.cdef
          if @cdef
            ret = Vertex.new("const-read", self)
            @cdef.vtx.add_edge(genv, ret)
            ret
          else
            Source.new()
          end
        else
          Source.new()
        end
      end

      def uninstall0(genv)
        if @cdef
          @cdef.vtx.remove_edge(genv, @ret)
        end
        super
      end

      def dump0(dumper)
        s = @cbase ? @cbase.dump(dumper) : ""
        s << "::#{ @cname }"
      end
    end

    class COLON3 < Node
      def initialize(raw_node, lenv)
        super
        @cname, = raw_node.children
      end

      def define0(genv)
        const = BaseConstRead.new(self, @cname, CRef::Toplevel)
        genv.add_const_read(const)
        const
      end

      def undefine0(genv)
        genv.remove_const_read(@static_ret)
      end

      attr_reader :cname

      def attrs = { cname: }

      def install0(genv)
        if @static_ret
          @cdef = @static_ret.cdef
          if @cdef
            ret = Vertex.new("const-read", self)
            @cdef.vtx.add_edge(genv, ret)
            ret
          else
            Source.new()
          end
        else
          Source.new()
        end
      end

      def uninstall0(genv)
        if @cdef
          @cdef.vtx.remove_edge(genv, @ret)
        end
        super
      end

      def dump0(dumper)
        "::#{ @cname }"
      end
    end

    class CDECL < Node
      def initialize(raw_node, lenv)
        super
        children = raw_node.children
        if children.size == 2
          # C = expr
          @cpath = nil
          @static_cpath = lenv.cref.cpath + [children[0]]
          raw_rhs = children[1]
        else # children.size == 3
          # expr::C = expr
          @cpath = AST.create_node(children[0], lenv)
          @static_cpath = AST.parse_cpath(children[0], lenv.cref.cpath)
          raw_rhs = children[2]
        end
        @rhs = raw_rhs ? AST.create_node(raw_rhs, lenv) : nil
      end

      attr_reader :cpath, :rhs, :static_cpath

      def subnodes = { cpath:, rhs: }
      def attrs = { static_cpath: }

      def define0(genv)
        @rhs.define(genv) if @rhs
        genv.add_const_def(@static_cpath, self)
      end

      def undefine0(genv)
        genv.remove_const_def(@static_cpath, self)
        @rhs.undefine(genv) if @rhs
      end

      def install0(genv)
        @cpath.install(genv) if @cpath
        val = @rhs.install(genv) if @rhs
        if @static_ret.vtx && val
          val.add_edge(genv, @static_ret.vtx)
        end
        val
      end

      def uninstall0(genv)
        if @static_ret.vtx && @ret
          @ret.remove_edge(genv, @static_ret.vtx)
        end
        super
      end

      def dump0(dumper)
        if @cpath
          "#{ @cpath.dump(dumper) } = #{ @rhs.dump(dumper) }"
        else
          "#{ @static_cpath[0] } = #{ @rhs.dump(dumper) }"
        end
      end
    end
  end
end