# update
def foo
  1.times {|_| }
end

def bar
  1.times # TODO: type parameter of Enumerator
end

# assert
def foo: () -> Integer
def bar: () -> Enumerator