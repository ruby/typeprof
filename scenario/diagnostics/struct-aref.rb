## update
Pt = Struct.new(:x, :y) do
  def initialize(x = 0, y = 0)
    super
  end
end

Pt[]
Pt[3, 4]
Pt[1, 2, 3]

## diagnostics
(9,2)-(9,11): wrong number of arguments (3 for 0...2)
