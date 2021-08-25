def foo
  Hash.new { |h, k| h[k] = [] }
end

foo
__END__
# Classes
class Object
  private
  def foo: -> Hash[untyped, untyped]
end
