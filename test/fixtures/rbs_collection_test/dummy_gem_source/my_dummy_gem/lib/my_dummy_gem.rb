def hello(name)
  @name = name
  "Hello, #{ @name }"
  raise
end
