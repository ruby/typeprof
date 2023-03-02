module TypeProf
  class Type
    include StructuralEquality

    class Untyped < Type
      def inspect
        "<untyped>"
      end
    end

    class Module < Type
      def initialize(cpath)
        # TODO: type_param
        @cpath = cpath
      end

      attr_reader :cpath

      def show
        "singleton(#{ @cpath.join("::" ) })"
      end
    end

    class Class < Module
      def initialize(cpath)
        # TODO: type_param
        @cpath = cpath
      end

      attr_reader :kind, :cpath

      def get_instance_type
        raise "cannot instantiate a module" if @kind == :module
        Instance.new(@cpath)
      end
    end

    class Instance < Type
      def initialize(cpath)
        raise unless cpath.is_a?(Array)
        @cpath = cpath
      end

      attr_reader :cpath

      def get_class_type
        Class.new(:class, @cpath)
      end

      def show
        "#{ @cpath.join("::" )}"
      end
    end

    class RBS < Type
      def initialize(rbs_type)
        @rbs_type = rbs_type
      end

      def inspect
        "#<Type::RBS ...>"
      end
    end
  end

  class Vertex
    def initialize(show_name)
      @show_name = show_name
      @types = {}
      @followers = Set.new
      @decls = Set.new
    end

    attr_reader :show_name, :followers, :types

    def on_type_added(genv, src_var, added_types)
      new_added_types = []
      added_types.each do |ty|
        unless @types[ty]
          @types[ty] ||= Set.new
          new_added_types << ty
        end
        @types[ty] << src_var
      end
      unless new_added_types.empty?
        @followers.each do |follower|
          follower.on_type_added(genv, self, new_added_types)
        end
      end
    end

    def on_type_removed(genv, src_var, removed_types)
      new_removed_types = []
      removed_types.each do |ty|
        @types[ty].delete(src_var)
        if @types[ty].empty?
          @types.delete(ty)
          new_removed_types << ty
        end
      end
      unless new_removed_types.empty?
        @followers.each do |follower|
          follower.on_type_removed(genv, self, new_removed_types)
        end
      end
    end

    def add_follower(genv, follower)
      @followers << follower
      follower.on_type_added(genv, self, @types.keys) unless @types.empty?
    end

    def remove_follower(genv, follower)
      @followers.delete(follower)
      follower.on_type_removed(genv, self, @types.keys) unless @types.empty?
    end

    def show
      @types.empty? ? "untyped" : @types.keys.map {|ty| ty.show }.join(" | ")
    end
  end

  class Source
    def initialize(ty)
      @types = { ty => nil }
    end

    attr_reader :types

    def add_follower(genv, follower)
      follower.on_type_added(genv, self, @types.keys)
    end

    def remove_follower(genv, follower)
      follower.on_type_removed(genv, self, @types.keys)
    end

    def show
      @types.empty? ? "untyped" : @types.keys.map {|ty| ty.show }.join(" | ")
    end
  end

  class MethodDecl
    def initialize(cpath, singleton, mid, rbs_member)
      @cpath = cpath
      @singleton = singleton
      @mid = mid
      @rbs_member = rbs_member
      @builtin = nil
    end

    attr_reader :cpath, :singleton, :mid, :rbs_member, :builtin

    def resolve_overloads(genv, a_arg) # TODO: only one argument is supported!
      if @builtin
        return @builtin[genv, a_arg]
      end
      ret_types = []
      @rbs_member.overloads.each do |overload|
        func = overload.method_type.type
        # func.optional_keywords
        # func.optional_positionals
        # func.required_keywords
        # func.rest_keywords
        # func.rest_positionals
        # func.trailing_positionals
        # TODO: only one argument!
        f_arg = func.required_positionals.first
        f_arg = Signatures.type(genv, f_arg.type)
        if a_arg.types.key?(f_arg) # TODO: type consistency
          ret_types << Signatures.type(genv, func.return_type)
        end
      end
      ret_types
    end

    def set_builtin(&blk)
      @builtin = blk
    end

    def inspect
      "#<MethodDecl ...>"
    end
  end

  class MethodDef
    def initialize(cpath, singleton, mid, node, arg, ret)
      @cpath = cpath
      @singleton = singleton
      @mid = mid
      @node = node
      @arg = arg
      @ret = ret
    end

    attr_reader :cpath, :singleton, :mid, :node, :arg, :ret

    def show
      "(#{ arg.show }) -> #{ ret.show }"
    end
  end

  class CallSite
    def initialize(genv, node, recv, mid, args)
      raise mid.to_s unless mid
      @node = node
      @recv = recv
      @mid = mid
      @args = args
      @ret = Vertex.new("ret:#{ mid }")
      @error = false
      @followings = {}
      recv.add_follower(genv, self)
      args.add_follower(genv, self)
    end

    attr_reader :node, :recv, :mid, :args, :ret

    def on_type_added(genv, src_tyvar, added_types)
      genv.add_run(self)
    end

    def on_type_removed(genv, src_tyvar, removed_types)
      genv.add_run(self)
    end

    def run(genv)
      destroy(genv)

      resolve(genv).each do |ty, mds|
        mds.each do |md|
          case md
          when MethodDecl
            if md.builtin
              @followings[md] = md.builtin[ty, @mid, @args, @ret]
            else
              ret_types = md.resolve_overloads(genv, @args)
              # TODO: handle Type::Union
              @followings[md] = ret_types.map {|ty| [Source.new(ty), @ret] }
            end
          when MethodDef
            @followings[md] = [[@args, md.arg], [md.ret, @ret]]
          end
        end
      end

      @followings.each do |mdef, rel|
        rel.each do |src_tyvar, dest_tyvar|
          src_tyvar.add_follower(genv, dest_tyvar)
        end
      end
    end

    def destroy(genv)
      @followings.each do |mdef, rel|
        rel.each do |src_tyvar, dest_tyvar|
          src_tyvar.remove_follower(genv, dest_tyvar)
        end
      end
      @followings.clear
    end

    def resolve(genv)
      ret = []
      @recv.types.each do |ty, source|
        # TODO: resolve ty#mid
        # assume ty is a Type::Instnace or Type::Class
        mds = genv.resolve_method(ty.cpath, ty.is_a?(Type::Class), @mid)
        ret << [ty, mds] if mds
      end
      ret
    end
  end

  class ReadSite
    def initialize(node, cref, cname)
      @node = node
      @cref = cref
      @cname = cname
      @ret = Vertex.new("cname:#{ cname }")
      @followings = {}
    end

    attr_reader :node, :cref, :cname, :ret

    def run(genv)
      destroy(genv)

      cref = @cref
      while cref
        e = genv.get_const(cref.cpath, @cname)
        break if e && !e.defs.empty? # TODO: decls
        cref = cref.outer
      end
      @followings = [[e.val, @ret]]

      @followings.each do |src_tyvar, dest_tyvar|
        src_tyvar.add_follower(genv, dest_tyvar)
      end
    end

    def destroy(genv)
      @followings.each do |src_tyvar, dest_tyvar|
        src_tyvar.remove_follower(genv, dest_tyvar)
      end
      @followings.clear
    end
  end
end
