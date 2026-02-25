## update
# Instance type (typecheck_for_module): pure bot
#: { () -> String } -> void
def yield_instance
  yield
end

yield_instance do
  next "hello"
end

# Bool type (SigTyBaseBoolNode): pure bot
#: { () -> bool } -> void
def yield_bool
  yield
end

yield_bool do
  next false
end

# Nil type (SigTyBaseNilNode): pure bot
#: { () -> nil } -> void
def yield_nil
  yield
end

yield_nil do
  next nil
end

## diagnostics
