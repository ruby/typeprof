module TypeProf::LSP
  class Text
    def initialize(path, text, version)
      @path = path
      @text = text
      @version = version
    end

    attr_reader :path, :text, :version

    def apply_changes(changes, version)
      lines = @text.empty? ? [] : @text.lines

      changes.each do |change|
        change => {
          range: {
              start: { line: start_row, character: start_col },
              end:   { line: end_row  , character: end_col   }
          },
          text: new_text,
        }

        lines << "" if start_row == lines.size
        lines << "" if end_row == lines.size

        if start_row == end_row
          lines[start_row][start_col...end_col] = new_text
        else
          lines[start_row][start_col..] = ""
          lines[end_row][...end_col] = ""
          new_text = new_text.lines
          if new_text.size <= 1
            new_text = new_text.first || ""
            lines[start_row .. end_row] = [lines[start_row] + new_text + lines[end_row]]
          else
            lines[start_row] = lines[start_row] + new_text.shift
            lines[end_row] = new_text.pop + lines[end_row]
            lines[start_row + 1 .. end_row - 1] = new_text
          end
        end
      end

      @text = lines.join
      @version = version
    end
  end
end