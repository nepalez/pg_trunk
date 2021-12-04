# frozen_string_literal: true

class PGExtra::Operation
  # Build ruby snippet
  class RubyBuilder
    private def initialize(name, shortage: nil)
      @args = []
      @lines = []
      @name = name&.to_s
      @opts = []
      @shortage = shortage
    end

    # Add parameters to the method call
    def ruby_param(*args, **opts)
      @args = [*@args, *params(*args)]
      @opts = [*@opts, *params(**opts)]
    end

    # Add line into a block
    def ruby_line(meth, *args, **opts)
      return if meth.blank?
      return if args.first.nil?

      @lines << build_line(meth, *args, **opts)
    end

    # Build the snippet
    # @return [String]
    def build
      [header, *block].join(" ")
    end

    private

    # Pattern to split lines by heredocs
    HEREDOC = /<<~'?(?<head>[A-Z]+)'?.+(?<body>\n  .+)*\n\k<head>/.freeze

    def build_line(meth, *args, **opts)
      method_name = [shortage, meth].join(".")
      method_params = params(*args, **opts)
      line = [method_name, *method_params].join(" ")
      return single_line(line).indent(2) unless block_given?

      builder = self.class.new(line, shortage: "f")
      yield(builder)
      builder.build.indent(2)
    end

    # Finalize line containing a heredoc args
    #   "body <<~'SQL'.chomp\n  foo\nSQL, from: <<~'SQL'.chomp\n  bar\nSQL"
    #   "body <<~'SQL'.chomp, from: <<~'SQL'.chomp\n  foo\nSQL\n  bar\nSQL"
    def single_line(text)
      parts = text.partition(HEREDOC)
      (
        parts.map { |p| p[/^.+/] } + parts.map { |p| p[/\n(\n|.)*$/] }
      ).compact.join
    end

    def shortage
      @shortage ||= @name.split("_").last.first
    end

    def format(value)
      case value
      when Hash   then value
      when String then format_text(value)
      when Array  then format_list(value)
      else value.inspect
      end
    end

    def format_text(text)
      text = text.chomp
      # prevent quoting interpolations and heredocs
      return text if text[/^<<~|^%[A-Za-z][(]/]

      long_text = text.size > 50 || text.include?("\n")
      return "<<~'Q'.chomp\n#{text.indent(2)}\nQ" if long_text && text["\\"]
      return "<<~Q.chomp\n#{text.indent(2)}\nQ" if long_text
      return "%q(#{text})" if /\\|"/.match?(text)

      text.inspect
    end

    def format_list(list)
      case list.map(&:class).uniq
      when [::String] then "%w[#{list.join(' ')}]"
      when [::Symbol] then "%i[#{list.join(' ')}]"
      else list
      end
    end

    def params(*values, **options)
      vals = values.map { |val| format(val) }
      opts = options.compact.map { |key, val| "#{key}: #{format(val)}" }
      [*vals, *opts].join(", ").presence
    end

    def header
      method_params = [*@args, *@opts].join(", ").presence
      line = [@name, *method_params].join(" ")
      line << " do |#{shortage}|" if @lines.any?
      single_line(line)
    end

    def block
      [nil, *@lines, "end"].join("\n") if @lines.any?
    end
  end
end
