module TypeProf::LSP
  class Text
    def initialize(server, path, text, version)
      @server = server
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
          text: change_text,
        }

        lines << "" if start_row == lines.size
        lines << "" if end_row == lines.size

        if start_row == end_row
          lines[start_row][start_col...end_col] = change_text
        else
          lines[start_row][start_col..] = ""
          lines[end_row][...end_col] = ""
          change_text = change_text.lines
          if change_text.size <= 1
            change_text = change_text.first || ""
            lines[start_row .. end_row] = [lines[start_row] + change_text + lines[end_row]]
          else
            lines[start_row] = lines[start_row] + changed_text.shift
            lines[end_row] = changed_text.pop + lines[end_row]
            lines[start_row + 1 .. end_row - 1] = changed_text
          end
        end
      end

      @text = lines.join
      @version = version
    end
  end
end