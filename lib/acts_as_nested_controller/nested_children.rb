module ActsAsNestedController
  class NestedChildren < ActsAsNestedController::NestedObject # :nodoc:

    def nested_parent
      controller.send(:nested_parent)
    end

    def singleton?
      !!config[:singleton]
    end

    def find_in_association?
      !!config[:find_in_association]
    end

    def klass
      config[:child_class]
    end

    def parent_association
      config[:parent_association]
    end

    def base
      (find_in_association? && nested_parent.param) ? parent_children : klass
    end

    def find(*find_params)
      finder_method ? evaluate_method(finder_method, *find_params) : finder_with_scopes(base, find_params)
    end

    def build(parent, *child_params)
      if builder_method
        evaluate_method(builder_method, nested_parent, child_params)
      else
        if singleton?
          parent_children || nested_parent.find.send("build_#{nested_parent.child_association}", *child_params)
        else
          parent_children.build(*child_params)
        end
      end
    end

    private

      def parent_children
        nested_parent.find.send(nested_parent.child_association)
      end

      # TODO: Pass this in as a proc to initialize
      def finder_method
        config[:child_finder]
      end

      # TODO: Pass this in as a proc to initialize
      def builder_method
        config[:child_builder]
      end

  end
end