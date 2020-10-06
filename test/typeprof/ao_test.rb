require_relative "test_helper"
require_relative "../../lib/typeprof"

module TypeProf
  class AOBenchTest < Test::Unit::TestCase
    test "testbed/ao.rb" do
      path = File.join(__dir__, "../../testbed/ao.rb")
      name = "testbed/ao.rb"

      actual = TestRun.run(name, File.read(path))

      expected = <<-END
# Classes
class Object
  def clamp : (Float) -> Integer
  def otherBasis : (Vec) -> [Vec, Vec, Vec]
  def top : -> Integer
end

class Vec
  attr_accessor x : Float
  attr_accessor y : Float
  attr_accessor z : Float
  def initialize : (Float, Float, Float) -> Float
  def vadd : (Vec) -> Vec
  def vsub : (Vec) -> Vec
  def vcross : (Vec) -> Vec
  def vdot : (Vec) -> Float
  def vlength : -> Float
  def vnormalize : -> Vec
end

class Sphere
  attr_reader center : Vec
  attr_reader radius : Float
  def initialize : (Vec, Float) -> Float
  def intersect : (Ray, Isect) -> Vec?
end

class Plane
  @p : Vec
  @n : Vec
  def initialize : (Vec, Vec) -> Vec
  def intersect : (Ray, Isect) -> Vec?
end

class Ray
  attr_accessor org : Vec
  attr_accessor dir : Vec
  def initialize : (Vec, Vec) -> Vec
end

class Isect
  attr_accessor t : Float
  attr_accessor hit : bool
  attr_accessor pl : Vec
  attr_accessor n : Vec
  def initialize : -> Vec
end

class Scene
  @spheres : [Sphere, Sphere, Sphere]
  @plane : Plane
  def initialize : -> Plane
  def ambient_occlusion : (Isect) -> Vec
  def render : (Integer, Integer, Integer) -> Integer
end
      END

      assert_equal(expected, actual)
    end
  end
end
