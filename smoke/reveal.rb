p(1)
p("str")
p(:sym)
p([1, "str", :sym])

__END__
# Errors
smoke/reveal.rb:1: [p] Integer
smoke/reveal.rb:2: [p] String
smoke/reveal.rb:3: [p] Symbol
smoke/reveal.rb:4: [p] [Integer, String, Symbol]
# Classes
