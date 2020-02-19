require "json"

sigs = JSON.parse(File.read(File.join(__dir__, "rbs.json")), symbolized_names: true)

trans = -> e do
  case e
  when Array then e.map {|e| trans[e] }
  when Hash then e.to_h {|k, v| [k, trans[v]] }
  when String then e.to_sym
  else e
  end
end

STDLIB_SIGS = trans[sigs]
