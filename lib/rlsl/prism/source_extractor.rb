# frozen_string_literal: true

module RLSL
  module Prism
    class SourceExtractor
      class SourceNotAvailable < StandardError; end

      def extract(block)
        file, line_num = block.source_location
        raise SourceNotAvailable, "Block source location not available" unless file && File.exist?(file)

        lines = File.readlines(file)
        extract_block_source(lines, line_num - 1)
      end

      def extract_from_string(source)
        source
      end

      private

      def extract_block_source(lines, start_line)
        source = +""
        depth = 0
        in_block = false
        block_start_found = false

        lines[start_line..].each_with_index do |line, idx|
          tokens = tokenize_for_blocks(line)

          tokens.each do |token|
            case token
            when :do, :brace_open
              if !block_start_found
                block_start_found = true
                in_block = true
              end
              depth += 1
            when :block_start
              depth += 1
            when :end, :brace_close
              depth -= 1
            end
          end

          if block_start_found
            if idx == 0
              source << extract_first_line(line)
            else
              source << line
            end
          end

          break if in_block && depth == 0
        end

        clean_block_source(source)
      end

      def tokenize_for_blocks(line)
        tokens = []
        in_string = nil
        i = 0

        while i < line.length
          char = line[i]

          if in_string
            if char == in_string && (i == 0 || line[i - 1] != "\\")
              in_string = nil
            end
            i += 1
            next
          end

          if char == '"' || char == "'"
            in_string = char
            i += 1
            next
          end

          break if char == "#"

          prev_is_boundary = i == 0 || !line[i - 1].match?(/[a-zA-Z0-9_]/)

          if char == "{"
            tokens << :brace_open
          elsif char == "}"
            tokens << :brace_close
          elsif prev_is_boundary && line[i..].match?(/\Ado\b/)
            tokens << :do
            i += 1
          elsif prev_is_boundary && line[i..].match?(/\Aelsif\b/)
            i += 4
          elsif prev_is_boundary && line[i..].match?(/\Aelse\b/)
            i += 3
          elsif prev_is_boundary && (m = line[i..].match(/\A(if|unless|while|for|case|def|class|module)\b/))
            keyword = m[1]
            has_code_before = line[0...i].match?(/\S/)
            # Avoid counting modifier forms like "x = 1 if cond".
            unless has_code_before && %w[if unless while].include?(keyword)
              tokens << :block_start
            end
            i += keyword.length - 1
          elsif prev_is_boundary && line[i..].match?(/\Aend\b/)
            tokens << :end
            i += 2
          end

          i += 1
        end

        tokens
      end

      def extract_first_line(line)
        if line.include?(" do")
          match = line.match(/do\s*(\|[^|]*\|)?\s*(.*)$/)
          if match
            params = match[1] || ""
            rest = match[2] || ""
            "#{params}\n#{rest}\n"
          else
            "\n"
          end
        elsif line.include?("{")
          match = line.match(/\{\s*(\|[^|]*\|)?\s*(.*)$/)
          if match
            params = match[1] || ""
            rest = match[2] || ""
            "#{params}\n#{rest}\n"
          else
            "\n"
          end
        else
          line
        end
      end

      def clean_block_source(source)
        lines = source.lines
        return "" if lines.empty?

        last_line = lines.last.strip
        if last_line == "end" || last_line == "}"
          lines.pop
        elsif last_line.end_with?("end") || last_line.end_with?("}")
          lines[-1] = lines[-1].sub(/\s*(end|\})\s*$/, "\n")
        end

        lines.shift if lines.first&.strip&.empty?

        lines.join
      end
    end
  end
end
