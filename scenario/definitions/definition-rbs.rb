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
Animal::Cat.new.call_2

## definition: test.rb:9:17
test.rbs:(3,8)-(3,14)
test.rb:(3,8)-(3,14)

## definition: test.rb:10:17
test.rbs:(4,8)-(4,14)
