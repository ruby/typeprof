def number?(type)
  %w[integer float].include?(type).then { puts 1 }
end
number?('string')

__END__
# Classes
class Object
  private
  def number?: (String) -> nil
end
