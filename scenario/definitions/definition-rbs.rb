## update: test.rbs
module Animal
  class Cat
    def call_1: () -> void
    def call_2: () -> void
  end
end

## update: test.rb
module Animal
  class Cat
    def call_1
      puts "meow"
    end
  end
end

Animal::Cat.new.call_1
#                ^[A]
Animal::Cat.new.call_2
#                ^[B]

## definition: [A]
test.rbs:(3,8)-(3,14)
test.rb:(3,8)-(3,14)

## definition: [B]
test.rbs:(4,8)-(4,14)
