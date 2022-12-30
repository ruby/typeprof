class Incrementer
  def initialize
    @total = 0
  end

  def calc(num)
    @total += num
  end
end

incr = Incrementer.new
incr.calc("a")
