module ActsAsNestedController
  class NestedParent < ActsAsNestedController::NestedObject # :nodoc:

    def nested_children
      controller.send(:nested_children)
    end

    # If we only have one option, use it. Otherwise try to guess from params if available
    def param_name
      unless @param_name
        class_keys = config[:parent_class].keys
        @param_name = class_keys.size == 1 ? class_keys.first : class_keys.find{|k| !controller.params[k].nil? }
      end
      @param_name
    end

    def param
      controller.params[param_name] if param_name
    end

    def klass
      config[:parent_class][param_name] if param_name
    end

    def child_association
      config[:child_association]
    end

    def find(*find_params)
      find_params = [param] if find_params.empty?
      finder_method ? evaluate_method(finder_method, klass, *find_params) : finder_with_scopes(klass, find_params)
    end

    def after_find(parent)
      if parent || config[:force_after_find_parent]
        (after_find_method ? evaluate_method(after_find_method, parent) : true) || raise(ActsAsNestedController::HaltExecution)
      end
    end

    private

      # TODO: Set this up as a true callback
      def after_find_method
        config[:after_find_parent]
      end

      # TODO: Pass this in as a proc to initialize
      def finder_method
        config[:parent_finder]
      end

  end
end