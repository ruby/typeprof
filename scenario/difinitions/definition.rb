## update: test.rb
module Animal
  class Cat
    def call
      puts "meow"
    end
  end
end

Animal::Cat.new.call

## definition: test.rb:9:1
test.rb:(1,7)-(1,13)

## definition: test.rb:9:9
test.rb:(2,8)-(2,11)

## definition: test.rb:9:17
test.rb:(3,8)-(3,12)
