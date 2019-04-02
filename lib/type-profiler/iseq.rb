module TypeProfiler
  class ISeq
    include Utils::StructuralEquality

    def self.compile(file)
      opt = RubyVM::InstructionSequence.compile_option
      opt[:inline_const_cache] = false
      opt[:peephole_optimization] = false
      opt[:specialized_instruction] = false
      opt[:operands_unification] = false
      opt[:coverage_enabled] = false
      iseq = new(RubyVM::InstructionSequence.compile_file(file, opt).to_a)
      iseq.escape_analysis
      iseq
    end

    def self.compile_str(str)
      opt = RubyVM::InstructionSequence.compile_option
      opt[:inline_const_cache] = false
      opt[:peephole_optimization] = false
      opt[:specialized_instruction] = false
      opt[:operands_unification] = false
      opt[:coverage_enabled] = false
      iseq = new(RubyVM::InstructionSequence.compile(str, opt).to_a)
      iseq.escape_analysis
      iseq
    end

    def initialize(iseq)
      _magic, _major_version, _minor_version, _format_type, _misc,
        @name, @path, @absolute_path, @start_lineno, @type,
        @locals, @args, _catch_table, insns = *iseq

      @escaped_locals = []

      i = 0
      labels = {}
      insns.each do |e|
        if e.is_a?(Symbol) && e.to_s.start_with?("label")
          labels[e] = i
        elsif e.is_a?(Array)
          i += 1
        end
      end

      @args[:opt] = @args[:opt].map {|l| labels[l] } if @args[:opt]

      @insns = []
      @linenos = []

      lineno = 0
      insns.each do |e|
        case e
        when Integer # lineno
          lineno = e
        when Symbol # label or trace
          nil
        when Array
          insn, *operands = e
          operands = INSN_TABLE[insn].zip(operands).map do |type, operand|
            case type
            when "ISEQ"
              operand && ISeq.new(operand)
            when "lindex_t", "rb_num_t", "VALUE"
              operand
            when "ID", "GENTRY"
              operand
            when "CALL_INFO"
              operand
            when "OFFSET"
              labels[operand] || raise("unknown label: #{ operand }")
            when "CALL_CACHE"
              raise unless operand == false
              :_cache_operand
            when "IC", "ISE"
              raise unless operand.is_a?(Integer)
              :_cache_operand
            else
              raise "unknown operand type: #{ type }"
            end
          end

          @insns << [insn, *operands]
          @linenos << lineno
        else
          raise "unknown iseq entry: #{ e }"
        end
      end
    end

    def escape_analysis
      identify_escaped_locals([])
      replace_local_access_insns([])
    end

    def identify_escaped_locals(parent_iseqs)
      @insns.each do |insn, *operands|
        operands.each do |operand|
          operand.identify_escaped_locals(parent_iseqs + [self]) if operand.is_a?(ISeq)
        end
        if insn == :setlocal
          var_idx, scope_idx = operands
          if scope_idx >= 1
            tiseq = parent_iseqs[-scope_idx]
            tiseq.escaped_locals << var_idx
          end
        end
      end
    end

    def replace_local_access_insns(parent_iseqs)
      @insns = @insns.map do |insn, *operands|
        operands.each do |operand|
          operand.replace_local_access_insns(parent_iseqs + [self]) if operand.is_a?(ISeq)
        end
        if [:getlocal, :getblockparam, :getblockparamproxy, :setlocal].include?(insn)
          var_idx, scope_idx = operands
          tiseq = (parent_iseqs + [self])[-scope_idx - 1]
          [insn, *operands, tiseq.escaped_locals.include?(var_idx)]
        else
          [insn, *operands]
        end
      end
    end

    def source_location(pc)
      "#{ @path }:#{ @linenos[pc] }"
    end

    attr_reader :name, :path, :abolute_path, :start_lineno, :type, :locals, :escaped_locals, :args, :insns, :linenos
  end
end
