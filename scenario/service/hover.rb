## update
def foo(variable)
#         ^[A]
  variable + 1
#  ^[B]
end

def main(_)
  foo(2)
end

## hover: [A]
Integer

## hover: [B]
Integer

## update
def foo(nnn)
  nnn.times do |var|
    var
#   ^[C]
  end
end

foo(42)

## hover: [C]
Integer
