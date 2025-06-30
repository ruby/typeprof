module TypeProf
  class Diagnostic
    module DisableDirective
      # Determine which diagnostic ranges should not be reported.
      class Filter
        def initialize(ranges)
          @ranges = ranges
        end

        def skip?(line)
          @ranges.any? { |r| r.cover?(line) }
        end
      end
    end
  end
end
