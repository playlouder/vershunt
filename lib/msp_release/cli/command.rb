module MSPRelease
  class CLI::Command

    module ClassMethods

      def cli_argument(name, description, options={})
        cli_arguments << {
          :name        => name,
          :description => description,
          :extra       => options,
          :required    => options.fetch(:required, true),
          :formatted   => options.fetch(:required, true) ? name.to_s.upcase :
            "[#{name.to_s.upcase}]"
        }
      end

      def cli_option(name, description, options={})
        cli_options << {
          :name        => name,
          :description => description,
          :extra       => options
        }
      end

      def command_name
        self.name.split("::").last.gsub(/(.)([A-Z])/, '\1_\2').downcase
      end

      def usage_line
        pp_args = cli_arguments.map {|arg_data| arg_data[:formatted] }
        "Usage: msp_release #{command_name} #{pp_args.join(' ')}"
      end

      def trollop_parser
        parser = Trollop::Parser.new
        parser.banner self.description

        if cli_arguments.size > 0
          parser.banner ""
          max_length = cli_arguments.map { |h| h[:name].to_s.length }.max
          cli_arguments.each do |argument_data|
            parser.banner("  " + argument_data[:name].to_s.rjust(max_length) + " - #{argument_data[:description]}")
          end
        end

        parser.banner ""
        cli_options.each do |option_data|
          parser.opt(option_data[:name], option_data[:description], option_data[:extra])
        end
        parser
      end

      def check_arguments(args)

        if args.size > cli_arguments.size
          $stderr.puts(usage_line)
          raise ExitException, "Too many arguments supplied to command #{command_name}"
        end

        cli_arguments.zip(args).map do |arg_data, arg_value|
          if arg_data[:required] && (arg_value.nil? || arg_value.empty?)
            $stderr.puts("Error: you must supply an argument for #{arg_data[:name]}")
            $stderr.puts(usage_line)
            raise ExitException, "Not enough arguments supplied to command #{command_name}"
          end
          {arg_data[:name] => arg_value}
        end.inject {|a,b| a.merge(b) }
      end

      private

      # kept private to prevent mutation
      def cli_options   ; @cli_options ||= []   ; end
      def cli_arguments ; @cli_arguments ||= [] ; end

    end

    class << self
      include ClassMethods
    end

    # Base class for command line operations
    include Exec::Helpers

    def initialize(options, arguments)
      @global_options = options
      parser = self.class.trollop_parser
      @options = parser.parse(arguments)
      @arguments = self.class.check_arguments(parser.leftovers)
    end

    attr_accessor :global_options, :options, :arguments

  end
end