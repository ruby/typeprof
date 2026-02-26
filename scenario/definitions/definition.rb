## update: test.rb
module Animal
  class Cat
    def call
      puts "meow"
    end
  end
end

Animal::Cat.new.call
#^[A]    ^[B]    ^[C]

## definition: [A]
test.rb:(1,7)-(1,13)

## definition: [B]
test.rb:(2,8)-(2,11)

## definition: [C]
test.rb:(3,8)-(3,12)
