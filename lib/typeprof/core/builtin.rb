module TypeProf::Core
  class Builtin
    def initialize(genv)
      @genv = genv
    end

    def class_new(changes, node, ty, a_args, ret)
      ty = ty.get_instance_type(@genv)
      recv = Source.new(ty)
      changes.add_method_call_box(@genv, node, recv, :initialize, a_args, false)
      changes.add_edge(@genv, Source.new(ty), ret)
    end

    def proc_call(changes, node, ty, a_args, ret)
      case ty
      when Type::Proc
        ty.block.accept_args(@genv, changes, a_args.positionals, ret, false)
      else
        puts "??? proc_call"
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
        else
          #puts "??? array_aref"
        end
      else
        #puts "??? array_aref"
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
        else
          puts "??? array_aset #{ ty.class }"
        end
      else
        puts "??? array_aset #{ a_args.positionals.size }"
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
        puts "??? array_aset #{ a_args.positionals.size }"
      end
    end

    def hash_aref(changes, node, ty, a_args, ret)
      if a_args.positionals.size == 1
        case ty
        when Type::Hash
          idx = node.positional_args[0]
          idx = idx.is_a?(AST::SymbolNode) ? idx.lit : nil
          changes.add_edge(@genv, ty.get_value(idx), ret)
        else
          #puts "??? hash_aref 1"
        end
      else
        puts "??? hash_aref 2"
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
        else
          #puts "??? hash_aset 1 #{ ty.object_id } #{ ty.inspect }"
        end
      else
        puts "??? hash_aset 2"
      end
    end

    def deploy
      {
        class_new: [[:Class], false, :new],
        proc_call: [[:Proc], false, :call],
        array_aref: [[:Array], false, :[]],
        array_aset: [[:Array], false, :[]=],
        array_push: [[:Array], false, :<<],
        hash_aref: [[:Hash], false, :[]],
        hash_aset: [[:Hash], false, :[]=],
      }.each do |key, (cpath, singleton, mid)|
        me = @genv.resolve_method(cpath, singleton, mid)
        me.builtin = method(key)
      end
    end
  end
end
