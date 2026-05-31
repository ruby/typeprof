module TypeProf
  module Dsl
    class Scope
      def initialize(genv, changes, node, ty, a_args)
        @genv    = genv
        @changes = changes
        @node    = node
        @ty      = ty
        @a_args  = a_args
      end

      attr_reader :changes, :node

      def mid
        @node.mid
      end

      def owner
        @owner ||= build_owner
      end

      def arg_symbol(idx)
        vtx = @a_args.positionals[idx]
        return nil unless vtx
        result = nil
        vtx.each_type do |ty|
          return nil unless ty.is_a?(TypeProf::Core::Type::Symbol)
          return nil if result && result != ty.sym
          result = ty.sym
        end
        result
      end

      def has_block?
        !@node.block_body.nil?
      end

      private

      # Only the Singleton receiver (class body, `C.define_method(...)`) is supported.
      # Other receivers get a nil cpath, making ScopeOwner's mutating methods a no-op.
      def build_owner
        case @ty
        when TypeProf::Core::Type::Singleton
          ScopeOwner.new(@genv, @changes, @node, @ty.mod.cpath, false)
        else
          ScopeOwner.new(@genv, @changes, @node, nil, false)
        end
      end
    end

    class ScopeOwner
      def initialize(genv, changes, node, cpath, singleton)
        @genv      = genv
        @changes   = changes
        @node      = node
        @cpath     = cpath
        @singleton = singleton
      end

      attr_reader :cpath

      def define_method_from_block(mid)
        return unless @cpath
        return unless @node.block_body

        call_node = @node

        # Block params are already registered as Vertices on block_body.lenv
        # by CallNode#install0; pick them up as the new method's positional params.
        blk_f_args = (call_node.block_f_args || []).map do |name|
          call_node.block_body.lenv.get_var(name)
        end

        f_args = TypeProf::Core::FormalArguments.new(
          blk_f_args,
          [],
          nil,
          [],
          [],
          [],
          nil,
          nil,
        )

        ret_box = @changes.add_escape_box(@genv, call_node.block_body.ret)

        @changes.add_method_def_box(
          @genv,
          @cpath,
          @singleton,
          mid,
          f_args,
          [ret_box],
        )
      end
    end
  end
end
