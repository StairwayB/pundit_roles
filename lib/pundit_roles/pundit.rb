module PunditOverwrite

  # Overwrite for Pundit's default authorization, to be able to use PunditRoles. Does not conflict with existing
  # Pundit implementations
  #
  # @param record [Object] the object we're checking permissions of
  # @param query [Symbol, String] the predicate method to check on the policy (e.g. `:show?`).
  #   If omitted then this defaults to the Rails controller action name.
  # @raise [NotAuthorizedError] if the given query method returned false
  # @return [Object] Always returns the passed object record
  def authorize(record, query = nil)
    query ||= params[:action].to_s + '?'

    @_pundit_policy_authorized = true

    policy = policy(record)

    permitted_records = policy.resolve_query(query)

    unless permitted_records
      raise NotAuthorizedError, query: query, record: record, policy: policy
    end

    if permitted_records.is_a? TrueClass
      return record
    end

    return permitted_records
  end
end

module Pundit
  prepend PunditOverwrite
end