module ActsAsNestedController
  # TODO: Refactor this into a more fully-featured class
  class Configuration # :nodoc:

    def initialize(controller, options)
      @options = options.dup
      @options.symbolize_keys!
      raise ArgumentError.new(":parent_class is required") unless @options.has_key?(:parent_class)

      @options.reverse_merge!(:child_class => controller.controller_name.singularize, :find_in_association => true, :singleton => false,
                              :force_after_find_parent => false, :find_parent_from_child => true)

      @options[:parent_class] = if @options[:parent_class].is_a?(Array)
        @options[:parent_class].inject({}) do |map, klass| 
          map.merge( "#{klass.to_s.underscore}_id".to_sym => klass.to_s.camelize.constantize )
        end
      else
        { "#{@options[:parent_class].to_s.underscore}_id".to_sym => @options[:parent_class].to_s.camelize.constantize }
      end

      @options[:parent_association] ||= @options[:parent_class].values.first.to_s.underscore.to_sym

      @options[:child_class] = @options[:child_class].to_s.camelize.constantize
      @options[:child_name] = @options[:child_name] || @options[:child_class].to_s.underscore

      @options[:child_association] = (@options[:child_association] || @options[:child_class]).to_s
      @options[:child_association] = @options[:child_association].pluralize unless @options[:singleton]
      @options[:child_association] = @options[:child_association].underscore.to_sym
    end

    def [](key)
      @options[key]
    end

  end
end