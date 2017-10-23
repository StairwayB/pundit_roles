require_relative 'role/base'

# Module which handles all class-level methods-and-instance variables. Add the ability for a class to define roles
# as dynamically generated classes and permitted options for those roles as class instance variables on the @policy.
#
# @param permission_hash [Hash] hash containing the unrefined attributes and association options
# @param scope_hash [Hash] unused as of yet
module Role
  attr_accessor :permissions_hash, :scope_hash
  @permissions_hash = {}
  @scope_hash = {}

  # Method to define a role with the opts used for those roles, checks if all is kosher and calls the the method
  # to create the role
  #
  # @param role [Symbol, String] the role name
  # @param opts [Hash] options for the role
  def role(role, opts)
    options = opts.slice(*_role_default_keys)

    raise ArgumentError, 'You need to supply :authorize_with' unless options.slice(*_required_attributes).present?

    unless role.is_a? Symbol or role.is_a? String
      raise ArgumentError, "Expected Symbol or String for role, got #{role.class}"
    end

    create_role(role, self, options)
  end

  # Dynamically generates a class with the options and sets the constant on the @policy
  #
  # @param role [Symbol, String] the name of the role
  # @param policy [Object] the reference to the policy to set the constant on, should be passed a 'self' reference
  # @param opts [Hash] options for the role
  def create_role(role, policy, opts)
    begin
      policy.const_set role.to_s.classify, Class.new(Role::Base) {
        @authorize_with = "#{opts[:authorize_with]}?"
        @disable_merge = opts[:disable_merge]
      }
    rescue NameError => e
      raise ArgumentError, "Something went wrong, possible NameError with #{policy} or #{role} => #{e.message}"
    end
  end

  # Saves the unrefined options into the @permission_hash class instance variable
  #
  # @param role [Symbol, String] the name of the role to which the opts are associated
  # @param opts [Hash] the hash of options
  def permitted_for(role, opts)
    options = opts.slice(*_permitted_for_keys)

    @permissions_hash = {} if @permissions_hash.nil?
    @permissions_hash[role] = options
  end

  # Helper method to declare attributes directly
  #
  # @param role [Symbol, String] the name of the role to which the opts are associated
  # @param attr [Hash] the hash of attributes
  def permitted_attr_for(role, attr)
    options = attr.slice(*_permitted_opt_for_keys)

    @permissions_hash = {} if @permissions_hash.nil?
    @permissions_hash[role] = {:attributes => options}
  end

  # Helper method to declare associations directly
  #
  # @param role [Symbol, String] the name of the role to which the opts are associated
  # @param assoc [Hash] the hash of associations
  def permitted_assoc_for(role, assoc)
    options = assoc.slice(*_permitted_opt_for_keys)

    @permissions_hash = {} if @permissions_hash.nil?
    @permissions_hash[role] = {:associations => options}
  end

  # default options for role declaration
  private def _role_default_keys
    [:authorize_with, :disable_merge]
  end

  # required options for role declaration
  private def _required_attributes
    [:authorize_with]
  end

  # permitted options for permitted_for declaration
  private def _permitted_for_keys
    [:attributes, :associations]
  end

  # permitted options for permitted_assoc_for and permitted_attr_for declaration
  private def _permitted_opt_for_keys
    [:show, :create, :update, :save]
  end

end
