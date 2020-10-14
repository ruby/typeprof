$foo = 1

def log
  $foo
end

__END__
# Errors
smoke/gvar2.rb:1: [warning] inconsistent assignment to RBS-declared global variable

# Global variables
#$foo : String
$foo : Integer

# Classes
class Object
  def log : -> (Integer | String)
end
