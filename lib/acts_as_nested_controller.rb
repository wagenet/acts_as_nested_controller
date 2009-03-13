module ActsAsNestedController
  class HaltExecution < Exception; end
  class ActsAsNestedControllerError < StandardError; end
  
  def self.included(base)
    base.class_eval do
      extend ClassMethods
    end
  end
  
  module ClassMethods
    def acts_as_nested_controller(options)      
      cattr_accessor :nested_controller_options
      
      rescue_from ActsAsNestedController::HaltExecution, :with => :execution_halted
      
      options.reverse_merge!(:child_class => controller_name.singularize, :find_in_association => true, :singleton => false,
                              :force_after_find_parent => true)
      
      options[:parent_class] = if options[:parent_class].is_a?(Array)
        options[:parent_class].inject({}) do |map, klass| 
          map.merge( "#{klass.to_s.underscore}_id".to_sym => klass.to_s.camelize.constantize )
        end
      else
        { "#{options[:parent_class].to_s.underscore}_id".to_sym => options[:parent_class].to_s.camelize.constantize }
      end
        
      options[:parent_association] ||= options[:parent_class].values.first.to_s.underscore.to_sym
        
      options[:child_class] = options[:child_class].to_s.camelize.constantize
      options[:child_name] = options[:child_name] || options[:child_class].to_s.underscore
      
      options[:child_association] = (options[:child_association] || options[:child_class]).to_s
      options[:child_association] = options[:child_association].pluralize unless options[:singleton]
      options[:child_association] = options[:child_association].underscore.to_sym

      self.nested_controller_options = options
      
      include ActsMethods
    end
    
  end
  
  module ActsMethods
    def self.included(base)
      base.class_eval do
        define_method "find_#{nested_controller_options[:child_name]}", instance_method(:find_nested_child) 
        define_method "find_#{nested_controller_options[:child_name].pluralize}", instance_method(:find_nested_children)
        define_method "new_#{nested_controller_options[:child_name]}", instance_method(:new_nested_child)
      end
    end
    
    private

      def nested_controller_options
        self.class.nested_controller_options
      end
    
      # If we only have one option, use it. Otherwise try to guess from params if available
      def nested_parent_param_name
        @nested_parent_param_name ||= nested_controller_options[:parent_class].keys.size == 1 ?
                                        nested_controller_options[:parent_class].keys.first :
                                        nested_controller_options[:parent_class].keys.find{|k| !params[k].nil? }
      end
    
      def nested_parent_param
        params[nested_parent_param_name] if nested_parent_param_name
      end
    
      def nested_parent_class
        nested_controller_options[:parent_class][nested_parent_param_name] if nested_parent_param_name
      end
    
      def nested_parent
        nested_parent_finder(nested_parent_param)
      end

      def after_find_nested_parent(parent)
        res = nested_controller_options[:after_find_parent] ? 
                evaluate_method(nested_controller_options[:after_find_parent], parent) : true
        raise HaltExecution unless res
        res
      end
    
      def nested_parent_finder(*find_params)
        if nested_controller_options[:parent_finder]
          evaluate_method(nested_controller_options[:parent_finder], nested_parent_class, *find_params)
        else
          finder_with_scopes(nested_parent_class, find_params)
        end
      end
    
      def nested_child_finder(*find_params)
        if nested_controller_options[:child_finder]
          evaluate_method(nested_controller_options[:child_finder], *find_params)
        else
          finder_with_scopes(nested_base, find_params)
        end
      end
    
      def nested_child_builder(parent, *child_params)
        if nested_controller_options[:child_builder]
          evaluate_method(nested_controller_options[:child_builder], parent, child_params)
        else
          if nested_controller_options[:singleton]
            parent.send(nested_controller_options[:child_association]).nil? ?
              parent.send("build_#{nested_controller_options[:child_association]}", *child_params) :
              parent.send(nested_controller_options[:child_association])
          else
            parent.send(nested_controller_options[:child_association]).build(*child_params)
          end
        end
      end
    
      def nested_base
        nested_parent_param && nested_controller_options[:find_in_association] ? 
          nested_parent.send(nested_controller_options[:child_association]) : 
          nested_controller_options[:child_class]
      end
    
      def find_nested_child(*find_params)
        if nested_controller_options[:singleton] && nested_parent_param
          parent = nested_parent
          child = parent.send(nested_controller_options[:child_association])
        else
          child = nested_child_finder(*find_params)
          parent = child.send(nested_controller_options[:parent_association])
        end
        after_find_nested_parent(parent)
        return parent, child
      end
  
      def find_nested_children(*find_params)
        if nested_controller_options[:singleton] && nested_parent_param
          parent = nested_parent
          children = [parent.send(nested_controller_options[:child_association])]
        else
          children = nested_child_finder(*find_params)
          parent = nested_parent_param ? nested_parent : nil
        end
        after_find_nested_parent(parent) if parent || nested_controller_options[:force_after_find_parent]
        return parent, children
      end
  
      def new_nested_child(*child_params)
        if nested_parent_param
          parent = nested_parent
          child = nested_child_builder(parent, *child_params)
        else
          child = nested_controller_options[:child_class].new(*child_params)
          parent = child.send(nested_controller_options[:parent_association])
        end
        after_find_nested_parent(parent) if parent || nested_controller_options[:force_after_find_parent]
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
      
      def finder_with_scopes(base, find_params)
        options = find_params.extract_options!
        options.symbolize_keys!
        
        base = [*options.delete(:scopes)].inject(base){|b, scope| b.send(scope) } if options[:scopes]
        
        find_params << options unless options.empty?
        
        base.find(*find_params)
      end
      
      # Stub
      def execution_halted
        false
      end
  end
end
