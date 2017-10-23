module PolicyDefaults
  module Defaults
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

    # default authorization method
    def default_authorization?
      return false
    end

    # @authorize_with method for :guest role
    def user_guest?
      @user.nil?
    end

    # restricted attributes for show
    def restricted_show_attributes
      []
    end

    # restricted attributes for save
    def restricted_save_attributes
      [:id, :created_at, :updated_at]
    end

    # restricted attributes for create
    def restricted_create_attributes
      [:id, :created_at, :updated_at]
    end

    # restricted attributes for update
    def restricted_update_attributes
      [:id, :created_at, :updated_at]
    end

    # restricted associations for show
    def restricted_show_associations
      []
    end

    # restricted associations for save
    def restricted_save_associations
      []
    end

    # restricted associations for create
    def restricted_create_associations
      []
    end

    # restricted associations for update
    def restricted_update_associations
      []
    end
  end
end