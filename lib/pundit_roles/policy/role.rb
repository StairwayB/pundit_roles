require_relative 'role/option_builder'

# Extended by Policy::Base. Defines the methods necessary for declaring roles.
module Role

  attr_accessor :permissions
  attr_accessor :scopes

  # Builds a new role by saving it into the #permissions class instance variable
  # Valid options are :attributes, :associations, :scope, :uses_db, :extend
  #
  # @param *opts [Array] the roles, and the options which define the roles
  # @raise [ArgumentError] if the options are incorrectly defined, or no options are present
  def role(*opts)
    user_opts = opts.extract_options!.dup
    options = user_opts.slice(*_role_default_keys)

    raise ArgumentError, 'Please provide at least one role' unless opts.present?

    @permissions = {} if @permissions.nil?
    @scopes = {} if @scopes.nil?

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

    opts.each do |role|
      raise ArgumentError, "Expected Symbol for #{role}, got #{role.class}" unless role.is_a? Symbol
      @permissions[role] = OptionBuilder.new(self, options[:attributes], options[:associations],  options[:scope]).permitted
      @scopes[role] = options[:scope]
    end
  end

  # @api private
  private def _role_default_keys
    [:attributes, :associations, :scope, :uses_db, :extend]
  end

  # @api private
  private def _role_option_validations
    {attributes: [Hash, Symbol], associations: [Hash, Symbol], scope: [Proc], uses_db: [Symbol], extend: [Symbol]}
  end

end