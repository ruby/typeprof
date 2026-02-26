module TypeProf::Core
  class Builtin
    def initialize(genv)
      @genv = genv
    end

    def class_new(changes, node, ty, a_args, ret)
      type_param_vtxs = ty.mod.type_params.map { Vertex.new(node) }
      temp_instance_ty = Type::Instance.new(@genv, ty.mod, type_param_vtxs)
      recv = Source.new(temp_instance_ty)
      changes.add_method_call_box(@genv, recv, :initialize, a_args, false)
      changes.add_edge(@genv, recv, ret)
      true
    end

    def object_class(changes, node, ty, a_args, ret)
      ty = ty.base_type(@genv)
      mod = ty.is_a?(Type::Instance) ? ty.mod : @genv.mod_class
      ty = Type::Singleton.new(@genv, mod)
      vtx = Source.new(ty)
      changes.add_edge(@genv, vtx, ret)
      true
    end

    def proc_call(changes, node, ty, a_args, ret)
      case ty
      when Type::Proc
        ty.block.accept_args(@genv, changes, a_args.positionals)
        ty.block.add_ret(@genv, changes, ret)
        true
      else
        false
      end
    end

    def array_aref(changes, node, ty, a_args, ret)
      if a_args.positionals.size == 1
        case ty
        when Type::Array
          idx = node.positional_args[0]
          if idx.is_a?(AST::IntegerNode)
            idx = idx.lit
          else
            idx = nil
          end
          vtx = ty.get_elem(@genv, idx)
          changes.add_edge(@genv, vtx, ret)
          true
        else
          false
        end
      else
        false
      end
    end

    def array_aset(changes, node, ty, a_args, ret)
      if a_args.positionals.size == 2
        case ty
        when Type::Array
          val = a_args.positionals[1]
          idx = node.positional_args[0]
          if idx.is_a?(AST::IntegerNode) && ty.get_elem(@genv, idx.lit)
            changes.add_edge(@genv, val, ty.get_elem(@genv, idx.lit))
          else
            changes.add_edge(@genv, val, ty.get_elem(@genv))
          end
          true
        else
          false
        end
      else
        false
      end
    end

    def array_push(changes, node, ty, a_args, ret)
      if a_args.positionals.size == 1
        if ty.is_a?(Type::Array)
          val = a_args.positionals[0]
          changes.add_edge(@genv, val, ty.get_elem(@genv))
        end
        recv = Source.new(ty)
        changes.add_edge(@genv, recv, ret)
      else
        false
      end
    end

    def hash_aref(changes, node, ty, a_args, ret)
      if a_args.positionals.size == 1
        case ty
        when Type::Hash
          idx = node.positional_args[0]
          idx = idx.is_a?(AST::SymbolNode) ? idx.lit : nil
          value = ty.get_value(idx)
          if value
            changes.add_edge(@genv, value, ret)
          else
            # Return untyped for unknown fields
            changes.add_edge(@genv, Source.new(), ret)
          end
          true
        when Type::Record
          idx = node.positional_args[0]
          idx = idx.is_a?(AST::SymbolNode) ? idx.lit : nil
          value = ty.get_value(idx)
          if value
            changes.add_edge(@genv, value, ret)
          else
            changes.add_edge(@genv, Source.new(@genv.nil_type), ret)
          end
          # Symbol variable access - add nil possibility
          if idx.nil?
            changes.add_edge(@genv, Source.new(@genv.nil_type), ret)
          end
          true
        else
          false
        end
      else
        false
      end
    end

    def hash_aset(changes, node, ty, a_args, ret)
      if a_args.positionals.size == 2
        case ty
        when Type::Hash
          val = a_args.positionals[1]
          idx = node.positional_args[0]
          if idx.is_a?(AST::SymbolNode) && ty.get_value(idx.lit)
            # TODO: how to handle new key?
            changes.add_edge(@genv, val, ty.get_value(idx.lit))
          else
            # TODO: literal_pairs will not be updated
            changes.add_edge(@genv, a_args.positionals[0], ty.get_key)
            changes.add_edge(@genv, val, ty.get_value)
          end
          changes.add_edge(@genv, val, ret)
          true
        when Type::Record
          val = a_args.positionals[1]
          idx = node.positional_args[0]
          if idx.is_a?(AST::SymbolNode)
            field_vtx = ty.get_value(idx.lit)
            changes.add_edge(@genv, val, field_vtx) if field_vtx
          end
          changes.add_edge(@genv, val, ret)
          true
        else
          false
        end
      else
        false
      end
    end

    def object_method(changes, node, ty, a_args, ret)
      if a_args.positionals.size == 1
        sym_node = node.positional_args[0]
        if sym_node.is_a?(AST::SymbolNode)
          method_ty = Type::Method.new(@genv, ty, sym_node.lit)
          changes.add_edge(@genv, Source.new(method_ty), ret)
          return true
        end
      end
      false
    end

    def method_call(changes, node, ty, a_args, ret)
      case ty
      when Type::Method
        recv = Source.new(ty.recv_ty)
        box = changes.add_method_call_box(@genv, recv, ty.mid, a_args, false)
        changes.add_edge(@genv, box.ret, ret)
        true
      else
        false
      end
    end

    def kernel_send(changes, node, ty, a_args, ret)
      return false if a_args.positionals.empty?

      if a_args.splat_flags[0]
        # send(*array) case: extract method name and args from array elements
        splat_vtx = a_args.positionals[0]
        changes.add_edge(@genv, splat_vtx, changes.target)

        rest_positionals = a_args.positionals[1..]
        rest_splat_flags = a_args.splat_flags[1..]

        splat_vtx.each_type do |ary_ty|
          next unless ary_ty.is_a?(Type::Array)

          if ary_ty.elems && ary_ty.elems.size >= 1
            # Tuple: use per-element precision
            method_name_vtx = ary_ty.elems[0]
            changes.add_edge(@genv, method_name_vtx, changes.target)

            elem_args = ary_ty.elems[1..] + rest_positionals
            elem_flags = ::Array.new(ary_ty.elems.size - 1, false) + rest_splat_flags
            send_a_args = ActualArguments.new(elem_args, elem_flags, a_args.keywords, a_args.block)

            method_name_vtx.each_type do |sym_ty|
              if sym_ty.is_a?(Type::Symbol)
                recv = Source.new(ty)
                box = changes.add_method_call_box(@genv, recv, sym_ty.sym, send_a_args, false)
                changes.add_edge(@genv, box.ret, ret)
              end
            end
          else
            # Non-tuple array: use unified element type for method name
            elem_vtx = ary_ty.get_elem(@genv)
            next unless elem_vtx
            changes.add_edge(@genv, elem_vtx, changes.target)

            send_a_args = ActualArguments.new(rest_positionals, rest_splat_flags, a_args.keywords, a_args.block)

            elem_vtx.each_type do |sym_ty|
              if sym_ty.is_a?(Type::Symbol)
                recv = Source.new(ty)
                box = changes.add_method_call_box(@genv, recv, sym_ty.sym, send_a_args, false)
                changes.add_edge(@genv, box.ret, ret)
              end
            end
          end
        end
      else
        # send(:sym, ...) case
        changes.add_edge(@genv, a_args.positionals[0], changes.target)
        send_a_args = ActualArguments.new(
          a_args.positionals[1..],
          a_args.splat_flags[1..],
          a_args.keywords,
          a_args.block,
        )
        a_args.positionals[0].each_type do |sym_ty|
          if sym_ty.is_a?(Type::Symbol)
            recv = Source.new(ty)
            box = changes.add_method_call_box(@genv, recv, sym_ty.sym, send_a_args, false)
            changes.add_edge(@genv, box.ret, ret)
          end
        end
      end
      true
    end

    def deploy
      [
        [method(:class_new), [:Class], false, :new],
        [method(:object_class), [:Object], false, :class],
        [method(:proc_call), [:Proc], false, :call],
        [method(:array_aref), [:Array], false, :[]],
        [method(:array_aset), [:Array], false, :[]=],
        [method(:array_push), [:Array], false, :<<],
        [method(:hash_aref), [:Hash], false, :[]],
        [method(:hash_aset), [:Hash], false, :[]=],
        [method(:object_method), [:Kernel], false, :method],
        [method(:method_call), [:Method], false, :call],
        [method(:kernel_send), [:BasicObject], false, :__send__],
        [method(:kernel_send), [:Kernel], false, :public_send],
        [method(:kernel_send), [:Kernel], false, :send],
      ].each do |builtin, cpath, singleton, mid|
        me = @genv.resolve_method(cpath, singleton, mid)
        me.builtin = builtin
      end
    end
  end
end
