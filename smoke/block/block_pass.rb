# update
def foo
  yield 42
end

def proxy(&blk)
  foo(&blk)
end

def bar
  ret = nil
  foo do |n|
    ret = n
  end
  ret
end

# assert
def foo: () ({ (Integer) -> Integer }) -> Integer
def proxy: () -> Integer
def bar: () -> Integer?

# update
def foo(x)
  yield 42
end

def proxy(&blk)
  foo(1, &blk)
end

def bar
  ret = nil
  foo do |n|
    ret = n
  end
  ret
end

# assert
def foo: (Integer) ({ (Integer) -> Integer }) -> Integer
def proxy: () -> Integer
def bar: () -> Integer?