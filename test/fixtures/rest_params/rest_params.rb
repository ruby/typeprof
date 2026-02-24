def foo(*args)
  args
end

def bar(**kwargs)
  kwargs
end

foo(1)
bar(x: "str")
