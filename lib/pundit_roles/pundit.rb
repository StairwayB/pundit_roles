require 'pundit_roles/pundit_associations'
require 'pundit_roles/pundit_selectors'

# Contains the overwritten #authorize method
module PunditOverwrite
  include PunditAssociations
  include PunditSelectors

  # A modified version of Pundit's default authorization. Returns a hash of permitted attributes or raises exception
  # it the user is not authorized
  #
  # @param resource [Object] the object we're checking @permitted_attributes of
  # @param opts [Hash] options for scopes: query, associations
  #   query: the method which returns the permissions,
  #     If omitted then this defaults to the Rails controller action name.
  #   associations: associations to authorize, defaults to []
  # @raise [NotAuthorizedError] if the given query method returned false
  # @return [Object, Hash] Returns the @permitted_attributes hash or the resource
  def authorize!(resource, opts = {query: nil, associations: []})
    opts[:query] ||= params[:action].to_s + '?'

    @_pundit_policy_authorized = true

    @pundit_current_options = {
      primary_resource: resource.is_a?(Class) ? resource : resource.class,
      current_query: opts[:query]
    }

    policy = policy(resource)
    primary_permission = policy.resolve_query(opts[:query])

    unless primary_permission
      raise_not_authorized(resource)
    end

    if primary_permission.is_a? TrueClass
      return resource
    end

    @pundit_primary_permissions = primary_permission

    primary_resource_identifier = @pundit_current_options[:primary_resource].name.underscore.to_sym
    @pundit_attribute_lists = {
      show: {primary_resource_identifier => primary_show_attributes},
      create: [*primary_create_attributes],
      update: [*primary_update_attributes]
    }
    @pundit_permission_table = {}
    @pundit_permitted_associations = {show: [], create: [], update: []}

    if opts[:associations].present?
      authorize_associations!(opts)
    end

    return @pundit_primary_permissions
  end

  # Returns the permitted scope or raises exception
  #
  # @param resource [Object] the object we're checking @permitted_attributes of
  # @param opts [Hash] options for scopes: query, associations
  #   query: the method which returns the permissions,
  #     If omitted then this defaults to the Rails controller action name.
  #   associations: associations to scope, defaults to []
  # @raise [NotAuthorizedError] if the given query method returned false
  # @return [Object, ActiveRecord::Association] Returns the @permitted_attributes hash or the resource
  def policy_scope!(resource, opts= {query: nil, associations: []})
    opts[:query] ||= params[:action].to_s + '?'

    @_pundit_policy_scoped = true

    @pundit_current_options = {
      primary_resource: resource.is_a?(Class) ? resource : resource.class,
      current_query: opts[:query]
    }

    policy = policy(resource)
    permitted_scope = policy.resolve_scope(opts[:query])

    unless permitted_scope
      raise_not_authorized(resource)
    end

    if permitted_scope.is_a? TrueClass
      return resource
    end

    return permitted_scope
  end

  def raise_not_authorized(record)
    raise Pundit::NotAuthorizedError,
          query: @pundit_current_options[:current_query],
          record: record
  end

end

# Prepends the PunditOverwrite to Pundit, in order to overwrite the default Pundit #authorize method
module Pundit
  prepend PunditOverwrite
end