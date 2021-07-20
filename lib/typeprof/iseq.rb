module TypeProf
  class ISeq
    # https://github.com/ruby/ruby/pull/4468
    CASE_WHEN_CHECKMATCH = RubyVM::InstructionSequence.compile("case 1; when Integer; end").to_a.last.any? {|insn,| insn == :checkmatch }

    FileInfo = Struct.new(
      :node_id2code_range,
      :definition_table,
    )

    class << self
      def compile(file)
        compile_core(nil, file)
      end

      def compile_str(str, path = nil)
        compile_core(str, path)
      end

      private def compile_core(str, path)
        opt = RubyVM::InstructionSequence.compile_option
        opt[:inline_const_cache] = false
        opt[:peephole_optimization] = false
        opt[:specialized_instruction] = false
        opt[:operands_unification] = false
        opt[:coverage_enabled] = false

        if str
          node = RubyVM::AbstractSyntaxTree.parse(str)
          iseq = RubyVM::InstructionSequence.compile(str, path, **opt)
        else
          node = RubyVM::AbstractSyntaxTree.parse_file(path)
          iseq = RubyVM::InstructionSequence.compile_file(path, **opt)
        end

        node_id2code_range = {}
        build_ast_node_id_table(node, node_id2code_range)

        file_info = FileInfo.new(node_id2code_range, CodeRangeTable.new)

        return new(iseq.to_a, file_info), file_info.definition_table
      end

      private def build_ast_node_id_table(node, tbl = {})
        tbl[node.node_id] = CodeRange.new(
          CodeLocation.new(node.first_lineno, node.first_column),
          CodeLocation.new(node.last_lineno, node.last_column),
        )
        node.children.each do |child|
          build_ast_node_id_table(child, tbl) if child.is_a?(RubyVM::AbstractSyntaxTree::Node)
        end
        tbl
      end
    end

    def add_called_iseq(pc, callee_iseq)
      if callee_iseq && @definitions[pc]
        @definitions[pc] << [callee_iseq.path, callee_iseq.iseq_code_range]
      end
    end

    FRESH_ID = [0]

    def initialize(iseq, file_info)
      @id = FRESH_ID[0]
      FRESH_ID[0] += 1

      _magic, _major_version, _minor_version, _format_type, misc,
        @name, @path, @absolute_path, @start_lineno, @type,
        @locals, @fargs_format, catch_table, insns = *iseq

      node_ids = misc[:node_ids]
      raw_code_ranges = node_ids.map {|node_id| file_info.node_id2code_range[node_id] }

      fl, fc, ll, lc = misc[:code_location]
      @iseq_code_range = CodeRange.new(CodeLocation.new(fl, fc), CodeLocation.new(ll, lc))

      case @type
      when :method, :block
        if @fargs_format[:opt]
          label = @fargs_format[:opt].last
          i = insns.index(label) + 1
        else
          i = insns.find_index {|insn| insn.is_a?(Array) }
        end
        # skip keyword initialization
        while insns[i][0] == :checkkeyword
          raise if insns[i + 1][0] != :branchif
          label = insns[i + 1][1]
          i = insns.index(label) + 1
        end
        insns[i, 0] = [[:_iseq_body_start]]
        raw_code_ranges.unshift(nil)
      end

      # rescue/ensure clauses need to have a dedicated return addresses
      # because they requires to be virtually called.
      # So, this preprocess adds "nop" to make a new insn for their return addresses
      special_labels = {}
      catch_table.map do |type, iseq, first, last, cont, stack_depth|
        special_labels[cont] = true if type == :rescue || type == :ensure
      end

      @insns = []
      @linenos = []
      @code_ranges = []
      @definitions = []

      labels = setup_iseq(insns, special_labels, raw_code_ranges, file_info)

      # checkmatch->branch
      # send->branch

      @catch_table = []
      catch_table.map do |type, iseq, first, last, cont, stack_depth|
        iseq = iseq ? ISeq.new(iseq, file_info) : nil
        target = labels[special_labels[cont] ? :"#{ cont }_special" : cont]
        entry = [type, iseq, target, stack_depth]
        labels[first].upto(labels[last]) do |i|
          @catch_table[i] ||= []
          @catch_table[i] << entry
        end
      end

      merge_branches

      analyze_stack
    end

    def <=>(other)
      @id <=> other.id
    end

    def setup_iseq(insns, special_labels, raw_code_ranges, file_info)
      i = 0
      labels = {}
      ninsns = []
      code_ranges = []
      insns.each do |e|
        if e.is_a?(Symbol) && e.to_s.start_with?("label")
          if special_labels[e]
            labels[:"#{ e }_special"] = i
            ninsns << [:nop]
            code_ranges << nil
            i += 1
          end
          labels[e] = i
        else
          ninsns << e
          if e.is_a?(Array)
            i += 1
            code_ranges << raw_code_ranges.shift
          end
        end
      end

      lineno = 0
      ninsns.each do |e|
        case e
        when Integer # lineno
          lineno = e
        when Symbol # label or trace
          nil
        when Array
          insn, *operands = e
          operands = (INSN_TABLE[insn] || []).zip(operands).map do |type, operand|
            case type
            when "ISEQ"
              operand && ISeq.new(operand, file_info)
            when "lindex_t", "rb_num_t", "VALUE", "ID", "GENTRY", "CALL_DATA"
              operand
            when "OFFSET"
              labels[operand] || raise("unknown label: #{ operand }")
            when "IVC", "ISE"
              raise unless operand.is_a?(Integer)
              :_cache_operand
            else
              raise "unknown operand type: #{ type }"
            end
          end
          code_range = code_ranges.shift

          if code_range && insn == :send
            definition = Utils::MutableSet.new
            file_info.definition_table[code_range] = definition
          end

          @insns << [insn, operands]
          @linenos << lineno
          @code_ranges << code_range
          @definitions << definition
        else
          raise "unknown iseq entry: #{ e }"
        end
      end

      @fargs_format[:opt] = @fargs_format[:opt].map {|l| labels[l] } if @fargs_format[:opt]

      labels
    end

    def merge_branches
      @insns.size.times do |i|
        insn, operands = @insns[i]
        case insn
        when :branchif
          @insns[i] = [:branch, [:if] + operands]
        when :branchunless
          @insns[i] = [:branch, [:unless] + operands]
        when :branchnil
          @insns[i] = [:branch, [:nil] + operands]
        end
      end
    end

    def source_location(pc)
      "#{ @path }:#{ @linenos[pc] }"
    end

    def detailed_source_location(pc)
      if @code_ranges[pc]
        [@path, @code_ranges[pc]]
      else
        nil
      end
    end

    attr_reader :name, :path, :absolute_path, :start_lineno, :type, :locals, :fargs_format, :catch_table, :insns, :linenos
    attr_reader :id, :code_ranges, :iseq_code_range

    def pretty_print(q)
      q.text "ISeq["
      q.group do
        q.nest(1) do
          q.breakable ""
          q.text "@type=          #{ @type }"
          q.breakable ", "
          q.text "@name=          #{ @name }"
          q.breakable ", "
          q.text "@path=          #{ @path }"
          q.breakable ", "
          q.text "@absolute_path= #{ @absolute_path }"
          q.breakable ", "
          q.text "@start_lineno=  #{ @start_lineno }"
          q.breakable ", "
          q.text "@fargs_format=  #{ @fargs_format.inspect }"
          q.breakable ", "
          q.text "@insns="
          q.group(2) do
            @insns.each_with_index do |(insn, *operands), i|
              q.breakable
              q.group(2, "#{ i }: #{ insn.to_s }", "") do
                q.pp operands
              end
            end
          end
        end
        q.breakable
      end
      q.text "]"
    end

    def analyze_stack
      # gather branch targets
      # TODO: catch_table should be also considered
      branch_targets = {}
      @insns.each do |insn, operands|
        case insn
        when :branch
          branch_targets[operands[1]] = true
        when :jump
          branch_targets[operands[0]] = true
        end
      end

      # flow-sensitive analysis for `case var; when A; when B; when C; end`
      # find a pattern: getlocal, (dup, putobject(true), getconstant(class name), checkmatch, branch)* for ..Ruby 3.0
      # find a pattern: getlocal, (putobject(true), getconstant(class name), top(1), send(===), branch)* for Ruby 3.1..
      case_branch_list = []
      if CASE_WHEN_CHECKMATCH
        (@insns.size - 1).times do |i|
          insn0, getlocal_operands = @insns[i]
          next unless [:getlocal, :getblockparam, :getblockparamproxy].include?(insn0) && getlocal_operands[1] == 0
          nops = [i]
          new_insns = []
          j = i + 1
          while true
            case @insns[j]
            when [:dup, []]
              break unless @insns[j + 1] == [:putnil, []]
              break unless @insns[j + 2] == [:putobject, [true]]
              break unless @insns[j + 3][0] == :getconstant # TODO: support A::B::C
              break unless @insns[j + 4] == [:checkmatch, [2]]
              break unless @insns[j + 5][0] == :branch
              target_pc = @insns[j + 5][1][1]
              break unless @insns[target_pc] == [:pop, []]
              nops << j << (j + 4) << target_pc
              new_insns << [j + 5, [:getlocal_checkmatch_branch, [getlocal_operands, @insns[j + 5][1]]]]
              j += 6
            when [:pop, []]
              nops << j
              case_branch_list << [nops, new_insns]
              break
            else
              break
            end
          end
        end
      else
        (@insns.size - 1).times do |i|
          insn0, getlocal_operands = @insns[i]
          next unless [:getlocal, :getblockparam, :getblockparamproxy].include?(insn0) && getlocal_operands[1] == 0
          nops = []
          new_insns = []
          j = i + 1
          while true
            case @insns[j]
            when [:putnil, []]
              break unless @insns[j + 1] == [:putobject, [true]]
              break unless @insns[j + 2][0] == :getconstant # TODO: support A::B::C
              break unless @insns[j + 3] == [:topn, [1]]
              break unless @insns[j + 4] == [:send, [{:mid=>:===, :flag=>20, :orig_argc=>1}, nil]]
              break unless @insns[j + 5][0] == :branch
              target_pc = @insns[j + 5][1][1]
              break unless @insns[target_pc] == [:pop, []]
              nops << (j + 4) #<< target_pc
              new_insns << [j + 5, [:arg_getlocal_send_branch, [getlocal_operands, @insns[j + 4][1], @insns[j + 5][1]]]]
              j += 6
            when [:pop, []]
              #nops << j
              case_branch_list << [nops, new_insns]
              break
            else
              break
            end
          end
        end
      end
      case_branch_list.each do |nops, new_insns|
        nops.each {|i| @insns[i] = [:nop, []] }
        new_insns.each {|i, insn| @insns[i] = insn }
      end

      # find a pattern: getlocal(recv), ..., send (is_a?, respond_to?), branch
      recv_getlocal_send_branch_list = []
      (@insns.size - 1).times do |i|
        insn, operands = @insns[i]
        if insn == :getlocal && operands[1] == 0
          j = i + 1
          sp = 1
          while @insns[j]
            sp = check_send_branch(sp, j)
            if sp == :match
              recv_getlocal_send_branch_list << [i, j]
              break
            end
            break if !sp
            j += 1
          end
        end
      end
      recv_getlocal_send_branch_list.each do |i, j|
        next if (i + 1 .. j + 1).any? {|i| branch_targets[i] }
        _insn, getlocal_operands = @insns[i]
        _insn, send_operands = @insns[j]
        _insn, branch_operands = @insns[j + 1]
        @insns[j] = [:nop]
        @insns[j + 1] = [:recv_getlocal_send_branch, [getlocal_operands, send_operands, branch_operands]]
      end

      # find a pattern: getlocal, send (===), branch
      arg_getlocal_send_branch_list = []
      (@insns.size - 1).times do |i|
        insn1, operands1 = @insns[i]
        next unless insn1 == :getlocal && operands1[1] == 0
        insn2, operands2 = @insns[i + 1]
        next unless insn2 == :send
        send_opt = operands2[0]
        next unless send_opt[:flag] == 16 && send_opt[:orig_argc] == 1
        insn3, _operands3 = @insns[i + 2]
        next unless insn3 == :branch
        arg_getlocal_send_branch_list << i
      end
      arg_getlocal_send_branch_list.each do |i|
        next if (i .. i + 2).any? {|i| branch_targets[i] }
        _insn, getlocal_operands = @insns[i]
        _insn, send_operands = @insns[i + 1]
        _insn, branch_operands = @insns[i + 2]
        @insns[i + 1] = [:nop]
        @insns[i + 2] = [:arg_getlocal_send_branch, [getlocal_operands, send_operands, branch_operands]]
      end

      # find a pattern: send (block_given?), branch
      send_branch_list = []
      (@insns.size - 1).times do |i|
        insn, _operands = @insns[i]
        if insn == :send
          insn, _operands = @insns[i + 1]
          if insn == :branch
            send_branch_list << i
          end
        end
      end
      send_branch_list.each do |i|
        next if branch_targets[i + 1]
        _insn, send_operands = @insns[i]
        _insn, branch_operands = @insns[i + 1]
        @insns[i] = [:nop]
        @insns[i + 1] = [:send_branch, [send_operands, branch_operands]]
      end

      # find a pattern: getlocal, dup, branch
      (@insns.size - 2).times do |i|
        next if branch_targets[i + 1] || branch_targets[i + 2]
        insn0, getlocal_operands = @insns[i]
        insn1, dup_operands = @insns[i + 1]
        insn2, branch_operands = @insns[i + 2]
        if insn0 == :getlocal && insn1 == :dup && insn2 == :branch && getlocal_operands[1] == 0
          @insns[i    ] = [:nop]
          @insns[i + 1] = [:nop]
          @insns[i + 2] = [:getlocal_dup_branch, [getlocal_operands, dup_operands, branch_operands]]
        end
      end

      # find a pattern: dup, branch
      (@insns.size - 1).times do |i|
        next if branch_targets[i + 1]
        insn0, dup_operands = @insns[i]
        insn1, branch_operands = @insns[i + 1]
        if insn0 == :dup && insn1 == :branch
          @insns[i    ] = [:nop]
          @insns[i + 1] = [:dup_branch, [dup_operands, branch_operands]]
        end
      end

      # find a pattern: getlocal, branch
      (@insns.size - 1).times do |i|
        next if branch_targets[i + 1]
        insn0, getlocal_operands = @insns[i]
        insn1, branch_operands = @insns[i + 1]
        if [:getlocal, :getblockparam, :getblockparamproxy].include?(insn0) && getlocal_operands[1] == 0 && insn1 == :branch
          @insns[i    ] = [:nop]
          @insns[i + 1] = [:getlocal_branch, [getlocal_operands, branch_operands]]
        end
      end
    end

    def check_send_branch(sp, j)
      insn, operands = @insns[j]

      case insn
      when :putspecialobject, :putnil, :putobject, :duparray, :putstring,
           :putself
        sp += 1
      when :newarray, :newarraykwsplat, :newhash, :concatstrings
        len, = operands
        sp =- len
        return nil if sp <= 0
        sp += 1
      when :newhashfromarray
        raise NotImplementedError, "newhashfromarray"
      when :newrange, :tostring
        sp -= 2
        return nil if sp <= 0
        sp += 1
      when :freezestring
        # XXX: should leverage this information?
      when :toregexp
        _regexp_opt, len = operands
        sp -= len
        return nil if sp <= 0
        sp += 1
      when :intern
        sp -= 1
        return nil if sp <= 0
        sp += 1
      when :definemethod, :definesmethod
      when :defineclass
        sp -= 2
      when :send, :invokesuper
        opt, = operands
        _flags = opt[:flag]
        _mid = opt[:mid]
        kw_arg = opt[:kw_arg]
        argc = opt[:orig_argc]
        argc += 1 # receiver
        argc += kw_arg.size if kw_arg
        sp -= argc
        return :match if insn == :send && sp == 0 && @insns[j + 1][0] == :branch
        sp += 1
      when :arg_getlocal_send_branch
        return # not implemented
      when :invokeblock
        opt, = operands
        sp -= opt[:orig_argc]
        return nil if sp <= 0
        sp += 1
      when :invokebuiltin
        raise NotImplementedError
      when :leave, :throw
        return
      when :once
        return # not implemented
      when :branch, :jump
        return # not implemented
      when :setinstancevariable, :setclassvariable, :setglobal
        sp -= 1
      when :setlocal, :setblockparam
        return # conservative
      when :getinstancevariable, :getclassvariable, :getglobal,
           :getlocal, :getblockparam, :getblockparamproxy
        sp += 1
      when :getconstant
        sp -= 2
        return nil if sp <= 0
        sp += 1
      when :setconstant
        sp -= 2
      when :getspecial
        sp += 1
      when :setspecial
        # flip-flop
        raise NotImplementedError, "setspecial"
      when :dup
        sp += 1
      when :duphash
        sp += 1
      when :dupn
        n, = operands
        sp += n
      when :pop
        sp -= 1
      when :swap
        sp -= 2
        return nil if sp <= 0
        sp += 2
      when :reverse
        n, = operands
        sp -= n
        return nil if sp <= 0
        sp += n
      when :defined
        sp -= 1
        return nil if sp <= 0
        sp += 1
      when :checkmatch
        sp -= 2
        return nil if sp <= 0
        sp += 1
      when :checkkeyword
        sp += 1
      when :adjuststack
        n, = operands
        sp -= n
      when :nop
      when :setn
        return nil # not implemented
      when :topn
        sp += 1
      when :splatarray
        sp -= 1
        return nil if sp <= 0
        sp += 1
      when :expandarray
        num, flag = operands
        splat = flag & 1 == 1
        sp -= 1
        return nil if sp <= 0
        sp += num + (splat ? 1 : 0)
      when :concatarray
        sp -= 2
        return nil if sp <= 0
        sp += 1
      when :checktype
        sp -= 1
        return nil if sp <= 0
        sp += 1
      else
        raise "Unknown insn: #{ insn }"
      end

      return nil if sp <= 0
      sp
    end
  end
end
