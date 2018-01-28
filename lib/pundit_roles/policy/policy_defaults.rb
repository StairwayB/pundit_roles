# Defaults for Policy::Base
module PolicyDefaults
  # default index? method
  def index?
    false
  end

  # default show? method
  def show?
    false
  end

  # default create? method
  def create?
    false
  end

  # default update? method
  def update?
    false
  end

  # default destroy? method
  def destroy?
    false
  end

  # defaults to this when no associated_as roles have been provided. It is also merged to the provided roles
  DEFAULT_ASSOCIATED_ROLES = []

  # restricted attributes for show
  RESTRICTED_SHOW_ATTRIBUTES = []

  # restricted attributes for save
  RESTRICTED_SAVE_ATTRIBUTES = [:id, :created_at, :updated_at]

  # restricted attributes for create
  RESTRICTED_CREATE_ATTRIBUTES = [:id, :created_at, :updated_at]

  # restricted attributes for update
  RESTRICTED_UPDATE_ATTRIBUTES = [:id, :created_at, :updated_at]


  # restricted associations for show
  RESTRICTED_SHOW_ASSOCIATIONS = []

  # restricted associations for save
  RESTRICTED_SAVE_ASSOCIATIONS = []

  # restricted associations for create
  RESTRICTED_CREATE_ASSOCIATIONS = []

  # restricted associations for update
  RESTRICTED_UPDATE_ASSOCIATIONS = []
end
