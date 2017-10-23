require 'active_support/core_ext/hash/slice'
require 'active_support/core_ext/array/extract_options'
require 'active_support/core_ext/string/inflections'
require 'pry'

require_relative 'role/role'

module Policy
  class Base
    extend Role

    role :guest, authorize_with: :user_guest

    attr_reader :user, :record

    def initialize(user, record)
      @user = user
      @record = record
    end

    def index?
      false
    end

    def show?
      false
    end

    def create?
      false
    end

    def update?
      false
    end

    def destroy?
      false
    end

    def scope
      Pundit.authorize_scope!(user, record.class, fields)
    end

    def resolve_query(query)
      permitted_roles = public_send(query)
      if permitted_roles.is_a? TrueClass or permitted_roles.is_a? FalseClass
        return permitted_roles
      end

      permissions_hash = self.class.permissions_hash
      current_roles = {}

      guest = self.class::Guest.new(self, permissions_hash[:guest])

      if guest.test_condition
        if permitted_roles.include? :guest
          return guest.permitted
        else
          return false
        end
      end

      permitted_roles.each do |permitted_role|
        if permitted_role == :guest
          next
        end

        begin
          current_role = {role: permitted_role, class: "#{self.class}::#{permitted_role.to_s.classify}".constantize}
          current_role_obj = current_role[:class].new(self, permissions_hash[current_role[:role]])
          if current_role_obj.test_condition
            current_roles[current_role[:role]] = current_role_obj.permitted
          end
        rescue NameError, NoMethodError
          raise $!, "Something went wrong, #{current_role[:role]} possibly not defined, or maybe you forgot to define the test condition: it needs to be test_condition? and passed as test_condition, without the '?': #{$!}", $!.backtrace
        end
      end

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

    def unique_merge(roles)
      merged_hash = {attributes: {}, associations: {}, roles: []}

      roles.each do |role, option|
        unless option.present?
          next
        end
        merged_hash[:roles] << role
        option.each do |type, actions|
          raise ArgumentError, "Permitted keys can only be #{_permitted_keys}" unless _permitted_keys.include? type
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

    def allow(*roles)
      return roles
    end

    def default_authorization?
      return false
    end

    def user_guest?
      @user.nil?
    end

    def _permitted_keys
      [:attributes, :associations]
    end

    def restricted_show_attributes
      []
    end

    def restricted_save_attributes
      [:id, :created_at, :updated_at]
    end

    def restricted_create_attributes
      [:id, :created_at, :updated_at]
    end

    def restricted_update_attributes
      [:id, :created_at, :updated_at]
    end

    def restricted_show_associations
      []
    end

    def restricted_save_associations
      []
    end

    def restricted_create_associations
      []
    end

    def restricted_update_associations
      []
    end

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
