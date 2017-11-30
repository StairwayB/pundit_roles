# Module containing selectors for various authorized attributes, can be accessed as, ex: permitted_show_attributes
module PunditSelectors

  # returns the permission hash for the primary model
  def permissions
    @pundit_primary_permissions
  end

  # returns the formatted attributes for :show, :create and :update, ready to plug-and-play
  def attribute_permissions
    @formatted_attribute_lists
  end

  # returns the permitted associations in the form of [Array] -> [{:posts => {:comments => [:author]}}, :settings]
  def permitted_associations
    @pundit_permitted_associations
  end

  # returns the permission hashes of permitted associations, ex: {:posts => {:attributes => {:show => [:text]}, :associations => {:show => [:comments]}}}
  def association_permissions
    @pundit_association_permissions
  end

  def permitted_show_attributes
    @formatted_attribute_lists[:show]
  end

  def permitted_create_attributes
    @formatted_attribute_lists[:create]
  end

  def permitted_update_attributes
    @formatted_attribute_lists[:update]
  end

  def permitted_show_associations
    @pundit_permitted_associations[:show]
  end

  def permitted_create_associations
    @pundit_permitted_associations[:create]
  end

  def permitted_update_associations
    @pundit_permitted_associations[:update]
  end

  # returns the permitted show attributes of the primary model
  def primary_show_attributes
    @pundit_primary_permissions[:attributes][:show]
  end

  # returns the permitted create attributes of the primary model
  def primary_create_attributes
    @pundit_primary_permissions[:attributes][:create]
  end

  # returns the permitted update attributes of the primary model
  def primary_update_attributes
    @pundit_primary_permissions[:attributes][:update]
  end

  # returns the permitted show associations of the primary model
  def primary_show_associations
    @pundit_primary_permissions[:associations][:show]
  end

  # returns the permitted create associations of the primary model
  def primary_create_associations
    @pundit_primary_permissions[:associations][:create]
  end

  # returns the permitted update associations of the primary model
  def primary_update_associations
    @pundit_primary_permissions[:associations][:update]
  end

  # returns the permitted show attributes of the associated models
  def association_show_attributes
    return {} unless @pundit_association_permissions
    associated_stuff = {}
    @pundit_association_permissions.each do |role, action|
      associated_stuff[role] = action[:attributes].slice(:show)[:show]
    end
    return associated_stuff
  end

  # returns the permitted create attributes of the associated models
  def association_create_attributes
    return {} unless @pundit_association_permissions
    associated_stuff = {}
    @pundit_association_permissions.each do |role, action|
      associated_stuff[role] = action[:attributes].slice(:create)[:create]
    end
    return associated_stuff
  end

  # returns the permitted update attributes of the associated models
  def association_update_attributes
    return {} unless @pundit_association_permissions
    associated_stuff = {}
    @pundit_association_permissions.each do |role, action|
      associated_stuff[role] = action[:attributes].slice(:update)[:update]
    end
    return associated_stuff
  end

  # returns the permitted show associations of the associated models
  def association_show_associations
    return {} unless @pundit_association_permissions
    associated_stuff = {}
    @pundit_association_permissions.each do |role, action|
      associated_stuff[role] = action[:associations].slice(:show)[:show]
    end
    return associated_stuff
  end

  # returns the permitted create associations of the associated models
  def association_create_associations
    return {} unless @pundit_association_permissions
    associated_stuff = {}
    @pundit_association_permissions.each do |role, action|
      associated_stuff[role] = action[:associations].slice(:create)[:create]
    end
    return associated_stuff
  end

  # returns the permitted update associations of the associated models
  def association_update_associations
    return {} unless @pundit_association_permissions
    associated_stuff = {}
    @pundit_association_permissions.each do |role, action|
      associated_stuff[role] = action[:associations].slice(:update)[:update]
    end
    return associated_stuff
  end
end