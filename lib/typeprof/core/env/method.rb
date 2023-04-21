module TypeProf::Core
  class FormalArguments
    def initialize(req_positionals, opt_positionals, rest_positionals, post_positionals, req_keywords, opt_keywords, rest_keywords, block)
      @req_positionals = req_positionals
      @opt_positionals = opt_positionals
      @rest_positionals = rest_positionals
      @post_positionals = post_positionals
      @req_keywords = req_keywords
      @opt_keywords = opt_keywords
      @rest_keywords = rest_keywords
      @block = block
    end

    Empty = FormalArguments.new([], [], nil, [], [], [], nil, nil)

    attr_reader :req_positionals
    attr_reader :opt_positionals
    attr_reader :rest_positionals
    attr_reader :post_positionals
    attr_reader :req_keywords
    attr_reader :opt_keywords
    attr_reader :rest_keywords
    attr_reader :block

    def ==(other)
      return false if @req_positionals != other.req_positionals
      return false if @opt_positionals != other.opt_positionals
      return false if @rest_positionals != other.rest_positionals
      return false if @post_positionals != other.post_positionals
      return false if @req_keywords != other.req_keywords
      return false if @opt_keywords != other.opt_keywords
      return false if @rest_keywords != other.rest_keywords
      return false if @block != other.block
      return true
    end

    def each_var(&blk)
      @req_positionals.each(&blk)
      @opt_positionals.each(&blk)
      yield @rest_positionals if @rest_positionals
      @post_positionals.each(&blk)
      @req_keywords.each(&blk)
      @opt_keywords.each(&blk)
      yield @rest_keywords if @rest_keywords
      yield @block if @block
    end
  end

  class Block
    def initialize(node, f_args, ret)
      @node = node
      @f_args = f_args
      @ret = ret
    end

    attr_reader :node, :f_args, :ret
  end
end