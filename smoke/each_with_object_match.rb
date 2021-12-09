def foo
  [:foo, 1, nil].each_with_object({}) do |(key, value), acc|
    acc[key] =
      case value
      when Object
        :object
      else
        :other
      end
  end
end

__END__
# Classes
class Object
  private
  def foo: -> Hash[untyped, untyped]
end
