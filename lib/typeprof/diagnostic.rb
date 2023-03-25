module TypeProf
  class Diagnostic
    def initialize(code_range, msg)
      @code_range = code_range.is_a?(TypeProf::CodeRange) ? code_range : code_range.code_range
      @msg = msg
      @severity = :error # TODO: keyword argument
      @tags = nil # TODO: keyword argument
    end

    attr_reader :msg, :severity, :code_range

    SEVERITY = { error: 1, warning: 2, info: 3, hint: 4 }
    TAG = { unnecesary: 1, deprecated: 2 }

    def to_lsp
      json = {
        range: @code_range.to_lsp,
        source: "TypeProf",
        message: @msg,
      }
      json[:severity] = SEVERITY[@severity] if @severity
      json[:tags] = @tags.map {|tag| TAG[tag] } if @tags
      json
    end
  end
end