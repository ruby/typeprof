class User
  def foo(name: "str", age: 0)
    @name, @age = name, age
  end

  attr_reader :name, :age
end
