## update: test.rb
module A動物
  class B猫
    def 🐱🐱🐱
      puts "にゃー"
    end
  end
end

A動物::B猫.new.🐱🐱🐱
#^[A] ^[B]   ^[C]

## definition: [A]
test.rb:(1,7)-(1,10)

## definition: [B]
test.rb:(2,8)-(2,10)

## definition: [C]
test.rb:(3,8)-(3,14)
