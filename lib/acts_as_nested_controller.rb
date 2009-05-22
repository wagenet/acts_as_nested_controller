# See ActsAsNestedController::ActsMethods for documentation.
module ActsAsNestedController
  # Raised when a <tt>:after_find_parent</tt> returns +nil+ or +false+.
  # Allows us to stop controller action execution silently.
  class HaltExecution < Exception; end

  def self.included(base)
    base.extend ActsMethods
  end

  module ActsMethods

    # Specifies that the controller is available as both a nested and non-nested route
    #
    # The following private methods will be added for finding and building the child class:
    #
    # [find_child(*find_params)]
    #   Returns an array of <tt>[parent, child]</tt>. When <tt>params[:parent_id]</tt> is set, it finds the
    #   child in the parent's child association. Otherwise, it will find the child and then attempt to set the
    #   parent based upon the child's parent association. +parent+ will be +nil+ is this fails.
    #   <tt>find_params</tt> match <tt>ActiveRecord's find</tt>
    # [find_children(*find_params)]
    #   Returns an array of <tt>[parent, children]</tt>. When <tt>params[:parent_id]</tt> is set, it finds the
    #   parent and then finds the child in the parent's child association. If <tt>params[:parent_id]</tt> is not 
    #   present, then +parent+ will be +nil+.
    #   <tt>find_params</tt> match <tt>ActiveRecord's find</tt>
    # [new_child(*child_params)]
    #   Returns an array of <tt>[parent, child]</tt>. When <tt>parent[:parent_id]</tt> is set, it find the parent
    #   and then calls the build method on the child association. Otherwise, it initializes the child instance
    #   and then tries to set the parent from the child's parent association. +parent+ will be +nil+ is this fails.
    #
    # (+child+ and +children+ are replaced with the underscored versions of the specified <tt>:child_class</tt>.
    # This can be overridden by the <tt>:child_name</tt> option.)
    #
    # === Example
    #
    # A controller UsersController declares <tt>acts_as_nested_controller :parent_class => :account</tt>, which will
    # add:
    # * <tt>UsersController#find_user(*find_params)</tt> (similar to <tt>User.find(id)</tt>)
    # * <tt>UsersController#find_users(*find_params)</tt> (similar to <tt>User.find(:all)</tt>)
    # * <tt>UsersController#new_user(*child_params)</tt> (similar to <tt>User.new(attributes)</tt>)
    # The declaration also can take a variety of additional parameters to customize behavior
    #
    # === Options
    #
    # [:parent_class]
    #   Required.
    #   Specify the class that this controller is nested under.
    # [:find_in_association]
    #   By default the child find method will be called on the parent's <tt>:child_association</tt> where possible.
    #   Set to false if you want the child find method to always be called directly on <tt>:child_class</tt>.
    # [:singleton]
    #   By default we assume that <tt>:child_association</tt> is a +has_many+.
    #   Set to true if <tt>:child_association</tt> is +has_one+ instead.
    # [:child_class]
    #   Specify the class name of the child. Use it only if that name can't be inferred from the controller name.
    # [:child_name]
    #   Specify the name to be used for the generated methods.
    #   By default this is the underscored version of <tt>:child_class</tt>.
    # [:child_association]
    #   Specify the name of the parent's child association.
    #   By default this is assumed to be the underscored version of <tt>:child_class</tt>.
    #   NOTE: This value will be pluralized unless the <tt>:singleton</tt> is true.
    # [:parent_association]
    #   Specify the name of the child's parent association.
    #   By default this is the <tt>:parent_class</tt> underscored.
    # [:parent_finder]
    #   Specify a method, proc, or string (will be evaled) to be used for finding the parent instead of the default.
    #   If a method or proc, it will be called with <tt>(parent_class, *find_params)</tt>.
    # [:child_finder]
    #   Specify a method, proc, or string (will be evaled) to be used for finding the children instead of the default.
    #   If a method or proc, it will be called with <tt>(*find_params)</tt>.
    # [:child_builder]
    #   Specify a method, proc, or string (will be evaled) to be used for finding the children instead of the default.
    #   If a method or proc, it will be called with <tt>(parent, *child_params)</tt>.
    # [:find_parent_from_child]
    #   By default when <tt>params[:parent_id]</tt> is missing we load the child first and then attempt to load the
    #   parent by calling <tt>:parent_association</tt> on the child.
    #   Set this to fault to skip this attempt and instead try to find by <tt>:parent_id</tt>.
    # [:after_find_parent]
    #   Specify a method, proc, or string (will be evaled) to be called after a parent is found.
    #   If a method or proc, it will be called with <tt>(parent)</tt>.
    #   If +false+ or +nil+ is returned, controller execution will be halted.
    # [:force_after_find_parent]
    #   By default the <tt>:after_find_parent</tt> will not be called if no parent is found.
    #   Set this to true to call it anyway.
    #
    # Option examples:
    #   acts_as_nested_controller :parent_class => :account
    #   acts_as_nested_controller :parent_class => :account,
    #                               :after_find_parent => lambda{|account| account.allow_access_for(current_user) }
    #   acts_as_nested_controller :parent_class => :account, :child_class => :person
    #   acts_as_nested_controller :parent_class => :person, :child_class => :profile, :singleton => true,
    #                               :child_association => :public_profile
    def acts_as_nested_controller(options = {})
      cattr_accessor :nested_controller_config
      self.nested_controller_config = ActsAsNestedController::Configuration.new(self, options)

      # This hack prevents further execution if one of our callbacks returns false
      rescue_from ActsAsNestedController::HaltExecution, :with => lambda{ false }

      include InstanceMethods

      alias_method "find_#{nested_controller_config[:child_name]}",           :find_nested_child
      alias_method "find_#{nested_controller_config[:child_name].pluralize}", :find_nested_children
      alias_method "new_#{nested_controller_config[:child_name]}",            :new_nested_child
    end
  end

  module InstanceMethods

    private

      def nested_controller_config
        self.class.nested_controller_config
      end

      # TODO: Can we stop these from being passed on to the view?
      def nested_parent
        @nested_parent ||= ActsAsNestedController::NestedParent.new(self)
      end

      def nested_children
        @nested_children ||= ActsAsNestedController::NestedChildren.new(self)
      end

      def find_nested_child(*find_params)
        if nested_children.singleton? && nested_parent.param
          parent = nested_parent.find
          child = parent.send(nested_parent.child_association)
        else
          child = nested_children.find(*find_params)
          parent = nested_controller_config[:find_parent_from_child] ?
                      child.send(nested_children.parent_association) : (nested_parent.find rescue nil)
        end
        nested_parent.after_find(parent)
        return parent, child
      end

      def find_nested_children(*find_params)
        if nested_children.singleton? && nested_parent.param
          parent = nested_parent.find
          children = [parent.send(nested_parent.child_association)]
        else
          children = nested_children.find(*find_params)
          parent = nested_parent.param ? nested_parent.find : nil
        end
        nested_parent.after_find(parent)
        return parent, children
      end

      def new_nested_child(*child_params)
        if nested_parent.param
          parent = nested_parent.find
          child = nested_children.build(parent, *child_params)
        else
          child = nested_children.klass.new(*child_params)
          parent = nested_controller_config[:find_parent_from_child] ?
                      child.send(nested_children.parent_association) : (nested_parent.find rescue nil)
        end
        nested_parent.after_find(parent)
        return parent, child
      end

      def evaluate_method(method, *args)
        case method
          when Symbol
            send(method, *args)
          when String
            eval(method, args.first.instance_eval { binding })
          when Proc, Method
            instance_exec(*args, &method)
          else
            raise ArgumentError,
              "Callbacks must be a symbol denoting the method to call, a string to be evaluated, " +
              "or a block to be invoked."
          end
      end

  end
end
