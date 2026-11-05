module TypeProf
  module Dsl
    module Ruby
      # Only the block form is supported. The second-argument form
      # (Proc / Method / UnboundMethod) is not handled yet.
      # https://docs.ruby-lang.org/en/4.0/Module.html#method-i-define_method
      class DefineMethod < TypeProf::Dsl::Base
        on "Module#define_method"

        def install(scope)
          name = scope.arg_symbol(0) or return
          return unless scope.has_block?
          scope.owner.define_method_from_block(name)
        end
      end
    end
  end
end
