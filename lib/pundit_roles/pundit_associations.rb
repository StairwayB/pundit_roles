# Module containing the methods to authorize associations
module PunditAssociations
  private

  # authorizes associations for the primary record
  #
  # @param record_class [Class] the class of the record whose associations are being authorized
  # @param opts [Hash]
  # query: the method which returns the permissions,
  #     If omitted then this defaults to the Rails controller action name.
  #   associations: associations to authorize, defaults to []
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

  # @api private
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
  def get_assoc_constant(record_class, assoc)
    begin
      return assoc.to_s.classify.constantize
    rescue NameError
      assoc_aliases = record_class.reflect_on_all_associations.map{|ass| {ass.name => ass.class_name}}.reduce Hash.new, :merge
      if assoc_aliases.keys.include? assoc
        return assoc_aliases[assoc].constantize
      else
        raise NameError, "Could not find associated class #{assoc.to_s.classify}, and #{record_class}"+
          "does not include any associations named #{assoc}"
      end
    end
  end
end