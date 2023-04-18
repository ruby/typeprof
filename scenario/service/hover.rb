## update
def foo(variable)
  variable + 1
end

def main(_)
  foo(2)
end

## hover: test.rb:1:10
Integer

## hover: test.rb:2:3
Integer

## update
def foo(nnn)
  nnn.times do |var|
    var
  end
end

foo(42)

## hover: test.rb:3:4
Integer