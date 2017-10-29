# Contains the overwritten #authorize method
module PunditOverwrite

  # Overwrite for Pundit's default authorization, to be able to use PunditRoles. Does not conflict with existing
  # Pundit implementations
  #
  # @param resource [Object] the object we're checking permissions of
  # @param query [Symbol, String] the predicate method to check on the policy (e.g. `:show?`).
  #   If omitted then this defaults to the Rails controller action name.
  # @raise [NotAuthorizedError] if the given query method returned false
  # @return [Object, Hash] Returns the permissions hash or the record
  def authorize(resource, query = nil)
    query ||= params[:action].to_s + '?'

    @_pundit_policy_authorized = true

    policy = policy(resource)

    permitted_records = policy.resolve_query(query)

    unless permitted_records
      raise Pundit::NotAuthorizedError, query: query, record: resource, policy: policy
    end

    if permitted_records.is_a? TrueClass
      return resource
    end

    return permitted_records
  end
end

# Prepends the PunditOverwrite to Pundit, in order to overwrite the default Pundit #authorize method
module Pundit
  prepend PunditOverwrite
end