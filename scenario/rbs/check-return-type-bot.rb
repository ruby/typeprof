## update
# Instance type (typecheck_for_module): pure bot
#: -> String
def test_instance
  return "hello"
end

# Instance type (typecheck_for_module): mixed bot
#: (bool) -> String
def test_instance_mixed(a)
  if a
    return "hello"
  end
  "world"
end

# Bool type (SigTyBaseBoolNode): pure bot
#: -> bool
def test_bool
  return false
end

# Bool type (SigTyBaseBoolNode): mixed bot
#: (bool) -> bool
def test_bool_mixed(a)
  if a
    return true
  end
  false
end

# Nil type (SigTyBaseNilNode): pure bot
#: -> nil
def test_nil
  return nil
end

# Nil type (SigTyBaseNilNode): mixed bot
#: (bool) -> nil
def test_nil_mixed(a)
  if a
    return nil
  end
  nil
end

# Tuple type (SigTyTupleNode): pure bot
#: -> [Integer, String]
def test_tuple
  return [1, "hello"]
end

# Tuple type (SigTyTupleNode): mixed bot
#: (bool) -> [Integer, String]
def test_tuple_mixed(a)
  if a
    return [1, "hello"]
  end
  [2, "world"]
end

# Literal symbol type (SigTyLiteralNode): pure bot
#: -> :foo
def test_symbol
  return :foo
end

# Literal symbol type (SigTyLiteralNode): mixed bot
#: (bool) -> :foo
def test_symbol_mixed(a)
  if a
    return :foo
  end
  :foo
end

## diagnostics
