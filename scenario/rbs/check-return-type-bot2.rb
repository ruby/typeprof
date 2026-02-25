## update
class Foo
end

# Singleton type (SigTySingletonNode): pure bot
#: -> singleton(Foo)
def test_singleton
  return Foo
end

# Singleton type (SigTySingletonNode): mixed bot
#: (bool) -> singleton(Foo)
def test_singleton_mixed(a)
  if a
    return Foo
  end
  Foo
end

## diagnostics
