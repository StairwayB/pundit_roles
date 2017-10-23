module Role
  attr_accessor :permissions_hash, :scope_hash
  @permissions_hash = {}
  @scope_hash = {}

  def role(role, opts)
    options = opts.slice(*_role_default_keys)

    raise ArgumentError, 'You need to supply at least one option' if options.empty?

    # There's something wrong here
    raise ArgumentError, 'You need to supply :authorize_with' if options.slice(*_required_attributes).empty?

    unless role.is_a? Symbol or role.is_a? String
      raise ArgumentError, "Expected Symbol or String for role, got #{role.class}"
    end

    create_role(role, self, options)
  end

  def create_role(role, permission, opts)
    begin
      permission.const_set role.to_s.classify, Class.new(Role::Base) {
        @authorize_with = "#{opts[:authorize_with]}?"
        @disable_merge = opts[:disable_merge]
      }
    rescue NameError
      raise ArgumentError, "Something went wrong, possible NameError with #{permission} or #{role}"
    end
  end

  def permitted_for(role, opts)
    options = opts.slice(*_permitted_for_keys)

    @permissions_hash = {} if @permissions_hash.nil?
    @permissions_hash[role] = options
  end

  def permitted_attr_for(role, attr)
    options = attr.slice(*_permitted_opt_for_keys)

    @permissions_hash = {} if @permissions_hash.nil?
    @permissions_hash[role] = {:attributes => options}
  end

  def permitted_assoc_for(role, assoc)
    options = assoc.slice(*_permitted_opt_for_keys)

    @permissions_hash = {} if @permissions_hash.nil?
    @permissions_hash[role] = {:associations => options}
  end

  private def _role_default_keys
    [:authorize_with, :extends, :disable_merge]
  end

  private def _required_attributes
    [:authorize_with]
  end

  private def _permitted_for_keys
    [:attributes, :associations]
  end

  private def _permitted_opt_for_keys
    [:show, :create, :update, :save]
  end

  class Base

    class << self
      attr_accessor :authorize_with, :disable_merge
    end

    @authorize_with = :default_authorization
    @disable_merge = nil

    attr_reader :permission

    def initialize(permission, permission_options)
      @permission = permission
      @permission_options = permission_options
      freeze
    end

    def authorize_with
      return self.class.authorize_with
    end

    def test_condition
      @permission.send(authorize_with)
    end

    def permitted
      if not @permission_options
        permitted =  {attributes: remove_restricted({}, 'attributes'),
                associations: remove_restricted({}, 'associations')}

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

    def remove_restricted(obj, type)
      permitted_obj_values = {}

      iterate_through = obj
      unless obj.present?
        iterate_through = _default_option_keys
      end

      iterate_through.each do |key, value|
        restricted = @permission.send("restricted_#{key}_#{type}")
        permitted_obj_values[key] = restricted.present? ? value - restricted : value
      end

      return permitted_obj_values
    end

    def get_all_attributes
      begin
        @permission.record.class.column_names.map(&:to_sym)
      rescue NoMethodError
        begin
          @permission.scope.column_names.map(&:to_sym)
        rescue NoMethodError
          raise NoMethodError, "#{@permission} does not have a record or scope defined(or scope is not an ActiveRecord::Association), this is a problem."
        end
      end
    end

    def get_all_associations
      begin
        @permission.record.class.reflect_on_all_associations.map(&:name)
      rescue NoMethodError
        begin
          @permission.scope.reflect_on_all_associations.map(&:name)
        rescue NoMethodError
          raise NoMethodError, "#{@permission} does not have a record or scope defined(or scope is not an ActiveRecord::Association), this is a problem."
        end
      end
    end

    def _allowed_access_options
      [:show_all, :save_all, :create_all, :update_all]
    end

    def _default_option_keys
      {show: [], create: [], update: [], save: []}
    end

    def _permitted_value_types(value)
      value.is_a? Symbol or value.is_a? Array
    end

  end

end
