module TypeProf
  class Diagnostic
    def initialize(node, meth, msg, severity: :error, tags: nil)
      @node = node
      @meth = meth
      @msg = msg
      @severity = severity
      @tags = tags
    end

    def reuse(new_node)
      @node = new_node
    end

    attr_reader :msg, :severity, :tags

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
