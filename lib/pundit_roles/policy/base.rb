require_relative 'role'
require_relative 'policy_defaults'

# Namespace for aesthetic reasons
module Policy

  # Base policy class to be extended by all other policies, authorizes users based on roles they fall into,
  # return a uniquely merged hash of permitted attributes and associations of each role the @user has.
  #
  # @attr_reader user [Object] the user that initiated the action
  # @attr_reader record [Object] the object we're checking permissions of
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
      if permitted_roles.is_a? TrueClass or permitted_roles.is_a? FalseClass
        return permitted_roles
      end

      permissions_hash = self.class.permissions_hash

      # Always checks if user is a guest, and return the appropriate permission if true
      # the guest role cannot be merged with other roles
      if guest?
        return handle_guest_user(permitted_roles, permissions_hash)
      end
      current_roles = determine_current_roles(permitted_roles, permissions_hash)

      unless current_roles.present?
        return false
      end

      if current_roles.length == 1
        return current_roles.values[0].merge({roles: [current_roles.keys[0]]})
      end

      return unique_merge(current_roles)
    end

    private

    # Return the default :guest role if guest is present in @permitted_roles. Return false otherwise
    #
    # @param permitted_roles [Hash] roles returned by the query
    # @param permissions_hash [Hash] unrefined hash of options defined by all permitted_for methods
    def handle_guest_user(permitted_roles, permissions_hash)
      if permitted_roles.include? :guest
        return permissions_hash[:guest].merge({roles: [:guest]})
      end
      return false
    end

    # Build a hash of the roles that the user fulfills and the roles' attributes and associations,
    # based on the test_condition of the role.
    #
    # @param permitted_roles [Hash] roles returned by the query
    # @param permissions_hash [Hash] unrefined hash of options defined by all permitted_for methods
    def determine_current_roles(permitted_roles, permissions_hash)
      current_roles = {}

      permitted_roles.each do |permitted_role|
        if permitted_role == :guest or permitted_role == :guest_user
          next
        end

        begin
          if send("#{permitted_role}?")
            current_roles[permitted_role] = permissions_hash[permitted_role]
          end
        rescue NoMethodError => e
          raise NoMethodError, "Undefined test condition, it must be defined as 'role?', where, role is :#{permitted_role}, => #{e.message}"
        end
      end

      return current_roles
    end

    # Uniquely merge the options of all roles that the user fulfills
    #
    # @param roles [Hash] roles and options that the user fulfills
    def unique_merge(roles)
      merged_hash = {attributes: {}, associations: {}, roles: []}

      roles.each do |role, option|
        merged_hash[:roles] << role
        option.each do |type, actions|
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

    # Scope class from Pundit, to be used for limiting scopes. Unchanged from Pundit,
    # possible implementation forthcoming in a future update
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
