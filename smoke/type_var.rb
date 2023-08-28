def number?(ty)
  %w[integer float].include?(ty).then { nil }
end
number?('string')

__END__
# Classes
class Object
  private
  def number?: (String ty) -> nil
end
