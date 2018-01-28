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

    @pundit_requested_associations = Array.new(opts[:associations])
    @pundit_allowed_associations = []

    handle_associations(
      @pundit_current_options[:primary_resource],
      @pundit_requested_associations,
      @pundit_primary_permissions,
      @pundit_allowed_associations
    )

    [:show, :create, :update].each do |type|
      determine_permitted_associations(
        @pundit_allowed_associations,
        @pundit_primary_permissions,
        @pundit_permitted_associations[type],
        type
      )
    end

    @pundit_attribute_lists[:show].merge!(association_show_attributes)

    [:create, :update].each do |type|
      determine_save_permissions(
        @pundit_permitted_associations[type],
        @pundit_attribute_lists[type],
        type
      )
    end
  end

  private

  # @api private
  def handle_associations(record_class, requested_assoc, pundit_permission, permitted_assoc)
    permitted_actions = format_association_list(pundit_permission[:associations])

    requested_assoc.each do |assoc|
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
        permitted_assoc << assoc

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
          permitted_assoc << {current_assoc => []}
          handle_associations(
            assoc_constant,
            value,
            @pundit_permission_table[current_assoc],
            permitted_assoc.last[current_assoc]
          )
        end
      else
        raise ArgumentError, "Invalid association parameter, expected one of #{_valid_assoc_opts}, "+
          "got #{assoc} of class #{assoc.class}"
      end
    end
  end

  # @api private
  def fetch_assoc_policy(assoc_constant, association, associated_roles, actions)
    assoc_policy = policy(assoc_constant)
    assoc_permission = assoc_policy.resolve_as_association(associated_roles, actions)

    unless assoc_permission
      raise_not_authorized(assoc_constant)
    end

    @pundit_permission_table[association] = assoc_permission
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
  def determine_permitted_associations(requested_assoc, pundit_permission, permitted_opts, type)
    permitted_actions = pundit_permission[:associations][type]

    requested_assoc.each do |assoc|
      if assoc.is_a? Symbol or assoc.is_a? String
        if permitted_actions and permitted_actions.include? assoc
          permitted_opts << assoc
        end
      elsif assoc.is_a? Hash
        assoc.each do |current_assoc, value|
          if permitted_actions and permitted_actions.include? current_assoc
            permitted_opts << {current_assoc => []}

            determine_permitted_associations(
              value,
              @pundit_permission_table[current_assoc],
              permitted_opts.last[current_assoc],
              type
            )
          end
        end
      end
    end
  end

  # @api private
  def determine_save_permissions(permitted_assoc, save_attributes, type)
    permitted_assoc.each do |assoc|
      if assoc.is_a? Symbol or assoc.is_a? String
        assoc_sym = "#{assoc}_attributes".to_sym
        save_attributes << {assoc_sym => @pundit_permission_table[assoc][:attributes][type]}
      elsif assoc.is_a? Hash
        assoc.each do |current_assoc, value|
          assoc_sym = "#{current_assoc}_attributes".to_sym
          save_attributes << {assoc_sym => @pundit_permission_table[current_assoc][:attributes][type]}

          determine_save_permissions(
            value,
            save_attributes.last[assoc_sym],
            type
          )
        end
      end
    end
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