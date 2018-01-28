module Role
  # Helper class, which handles building of a role's #permissions_hash.
  #
  # @param policy [Class] the class used to store a reference to the policy which instantiated this
  # @param attr_opts [Hash, :Symbol] the requested options for attributes to be refined by the permitted method
  # @param assoc_opts [Hash, :Symbol] the requested options for associations to be refined by the permitted method
  # @param scope [String] the scope for the role in String format

  class OptionBuilder

    attr_reader :policy

    def initialize(policy, attr_opts, assoc_opts, scope)
      @policy = policy
      @attr_opts = attr_opts
      @assoc_opts = assoc_opts
      @scope = scope
      freeze
    end

    # Returns a refined hash of attributes and associations the current_user has access to
    def permitted
      return {
        attributes: permitted_options(@attr_opts, 'attributes'),
        associations: permitted_options(@assoc_opts, 'associations')
      }
    end

    private

    # Determines the the kind of method used to declare the option
    #
    # @param *opts [Hash] the hash of attributes or associations for the role
    # @param type [String] the kind of option, can be 'attributes' or 'associations'
    def permitted_options(opts, type)
      if not opts
        permitted =  {}

      elsif opts.is_a? Symbol
        permitted =  handle_default_options(opts, type)
      else
        permitted =  init_options(opts, type)
      end

      return permitted
    end

    # Build hash of options when options are explicitly declared as a Hash
    #
    # @param options [Hash] unrefined hash containing either attributes or associations
    # @param type [String] the type of option to be built, can be 'attributes' or 'associations'
    def init_options(options, type)
      raise ArgumentError, "Permitted #{type}, if declared, must be declared as a Hash or Symbol, expected something along the lines of
                            {show: [:id, :name], create: [:name], update: :all} or :all, got #{options}" unless options.is_a? Hash

      parsed_options = {}
      options.each do |key, value|
        raise ArgumentError, "Expected Symbol or Array, for #{key} attribute, got #{value} of kind #{value.class}" unless _permitted_value_types value

        if key == :save
          actions = [:create, :update]
        else
          actions = [key]
        end

        if value.is_a? Symbol and value == :all
          actions.each do |action|
            parsed_options[action] = remove_restricted(action, type)
          end
          next
        end

        if value.is_a? Array
          actions.each do |action|
            parsed_options[action] = [] unless parsed_options[action].present?
            parsed_options[action] |= value
          end
          next
        end

      end

      return parsed_options
    end

    # Build hash of options when options are implicitly declared as a Symbol, ex: :show_all
    #
    # @param option [Symbol] unrefined hash containing either attributes or associations
    # @param type [String] the type of option to be built, can be 'attributes' or 'associations'
    def handle_default_options(option, type)
      raise ArgumentError, "Permitted options for implicit permission declaration are #{_allowed_access_options},
                            got #{option} instead" unless _allowed_access_options.include? option
      parsed_options = {}
      case option
        when :show_all
          parsed_options[:show] = remove_restricted(:show, type)
        when :save_all
          [:show, :create, :update].each do |action|
            parsed_options[action] = remove_restricted(action, type)
          end
        else
          option_type = option.to_s.gsub('_all', '').to_sym
          [:show, option_type].each do |action|
            parsed_options[action] = remove_restricted(action, type)
          end
      end

      return parsed_options
    end

    # Remove restricted attributes declared in the #policy RESTRICTED_#{key}_#{type} constants
    #
    # @param action [Hash] the action we're fetch the restricted options for
    # @param type [String] the type of option to be built, can be 'attributes' or 'associations'
    def remove_restricted(action, type)
      all_attributes = get_all(type)
      restricted = "#{@policy}::RESTRICTED_#{action.upcase}_#{type.upcase}".constantize

      return restricted.present? ? all_attributes - restricted : all_attributes
    end

    # Returns all attributes of a record or scope defined in the #policy
    def get_all_attributes
      @policy.to_s.gsub('Policy', '').constantize.column_names.map(&:to_sym)
    end

    # Returns all associations of a record or scope defined in the #policy
    def get_all_associations
      @policy.to_s.gsub('Policy', '').constantize.reflect_on_all_associations.map(&:name)
    end

    def get_all(type)
      begin
        send("get_all_#{type}")
      rescue NameError => e
        raise ArgumentError, "#{@policy} does not seem to have a corresponding model: "+
          "#{@policy.to_s.gsub('Policy', '')}, implicit declarations are not allowed => #{e.message}"
      end
    end

    # allowed options for implicit declaration
    def _allowed_access_options
      [:show_all, :save_all, :create_all, :update_all]
    end

    # allowed options for explicit declaration
    def _permitted_value_types(value)
      value.is_a? Symbol or value.is_a? Array
    end

  end
end