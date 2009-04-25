module ActsAsNestedController
  class NestedObject # :nodoc:

    attr_reader :controller

    def initialize(controller)
      @controller = controller
    end

    def config
      controller.nested_controller_config
    end

    private

      def finder_with_scopes(base, find_params)
        options = find_params.extract_options!
        options.symbolize_keys!

        base = [*options.delete(:scopes)].inject(base){|b, scope| b.send(scope) } if options[:scopes]

        find_params << options unless options.empty?

        base.find(*find_params)
      end

      def evaluate_method(method, *args)
        case method
          when Symbol
            controller.send(method, *args)
          when String
            eval(method, args.first.instance_eval { binding })
          when Proc, Method
            controller.instance_exec(*args, &method)
          else
            raise ArgumentError,
              "Callbacks must be a symbol denoting the method to call, a string to be evaluated, " +
              "or a block to be invoked."
          end
      end

  end
end