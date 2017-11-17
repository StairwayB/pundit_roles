# Contains the overwritten #authorize method
module PunditOverwrite

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

    policy = policy(resource)
    @pundit_permissions = policy.resolve_query(opts[:query])

    unless @pundit_permissions
      raise Pundit::NotAuthorizedError, query: opts[:query], record: resource, policy: policy
    end

    if opts[:associations]
      authorize_associations!(resource.class, opts)
    end

    return @pundit_permissions
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

    policy = policy(resource)
    permitted_scope = policy.resolve_scope(opts[:query])

    unless permitted_scope
      raise Pundit::NotAuthorizedError, query: opts[:query], record: resource, policy: policy
    end

    if permitted_scope.is_a? TrueClass
      return resource
    end

    return permitted_scope
  end

  private

  # @api private
  def authorize_associations!(record_class, opts = {query: nil, associations: []})
    raise ArgumentError, 'You must first call authorize!' unless @pundit_permissions.present?

    opts[:query] ||= params[:action].to_s + '?'

    @permitted_associations = {}

    handle_associations(
      record_class,
      opts[:associations],
      @pundit_permissions[:associations],
      @pundit_permissions[],
      @pundit_permissions[],
      opts[:query])
  end

  def handl_associations(record_class, requested_assoc, pundit_permission, query)
    permitted_actions = format_association_list(pundit_permission[:associations])
    requested_assoc.each do |assoc|
      assoc_constant = get_assoc_constant(record_class, assoc)

      if assoc.is_a? Symbol
        next unless permitted_actions.keys.include? assoc
        get_assoc_policy(assoc_constant, assoc, associated_roles, query, permitted_actions[assoc].to_a)
        next
      end

      if assoc.is_a? Hash
        raise ArgumentError, 'there can be only one key for each nested association,'+
          "ex: {posts: [:comments, :likes]}, got #{assoc} instead, with #{assoc.keys.length} keys" if assoc.keys.length > 1
        next unless permitted_actions.keys.include? assoc.keys.first

        get_assoc_policy(assoc_constant, assoc.keys.first, associated_roles, query, permitted_actions[assoc.keys.first].to_a)
        handl_associations(assoc_constant, assoc.values.first, @permitted_associations[assoc.keys.first][:associations], query)
      end
    end
  end

  # @api private
  def handle_associations(record_class, requested_assoc, permitted_assoc, current_roles, role_associations, query)
    permitted_actions = format_association_list(permitted_assoc)
    requested_assoc.each do |assoc|
      assoc_constant = get_assoc_constant(record_class, assoc)
      associated_roles = build_association_roles(current_roles, role_associations, association)
      if assoc.is_a? Symbol
        next unless permitted_actions.keys.include? assoc
        get_assoc_policy(assoc_constant, assoc, associated_roles, query, permitted_actions[assoc].to_a)
        next
      end

      if assoc.is_a? Hash
        raise ArgumentError, 'there can be only one key for each nested association,'+
          "ex: {posts: [:comments, :likes]}, got #{assoc} instead, with #{assoc.keys.length} keys" if assoc.keys.length > 1
        next unless permitted_actions.keys.include? assoc.keys.first

        get_assoc_policy(assoc_constant, assoc.keys.first, associated_roles, query, permitted_actions[assoc.keys.first].to_a)
        handle_associations(assoc_constant, assoc.values.first, @permitted_associations[assoc.keys.first][:associations], query)
      end
    end
  end

  # @api private
  def get_assoc_policy(assoc_constant, association, associated_roles, query, actions)
    assoc_policy = policy(assoc_constant)
    assoc_permission = assoc_policy.resolve_as_association(associated_roles, actions)

    unless assoc_permission
      raise Pundit::NotAuthorizedError, query: query, record: assoc_constant, policy: assoc_policy
    end

    if assoc_permission.is_a? TrueClass
      @permitted_associations[association] = {attributes: {}, associations: {}, roles: {}}
      return assoc_constant
    end

    @permitted_associations[association] = assoc_permission

    return assoc_constant
  end

  # @api private
  def format_association_list(assoc)
    permitted_actions = {}
    assoc.each do |key, associations|
      associations.each do |ass|
        permitted_actions[ass] = Set.new unless permitted_actions[ass].present?
        permitted_actions[ass].add(key)
      end
    end

    return permitted_actions
  end

  # @api private
  def build_association_roles(current_roles, role_associations, association)
    associated_roles = []
    current_roles.each do |role|
      associated_roles |= role_associations[role][association]
    end
    return associated_roles
  end

  # @api private
  def get_assoc_constant(record_class, assoc)
    begin
      return assoc.to_s.classify.constantize
    rescue NameError
      assoc_aliases = record_class.reflect_on_all_associations.map{|ass| {ass.name => ass.class_name}}
      if assoc_aliases.keys.include? assoc
        return assoc.constantize
      else
        raise NameError, "Could not find associated class #{assoc.to_s.classify}, and #{record_class}"+
          "does not include any associations named #{assoc}"
      end
    end
  end

  # @api private
  def permitted
    @pundit_permissions
  end

  # @api private
  def show_attributes
    @pundit_permissions[:attributes][:show]
  end

  # @api private
  def create_attributes
    @pundit_permissions[:attributes][:create]
  end

  # @api private
  def update_attributes
    @pundit_permissions[:attributes][:update]
  end

  # @api private
  def save_attributes
    @pundit_permissions[:attributes][:save]
  end

  # @api private
  def show_associations
    @pundit_permissions[:associations][:show]
  end

  # @api private
  def create_associations
    @pundit_permissions[:associations][:create]
  end

  # @api private
  def update_associations
    @pundit_permissions[:associations][:update]
  end

  # @api private
  def save_associations
    @pundit_permissions[:associations][:save]
  end

  # @api private
  def associated_show_attributes
    return {} unless @permitted_associations
    associated_stuff = {}
    @permitted_associations.each do |role, action|
      associated_stuff[role] = action[:attributes].slice(:show)[:show]
    end
    return associated_stuff
  end

  # @api private
  def associated_create_attributes
    return {} unless @permitted_associations
    associated_stuff = {}
    @permitted_associations.each do |role, action|
      associated_stuff[role] = action[:attributes].slice(:create)[:create]
    end
    return associated_stuff
  end

  # @api private
  def associated_update_attributes
    return {} unless @permitted_associations
    associated_stuff = {}
    @permitted_associations.each do |role, action|
      associated_stuff[role] = action[:attributes].slice(:update)[:update]
    end
    return associated_stuff
  end

  # @api private
  def associated_save_attributes
    return {} unless @permitted_associations
    associated_stuff = {}
    @permitted_associations.each do |role, action|
      associated_stuff[role] = action[:attributes].slice(:save)[:save]
    end
    return associated_stuff
  end

end

# Prepends the PunditOverwrite to Pundit, in order to overwrite the default Pundit #authorize method
module Pundit
  prepend PunditOverwrite
end