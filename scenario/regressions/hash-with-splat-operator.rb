## update
def opts(prefix)
  { "#{prefix}_key" => 1 }
end

def test
  {
    **opts(:cat),
    **opts(:dog)
  }
end
