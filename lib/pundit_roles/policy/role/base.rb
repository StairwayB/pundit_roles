module Role
  # Base class that all roles inherit, stores role options in class instance variables
  # and creates a hash of attributes and associations from the options defined in permitted_for methods
  #
  # @param authorize_with [Symbol, String] class instance attribute which stores the method that is used to
  # authorize users
  # @param disable_merge [TrueClass, FalseClass] unused as of yet
  # @param policy [Object] instance variable used to store a reference to the policy which instantiated the class
  # @param permission_options [Hash] unrefined hash of options to be refined by the permitted method
  class Base

    # Class instance variable accessors
    class << self
      attr_accessor :authorize_with, :disable_merge
    end

    @authorize_with = :default_authorization
    @disable_merge = nil

    attr_reader :policy

    def initialize(policy, permission_options)
      @policy = policy
      @permission_options = permission_options
      freeze
    end

    # Helper instance method to retrieve the class instance variable @authorize_with
    def authorize_with
      return self.class.authorize_with
    end

    # Send the method to the policy to check if user falls into this role
    def test_condition
      @policy.send(authorize_with)
    end

    # Returns a refined hash of attributes and associations this user has access to
    def permitted
      if not @permission_options
        permitted =  {attributes: {},
                      associations: {}}

      elsif @permission_options.is_a? Symbol
        permitted =  {attributes: handle_default_options(@permission_options, 'attributes'),
                      associations: handle_default_options(@permission_options, 'associations')}
      else
        permitted =  {attributes: init_options(@permission_options[:attributes], 'attributes'),
                      associations: init_options(@permission_options[:associations], 'associations')}
      end

      return permitted
    end

    private

    # Build hash of options when options are explicitly declared as a Hash
    #
    # @param options [Hash] unrefined hash containing either attributes or associations
    # @param type [String] the type of option to be built, can be 'attributes' or 'associations'
    def init_options(options, type)
      unless options.present?
        return {}
      end

      if options.is_a? Symbol
        return handle_default_options(options, type)
      end

      raise ArgumentError, "Permitted #{type}, if declared, must be declared as a Hash or Symbol, expected something along the lines of
                            {show: [:id, :name], create: [:name], update: :all} or :all, got #{options}" unless options.is_a? Hash

      parsed_options = {}
      options.each do |key, value|
        raise ArgumentError, "Expected Symbol or Array, for #{key} attribute, got #{value} of kind #{value.class}" unless _permitted_value_types value

        if value.is_a? Symbol and value == :all
          parsed_options[key] = send("get_all_#{type}")
          next
        end

        if value.is_a? Array
          case value.first
            when :all_minus
              parsed_options[key] = send("get_all_#{type}") - (value - [value.first])
            else
              parsed_options[key] = value
          end
          next
        end
      end

      return remove_restricted(parsed_options, type)
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
          parsed_options[:show] = send("get_all_#{type}")
        else
          of_type = option.to_s.gsub('_all', '').to_sym
          parsed_options[:show] = send("get_all_#{type}")
          parsed_options[of_type] = send("get_all_#{type}")
      end

      return remove_restricted(parsed_options, type)
    end

    # Remove restricted attributes declared in the @policy restricted_#{key}_#{type} methods,
    # ex: restricted_show_attributes
    #
    # @param obj [Hash] refined hash containing either attributes or associations
    # @param type [String] the type of option to be built, can be 'attributes' or 'associations'
    def remove_restricted(obj, type)
      permitted_obj_values = {}

      obj.each do |key, value|
        restricted = @policy.send("restricted_#{key}_#{type}")
        permitted_obj_values[key] = restricted.present? ? value - restricted : value
      end

      return permitted_obj_values
    end

    # Returns all attributes of a record or scope defined in the @policy
    def get_all_attributes
      begin
        @policy.record.class.column_names.map(&:to_sym)
      rescue NoMethodError
        begin
          @policy.scope.column_names.map(&:to_sym)
        rescue NoMethodError
          raise NoMethodError, "#{@policy} does not have a record or scope defined(or scope is not an ActiveRecord::Association), this is a problem."
        end
      end
    end

    # Returns all associations of a record or scope defined in the @policy
    def get_all_associations
      begin
        @policy.record.class.reflect_on_all_associations.map(&:name)
      rescue NoMethodError
        begin
          @policy.scope.reflect_on_all_associations.map(&:name)
        rescue NoMethodError
          raise NoMethodError, "#{@policy} does not have a record or scope defined(or scope is not an ActiveRecord::Association), this is a problem."
        end
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