class Student
  def initialize id, name
    @skill = 0
  end

  def study subject
    puts "study #{subject}"
    @skill += 1
  end
end
liam = Student.new(1, "Liam")
liam.study("math")
# wrong codes
liam.study
liam.study("math", "english")
liam.foo
