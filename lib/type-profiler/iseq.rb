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
      new(RubyVM::InstructionSequence.compile_file(file, opt).to_a)
    end

    def self.compile_str(str)
      opt = RubyVM::InstructionSequence.compile_option
      opt[:inline_const_cache] = false
      opt[:peephole_optimization] = false
      opt[:specialized_instruction] = false
      opt[:operands_unification] = false
      opt[:coverage_enabled] = false
      new(RubyVM::InstructionSequence.compile(str, opt).to_a)
    end

    def initialize(iseq)
      _magic, _major_version, _minor_version, _format_type, _misc,
        @name, @path, @absolute_path, @start_lineno, @type,
        @locals, @args, _catch_table, insns = *iseq

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

    def source_location(pc)
      "#{ @path }:#{ @linenos[pc] }"
    end

    attr_reader :name, :path, :abolute_path, :start_lineno, :type, :locals, :args, :insns, :linenos

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
          q.text "@args=          #{ @args.inspect }"
          q.breakable ", "
          q.text "@insns="
          q.group(2) do
            @insns.each do |insn, *operands|
              q.breakable
              q.group(2, insn.to_s, "") do
                q.pp operands
              end
            end
          end
        end
        q.breakable
      end
      q.text "]"
    end
  end
end
