class Base
  def initialize
    @warnings_suppressed = false
  end

  def suppress_warnings!
    tap { @warnings_suppressed = true }
  end

  def warn(message, event = nil)
    return if @warnings_suppressed
    puts message
  end
end

class Subclass < Base
  def do_stuff
    warn("Something went wrong")
  end
end
__END__
# Classes
class Base
  @warnings_suppressed: bool

  def initialize: -> void
  def suppress_warnings!: -> Base
  def warn: (String | untyped message, ?nil event) -> nil
end

class Subclass < Base
  def do_stuff: -> nil
end
