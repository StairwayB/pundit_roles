# Module containing the methods to authorize associations
module PunditAssociations

  # authorizes associations for the primary record
  #
  # @param opts [Hash]
  #   query: the method which returns the permissions,
  #     If omitted then this defaults to the Rails controller action name.
  #   associations: associations to authorize, defaults to []
  def authorize_associations!(opts = {query: nil, associations: []})
    raise ArgumentError, 'You must first call authorize!' unless @pundit_primary_permissions.present?

    opts[:query] ||= params[:action].to_s + '?'

    assoc_permissions = {show: [], create: [], update: [], }

    handle_associations(
      @pundit_primary_resource,
      opts[:associations],
      @pundit_primary_permissions,
      assoc_permissions,
      @formatted_attribute_lists
    )

    @formatted_attribute_lists[:show].merge!(association_show_attributes)
    @pundit_permitted_associations = assoc_permissions
  end

  private

  # @api private
  def handle_associations(record_class, requested_assoc, pundit_permission, assoc_opts={}, save_attributes={})

    permitted_actions = format_association_list(pundit_permission[:associations])
    requested_assoc.each_with_index do |assoc, index|
      raise ArgumentError, "Invalid association declaration, expected one of #{_valid_assoc_opts}, "+
        "got #{assoc} of class #{assoc.class}" unless _valid_assoc_opts.include? assoc.class

      if assoc.is_a? Symbol or assoc.is_a? String
        unless permitted_actions.keys.map(&:to_sym).include? assoc.to_sym
          next
        end

        assoc_constant = get_assoc_constant(record_class, assoc)
        fetch_assoc_policy(
          assoc_constant,
          assoc,
          pundit_permission[:roles][:for_associated_models][assoc],
          permitted_actions[assoc]
        )
        build_assoc_opts(assoc_opts, save_attributes, permitted_actions, assoc, false)

      elsif assoc.is_a? Hash
        assoc.each do |current_assoc, value|
          unless permitted_actions.keys.map(&:to_sym).include? current_assoc.to_sym
            next
          end

          assoc_constant = get_assoc_constant(record_class, current_assoc)

          fetch_assoc_policy(
            assoc_constant,
            current_assoc,
            pundit_permission[:roles][:for_associated_models][current_assoc],
            permitted_actions[current_assoc]
          )
          build_assoc_opts(assoc_opts, save_attributes,  permitted_actions, current_assoc, true)
          handle_associations(
            assoc_constant,
            value,
            @pundit_association_permissions[current_assoc],
            build_next_opts(assoc_opts, save_attributes,  current_assoc, index)
          )
        end
      end
    end
  end


  # @api private
  def build_assoc_opts(assoc_opts, save_attributes,  permitted_actions, assoc, is_hash)
    permitted_actions[assoc].each do |key|
      unless assoc_opts[key].nil?
        if is_hash
          assoc_opts[key] << {assoc => []}
        else
          assoc_opts[key] << assoc
        end

        if key != :show
          save_attributes[key] << {"#{assoc}_attributes".to_sym => @pundit_association_permissions[assoc][:attributes][key]}
        end
      end
    end
  end

  # @api private
  def build_next_opts(assoc_opts, save_attributes, assoc, assoc_index)
    next_opts = {}
    [:show, :create, :update].each do |type|
      next_opts[type] = assoc_opts[type][assoc_index].present? ? assoc_opts[type][assoc_index][assoc] : nil
    end

    [:create, :update].each do |type|
      next_opts[type] = save_attributes[type].is_a?(Hash) ? save_attributes[type].values.last : nil
    end

    return next_opts
  end

  # @api private
  def fetch_assoc_policy(assoc_constant, association, associated_roles, actions)
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

  # @api private
  def _valid_assoc_opts
    [Hash, String, Symbol]
  end
end