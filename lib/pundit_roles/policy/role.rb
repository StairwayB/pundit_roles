require_relative 'role/option_builder'

# Extended by Policy::Base. Defines the methods necessary for declaring roles.
module Role
  attr_accessor :permissions
  attr_accessor :role_associations
  attr_accessor :scopes

  # Builds a new role by saving it into the #permissions class instance variable
  # Valid options are :attributes, :associations, :scope, :uses_db, :extend
  #
  # @param *opts [Array] the roles, and the options which define the roles
  # @raise [ArgumentError] if the options are incorrectly defined, or no options are present
  def role(*opts)
    role_opts = opts.extract_options!.dup
    options = role_opts.slice(*_role_default_keys)

    raise ArgumentError, 'Please provide at least one role' unless opts.present?
    raise_if_options_are_invalid(options)

    @permissions = {} if @permissions.nil?
    @scopes = {} if @scopes.nil?
    @role_associations = {} if @role_associations.nil?

    opts.each do |role|
      raise ArgumentError, "Expected Symbol for #{role}, got #{role.class}" unless role.is_a? Symbol

      if options[:associated_as]
        determine_role_aliases(role, options[:associated_as])
      end

      @permissions[role] = OptionBuilder.new(self, options[:attributes], options[:associations],  options[:scope]).permitted
      @scopes[role] = options[:scope]
    end
  end

  # @api private
  private def determine_role_aliases(role, associated_as)
    if associated_as.is_a? Symbol
      return nil
    elsif associated_as.is_a? Array
      associated_as.each do |assoc|
        if assoc == :self
          @role_associations[role] = role
        else
          @role_associations[assoc] = role
        end
      end
    else
      raise ArgumentError, "'associated_as' must be either :self, :none or an Array of associated roles ([:logged_in_user, :post_owner]), got #{associated_as} instead"
    end
  end

  # @api private
  private def raise_if_options_are_invalid(options)
    options.each do |key, value|
      if value.present?
        expected = _role_option_validations[key]
        do_raise = true
        expected.each do |type|
          do_raise = false if value.is_a? type
        end
        raise ArgumentError, "Expected #{expected} for #{key}, got #{value.class}" if do_raise
      end
    end
  end

  # @api private
  private def _role_default_keys
    [:attributes, :associations, :associated_as, :scope]
  end

  # @api private
  private def _role_option_validations
    {attributes: [Hash, Symbol], associations: [Hash, Symbol], associated_as: [Array, Symbol], scope: [Proc]}
  end



end