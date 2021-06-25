require_relative "test_helper"
require_relative "../../lib/typeprof"

module TypeProf
  class AOBenchTest < Test::Unit::TestCase
    test "testbed/ao.rb" do
      name = "testbed/ao.rb"

      actual = TestRun.run(name)

      expected = <<-END
# Classes
class Object
  IMAGE_WIDTH: Integer
  IMAGE_HEIGHT: Integer
  NSUBSAMPLES: Integer
  NAO_SAMPLES: Integer

  private
  def clamp: (Float f) -> Integer
  def otherBasis: (Vec n) -> [Vec, Vec, Vec]
  def top: -> Integer
end

class Vec
  def initialize: (Float x, Float y, Float z) -> void
  attr_accessor x: Float
  attr_accessor y: Float
  attr_accessor z: Float
  def vadd: (Vec b) -> Vec
  def vsub: (Vec b) -> Vec
  def vcross: (Vec b) -> Vec
  def vdot: (Vec b) -> Float
  def vlength: -> Float
  def vnormalize: -> Vec
end

class Sphere
  def initialize: (Vec center, Float radius) -> void
  attr_reader center: Vec
  attr_reader radius: Float
  def intersect: (Ray ray, Isect isect) -> Vec?
end

class Plane
  @p: Vec
  @n: Vec

  def initialize: (Vec p, Vec n) -> void
  def intersect: (Ray ray, Isect isect) -> Vec?
end

class Ray
  def initialize: (Vec org, Vec dir) -> void
  attr_accessor org: Vec
  attr_accessor dir: Vec
end

class Isect
  def initialize: -> void
  attr_accessor t: Float
  attr_accessor hit: bool
  attr_accessor pl: Vec
  attr_accessor n: Vec
end

class Scene
  @spheres: [Sphere, Sphere, Sphere]
  @plane: Plane

  def initialize: -> void
  def ambient_occlusion: (Isect isect) -> Vec
  def render: (Integer w, Integer h, Integer nsubsamples) -> Integer
end
      END

      assert_equal(expected, actual)
    end
  end
end
