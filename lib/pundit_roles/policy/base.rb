require_relative 'role'
require_relative 'policy_defaults'

# Namespace for aesthetic reasons
module Policy

  # Base policy class to be extended by all other policies, authorizes users based on roles they fall into,
  # return a uniquely merged hash of permitted attributes and associations of each role the @user has.
  #
  # @attr_reader user [Object] the user that initiated the action
  # @attr_reader resource [Object] the object we're checking permissions of
  class Base
    extend Role
    include PolicyDefaults

    attr_reader :user, :resource
    def initialize(user, resource)
      @user = user
      @resource = resource
    end

    # Retrieves the permitted roles for the current query, checks if user is one or more of these roles
    # and return a hash of attributes and associations that the user has access to.
    #
    # @param query [Symbol, String] the predicate method to check on the policy (e.g. `:show?`)
    def resolve_query(query)
      permitted_roles = public_send(query)
      return permitted_roles if permitted_roles.is_a? TrueClass or permitted_roles.is_a? FalseClass

      validate_permission_type(permitted_roles, query)
      permissions = self.class.permissions

      if guest?
        return handle_guest_options(permitted_roles, permissions)
      end

      current_roles = determine_current_roles!(permitted_roles)
      return false unless current_roles.present?

      return options_or_merge(current_roles, permissions)
    end

    # Retrieves the permitted roles for the current query and checks each role, until it finds one that
    # that the user fulfills. It returns the defined scope for that role. Scopes do no merge with other scopes
    #
    # @param query [Symbol, String] the predicate method to check on the policy (e.g. `:show?`)
    def resolve_scope(query)
      permitted_roles = public_send(query)
      return permitted_roles if permitted_roles.is_a? TrueClass or permitted_roles.is_a? FalseClass

      validate_permission_type(permitted_roles, query)
      scopes = self.class.scopes

      if guest?
        return handle_guest_scope(permitted_roles, scopes)
      end

      current_roles =  determine_current_roles!(permitted_roles)
      return false unless current_roles.present?

      return instance_eval &scopes[current_roles[0]]
    end

    private

    # Return the default :guest role if guest is present in permitted_roles. Return false otherwise
    #
    # @param permitted_roles [Hash] roles returned by the query
    # @param permissions [Hash] unrefined hash of options defined by all permitted_for methods
    def handle_guest_options(permitted_roles, permissions)
      if permitted_roles.include? :guest
        return permissions[:guest].merge({roles: [:guest]})
      end
      return false
    end

    def handle_guest_scope(permitted_roles, scopes)
      if permitted_roles.include? :guest
        return instance_eval &scopes[:guest]
      end
      return false
    end

    # inspects the current_roles and returns the appropriate option
    #
    # @param current_roles [Hash] roles that the current user fulfills
    # @param permissions [Hash] unrefined hash of options defined by all permitted_for methods
    def options_or_merge(current_roles, permissions)
      return false unless current_roles.present?

      if current_roles.length == 1
        return permissions[current_roles[0]].merge({roles: [current_roles[0]]})
      end

      return unique_merge(current_roles, permissions)
    end

    # Build an Array of the roles that the user fulfills.
    #
    # @param permitted_roles [Hash] roles returned by the query
    def determine_current_roles!(permitted_roles)
      current_roles = []

      permitted_roles.each do |permitted_role|
        if permitted_role == :guest
          next
        end

        if test_condition?(permitted_role)
          current_roles << permitted_role
        end
      end

      return current_roles
    end

    # Uniquely merge the options of all roles that the user fulfills
    #
    # @param roles [Hash] roles that the user fulfills
    # @param permissions [Hash] the options for all roles
    def unique_merge(roles, permissions)
      merged_hash = {attributes: {}, associations: {}, roles: roles}

      roles.each do |role|
        permissions[role].each do |type, actions|
          actions.each do |key, value|
            unless merged_hash[type][key]
              merged_hash[type][key] = []
            end
            merged_hash[type][key] |= value
          end
        end
      end

      return merged_hash
    end

    # Helper method for testing the conditional of a role
    #
    # @param role [Symbol] the role to be tested
    # @raise [NoMethodError] if the test condition is undefined
    def test_condition?(role)
      begin
        if send("#{role}?")
          return true
        end
      rescue NoMethodError => e
        raise NoMethodError, "Undefined test condition, it must be defined as 'role?', where, role is :#{role}, => #{e.message}"
      end

      return false
    end

    # Helper method to be able to define allow: :guest, :user, etc. in the query methods
    #
    # @param *roles [Array] an array of permitted roles for a particular action
    def allow(*roles)
      return roles
    end

    # Default :guest role
    def guest?
      @user.nil?
    end

    # @api private
    def validate_permission_type(permitted_roles, query)
      valid = false
      _allowed_permission_types.each do |type|
        if permitted_roles.is_a? type
          valid = true
          break
        end
      end

      raise ArgumentError, "expected #{_allowed_permission_types} in #{query}, got #{permitted_roles.inspect}" unless valid
    end

    # @api private
    def _allowed_permission_types
      [Array, FalseClass, TrueClass]
    end

    # Scope class from Pundit, not used in this gem
    class Scope
      attr_reader :user, :scope

      def initialize(user, scope)
        @user = user
        @scope = scope
      end

      def resolve
        scope
      end

    end
  end
end
