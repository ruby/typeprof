## update
def foo
  "foo#{ bar(1) }"
  "foo"\
    "#{ bar(1) }"
  "foo#{ bar(1) }baz#{ qux(1.0) }"
end

def bar(n)
  "bar"
end

def qux(n)
  "qux"
end

## assert
class Object
  def foo: -> String
  def bar: (Integer) -> String
  def qux: (Float) -> String
end

## update
def foo
  "foo#{ }"
end

## assert
class Object
  def foo: -> String
end

## update
def xstring_lit(n)
  `echo foo`
end

def interpolate_xstring
  `echo #{xstring_lit(10)}`
end

## assert
class Object
  def xstring_lit: (Integer) -> String
  def interpolate_xstring: -> String
end

## update
def foo
  "#$1"
end

## assert
class Object
  def foo: -> String
end
