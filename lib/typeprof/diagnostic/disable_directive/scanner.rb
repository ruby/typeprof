module TypeProf
  class Diagnostic
    module DisableDirective
      # Determine which diagnostic ranges should not be reported.
      #
      # This scanner processes comments in the source code to identify which lines should be excluded from diagnostics.
      # It supports both block-level and inline disable/enable comments.
      #
      # Block-level comments start with `# typeprof:disable` and end with `# typeprof:enable`.
      # Inline comments with `# typeprof:disable` exclude diagnostics only for the line containing the comment.
      class Scanner
        DISABLE_RE = /\s*#\stypeprof:disable$/
        ENABLE_RE = /\s*#\stypeprof:enable$/

        def self.collect(prism_result, src)
          lines = src.lines
          comments_by_line = Hash.new { |h, k| h[k] = [] }

          prism_result.comments.each do |c|
            comments_by_line[c.location.start_line] << c.location.slice
          end

          ranges = []
          current_start = nil

          1.upto(lines.size) do |ln|
            comment_text = comments_by_line[ln].join(' ')
            line_text = lines[ln - 1]

            disable = (comment_text =~ DISABLE_RE) || (line_text =~ DISABLE_RE)
            enable = (comment_text =~ ENABLE_RE) || (line_text =~ ENABLE_RE)

            if current_start # Inside a disable comment block.
              if enable # Enable comment found.
                ranges << (current_start..ln - 1)
                if line_text.strip.start_with?('#') # Block-level enable comment found.
                  current_start = nil # Close the disable comment block.
                else
                  # Inline enable comment found.
                  # Exclude lines from the start of the disable comment block up to the current line.
                  current_start = ln + 1 # Start a new disable comment block on the next line.
                end
              end
            else
              # Outside a disable comment block.
              next unless disable

              if line_text.strip.start_with?('#') # Block-level disable comment found.
                current_start = ln + 1 # Disable comment block starts on the next line.
              else
                # Inline disable comment found.
                ranges << (ln..ln) # Exclude only the current line with inline disable.
              end
            end
          end

          # If a disable comment block was started but no matching enable comment was found,
          # exclude all lines from the start of the disable comment block to the end of the file.
          ranges << (current_start..Float::INFINITY) if current_start && current_start <= lines.size

          ranges
        end
      end
    end
  end
end
