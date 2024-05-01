module TypeProf
  class Diagnostic
    def initialize(node, meth, msg)
      @node = node
      @meth = meth
      @msg = msg
      @severity = :error # TODO: keyword argument
      @tags = nil # TODO: keyword argument
    end

    def reuse(new_node)
      @node = new_node
    end

    attr_reader :msg, :severity

    def code_range
      @node.send(@meth)
    end

    SEVERITY = { error: 1, warning: 2, info: 3, hint: 4 }
    TAG = { unnecessary: 1, deprecated: 2 }

    def to_lsp
      json = {
        range: code_range.to_lsp,
        source: "TypeProf",
        message: @msg,
      }
      json[:severity] = SEVERITY[@severity] if @severity
      json[:tags] = @tags.map {|tag| TAG[tag] } if @tags
      json
    end
  end
end
