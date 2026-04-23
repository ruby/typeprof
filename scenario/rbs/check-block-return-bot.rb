## update
class C
  # Instance type (typecheck_for_module): pure bot
  #: { () -> String } -> void
  def yield_instance
    yield
  end

  def test_instance
    yield_instance do
      next "hello"
    end
  end

  # Bool type (SigTyBaseBoolNode): pure bot
  #: { () -> bool } -> void
  def yield_bool
    yield
  end

  def test_bool
    yield_bool do
      next false
    end
  end

  # Nil type (SigTyBaseNilNode): pure bot
  #: { () -> nil } -> void
  def yield_nil
    yield
  end

  def test_nil
    yield_nil do
      next nil
    end
  end
end

## diagnostics
