# Contains the overwritten #authorize method
module PunditOverwrite

  # A modified version of Pundit's default authorization. Returns a hash of permitted attributes or raises exception
  # it the user is not authorized
  #
  # @param resource [Object] the object we're checking permissions of
  # @param query [Symbol, String] the predicate method to check on the policy (e.g. `:show?`).
  #   If omitted then this defaults to the Rails controller action name.
  # @raise [NotAuthorizedError] if the given query method returned false
  # @return [Object, Hash] Returns the permissions hash or the resource
  def authorize!(resource, query = nil)
    query ||= params[:action].to_s + '?'

    @_pundit_policy_authorized = true

    policy = policy(resource)
    permitted_records = policy.resolve_query(query)

    return determine_action(resource, query, policy, permitted_records)
  end

  # Returns the permitted scope or raises exception
  #
  # @param resource [Object] the object we're checking permissions of
  # @param query [Symbol, String] the predicate method to check on the policy (e.g. `:show?`).
  #   If omitted then this defaults to the Rails controller action name.
  # @raise [NotAuthorizedError] if the given query method returned false
  # @return [Object, ActiveRecord::Association] Returns the permissions hash or the resource
  def policy_scope!(resource, query = nil)
    query ||= params[:action].to_s + '?'

    @_pundit_policy_scoped = true

    policy = policy(resource)
    permitted_scope = policy.resolve_scope(query)

    return determine_action(resource, query, policy, permitted_scope)
  end

  private

  # @api private
  def determine_action(resource, query, policy, permitted)
    unless permitted
      raise Pundit::NotAuthorizedError, query: query, record: resource, policy: policy
    end

    if permitted.is_a? TrueClass
      return resource
    end

    return permitted
  end
end

# Prepends the PunditOverwrite to Pundit, in order to overwrite the default Pundit #authorize method
module Pundit
  prepend PunditOverwrite
end