## update: test.rb
module A動物
  class B猫
    def call
      puts "にゃー"
    end
  end
end

A動物::B猫
A動物::B猫.new.call

## definition: test.rb:9:1
test.rb:(1,7)-(1,10) # Jump to module

## definition: test.rb:10:6
test.rb:(2,8)-(2,10) # Jump to class

## definition: test.rb:10:13
test.rb:(3,8)-(3,12) # Jump to #call method
