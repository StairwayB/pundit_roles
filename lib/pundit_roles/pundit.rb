module Pundit

  require 'action_controller/metal/exceptions'

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