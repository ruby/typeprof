## update
class C
  def self.foo=(v)
    v.is_a?(Module)
  end

  self.foo = 1
end
