require_relative 'role'
require_relative 'policy_defaults/defaults'


module Policy

  # Base policy class to be extended by all other policies, authorizes users based on roles they fall into,
  # return a uniquely merged hash of permitted attributes and associations of each role the @user has.
  #
  # @param user [Object] the user that initiated the action
  # @param record [Object] the object we're checking permissions of
  class Base
    extend Role

    include PolicyDefaults::Defaults

    role :guest, authorize_with: :user_guest

    attr_reader :user, :record

    def initialize(user, record)
      @user = user
      @record = record
    end

    # Is here
    def scope
      Pundit.authorize_scope!(user, record.class, fields)
    end

    # Retrieves the permitted roles for the current @query, checks if @user is one or more of these roles
    # and return a hash of attributes and associations that the @user has access to.
    #
    # @param query [Symbol, String] the predicate method to check on the policy (e.g. `:show?`)
    def resolve_query(query)
      permitted_roles = public_send(query)
      if permitted_roles.is_a? TrueClass or permitted_roles.is_a? FalseClass
        return permitted_roles
      end

      permissions_hash = self.class.permissions_hash

      # Always checks if the @user is a :guest first. :guest users cannot only have the one :guest role
      guest = self.class::Guest.new(self, permissions_hash[:guest])
      if guest.test_condition
        if permitted_roles.include? :guest
          return guest.permitted
        else
          return false
        end
      end

      current_roles = determine_current_roles(permitted_roles, permissions_hash)

      unless current_roles.present?
        return false
      end

      if current_roles.length == 1
        current_roles.values[0][:roles] = current_roles.keys[0]
        return current_roles.values[0]
      end

      return unique_merge(current_roles)
    end

    private

    # Build a hash of the roles that the user fulfills and the roles' attributes and associations,
    # based on the test_condition of the role.
    #
    # @param permitted_roles [Hash] roles returned by the query
    # @param permissions_hash [Hash] unrefined hash of options defined by all permitted_for methods
    def determine_current_roles(permitted_roles, permissions_hash)
      current_roles = {}

      permitted_roles.each do |permitted_role|
        if permitted_role == :guest
          next
        end

        begin
          current_role = {class: "#{self.class}::#{permitted_role.to_s.classify}".constantize}
          current_role_obj = current_role[:class].new(self, permissions_hash[permitted_role])
          if current_role_obj.test_condition
            current_roles[permitted_role] = current_role_obj.permitted
          end
        rescue NoMethodError =>e
          raise NoMethodError, "Could not find test condition, needs to be defined as 'test_condition?' and passed to the role as 'authorize_with: :test_condition' => #{e.message}"
        rescue NameError => e
          raise NameError, "#{current_role[:role]} not defined => #{e.message} "
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
        unless option.present?
          next
        end
        merged_hash[:roles] << role
        option.each do |type, actions|
          unless actions.present?
            next
          end
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
