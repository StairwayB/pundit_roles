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

    @pundit_association_permissions = {}
    handle_associations(
      record_class,
      opts[:associations],
      @pundit_permissions
    )

    @pundit_permitted_associations = opts[:associations]
  end

  def handle_associations(record_class, requested_assoc, pundit_permission)
    permitted_actions = format_association_list(pundit_permission[:associations])

    # enumerator should not point to the same Array as requested_assoc, since that needs to be deleted from
    request_enumerator = Array.new(requested_assoc)
    request_enumerator.each do |assoc|
      if assoc.is_a? Symbol
        unless permitted_actions.keys.include? assoc
          requested_assoc.delete(assoc)
          next
        end

        assoc_constant = get_assoc_constant(record_class, assoc)
        get_assoc_policy(
          assoc_constant,
          assoc,
          pundit_permission[:roles][:for_associated_models][assoc],
          permitted_actions[assoc]
        )

      elsif assoc.is_a? Hash
        raise ArgumentError, 'there can be only one key for each nested association,'+
          "ex: {posts: [:comments, :likes]}, got #{assoc} instead, with #{assoc.keys.length} keys" if assoc.keys.length > 1
        unless permitted_actions.keys.include? assoc.keys.first
          requested_assoc.delete(assoc)
          next
        end
        assoc_constant = get_assoc_constant(record_class, assoc.keys.first)
        get_assoc_policy(
          assoc_constant,
          assoc.keys.first,
          pundit_permission[:roles][:for_associated_models][assoc.keys.first],
          permitted_actions[assoc.keys.first]
        )
        handle_associations(
          assoc_constant,
          assoc.values.first,
          @pundit_association_permissions[assoc.keys.first],
        )
      end
    end
  end

  # @api private
  def get_assoc_policy(assoc_constant, association, associated_roles, actions)
    assoc_policy = policy(assoc_constant)
    assoc_permission = assoc_policy.resolve_as_association(associated_roles, actions)

    unless assoc_permission
      raise Pundit::NotAuthorizedError, query: params[:action], record: assoc_constant, policy: assoc_policy
    end

    @pundit_association_permissions[association] = assoc_permission
  end

  # @api private
  def format_association_list(assoc)
    permitted_actions = {}
    assoc.each do |key, associations|
      associations.each do |ass|
        permitted_actions[ass] = [] unless permitted_actions[ass].present?
        permitted_actions[ass] |= [key]
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
      assoc_aliases = record_class.reflect_on_all_associations.map{|ass| {ass.name => ass.class_name}}.reduce Hash.new, :merge
      require 'pry'
      binding.pry
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
    return {} unless @pundit_association_permissions
    associated_stuff = {}
    @pundit_association_permissions.each do |role, action|
      associated_stuff[role] = action[:attributes].slice(:show)[:show]
    end
    return associated_stuff
  end

  # @api private
  def associated_create_attributes
    return {} unless @pundit_association_permissions
    associated_stuff = {}
    @pundit_association_permissions.each do |role, action|
      associated_stuff[role] = action[:attributes].slice(:create)[:create]
    end
    return associated_stuff
  end

  # @api private
  def associated_update_attributes
    return {} unless @pundit_association_permissions
    associated_stuff = {}
    @pundit_association_permissions.each do |role, action|
      associated_stuff[role] = action[:attributes].slice(:update)[:update]
    end
    return associated_stuff
  end

  # @api private
  def associated_save_attributes
    return {} unless @pundit_association_permissions
    associated_stuff = {}
    @pundit_association_permissions.each do |role, action|
      associated_stuff[role] = action[:attributes].slice(:save)[:save]
    end
    return associated_stuff
  end

  def permitted_associations
    @pundit_permitted_associations
  end

end

# Prepends the PunditOverwrite to Pundit, in order to overwrite the default Pundit #authorize method
module Pundit
  prepend PunditOverwrite
end