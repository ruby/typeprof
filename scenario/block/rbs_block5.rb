## update: test.rbs
class Object
  def yield_ary: { ([Integer, String]) -> untyped } -> void
end

## update: test.rb
def accept_x
  yield_ary {|x| return x }
  nil
end
def accept_x_y_z
  yield_ary {|x, y, z| return [x, y, z] }
  nil
end

## assert
class Object
  def accept_x: -> [Integer, String]?
  def accept_x_y_z: -> [Integer, String, nil]?
end

## update: test.rbs
class Object
  def yield_ary: { (Integer, String) -> untyped } -> void
end

## update: test.rb
def accept_x
  yield_ary {|x| return x }
  nil
end
def accept_x_y_z
  yield_ary {|x, y, z| return [x, y, z] }
  nil
end

## assert
class Object
  def accept_x: -> Integer?
  def accept_x_y_z: -> [Integer, String, untyped]?
end
