module TypeProf
  class CodePosition
    def initialize(lineno, column)
      @lineno = lineno
      @column = column
    end

    def self.from_lsp(pos)
      new(pos[:line] + 1, pos[:character])
    end

    def to_lsp
      { line: @lineno - 1, character: @column }
    end

    attr_reader :lineno, :column

    def <=>(other)
      cmp = @lineno <=> other.lineno
      cmp == 0 ? @column <=> other.column : cmp
    end

    include Comparable

    def to_s
      "(%d,%d)" % [@lineno, @column]
    end

    alias inspect to_s

    def left
      raise if @column == 0
      CodePosition.new(@lineno, @column - 1)
    end

    def right
      CodePosition.new(@lineno, @column + 1)
    end
  end

  class CodeRange
    def initialize(first, last)
      @first = first
      @last = last
    end

    def self.from_node(node)
      pos1 = CodePosition.new(node.first_lineno, node.first_column)
      pos2 = CodePosition.new(node.last_lineno, node.last_column)
      new(pos1, pos2)
    end

    def to_lsp
      { start: @first.to_lsp, end: @last.to_lsp }
    end

    attr_reader :first, :last

    def include?(pos)
      @first <= pos && pos < @last
    end

    def to_s
      "%p-%p" % [@first, @last]
    end

    alias inspect to_s

    def ==(other)
      @first == other.first && @last == other.last
    end
  end
end