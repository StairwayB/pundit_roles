describe PunditRoles do
  describe 'pundit selectors' do
    let(:current_user) { Base.new('current_user') } # Specify the current_user
    let(:selector_helper_user) {AssociationPermission.new('selector_helper_user')}

    it '.permissions' do
      authorize!(selector_helper_user, query: :basic_assoc_validation?, associations: [:show])
      expect(permissions)
        .to eq({
                 attributes: {
                   show: [:show],
                   create: [:create],
                   update: [:update]
                 },
                 associations: {
                   show: [:show],
                   create: [:create],
                   update: [:update]
                 },
                 roles: {
                   for_current_model: [:selector_helper_user],
                   for_associated_models: {:show => [:test_helper], :create => [:test_helper], :update => [:test_helper]}
                 }
               }
            )
    end

    it '.attribute_permissions' do
      authorize!(selector_helper_user, query: :basic_assoc_validation?, associations: [:show, :create, :update])
      expect(attribute_permissions)
        .to eq({
                 show: {:association_permission=>[:show], :show=>[:show], :create=>nil, :update=>nil},
                 create: [:create, {:create_attributes=>[:create]}],
                 update: [:update, {:update_attributes=>[:update]}]
               }
            )
    end

    it '.permitted_associations' do
      authorize!(selector_helper_user, query: :basic_assoc_validation?, associations: [:show, :create, :update])
      expect(permitted_associations)
        .to eq(
              {:show=>[:show], :create=>[:create], :update=>[:update]}
            )
    end

    it '.association_permissions' do
      authorize!(selector_helper_user, query: :basic_assoc_validation?, associations: [:show])
      expect(association_permissions)
        .to eq({
                 show: {
                   attributes: {
                     show: [:show]
                   },
                   associations: {
                     show: [:show]
                   },
                   roles: {
                     for_current_model: [:test_helper],
                     for_associated_models: {}
                   }}
               }
            )
    end

    it '.permitted_show_attributes' do
      authorize!(selector_helper_user, query: :basic_assoc_validation?, associations: [:show])
      expect(permitted_show_attributes)
        .to eq(
              {:association_permission=>[:show], :show=>[:show]}
            )
    end

    it '.permitted_create_attributes' do
      authorize!(selector_helper_user, query: :basic_assoc_validation?, associations: [:create])
      expect(permitted_create_attributes)
        .to eq(
              [:create, {:create_attributes=>[:create]}]
            )
    end

    it '.permitted_update_attributes' do
      authorize!(selector_helper_user, query: :basic_assoc_validation?, associations: [:update])
      expect(permitted_update_attributes)
        .to eq(
              [:update, {:update_attributes=>[:update]}]
            )
    end

    it '.permitted_show_associations' do
      authorize!(selector_helper_user, query: :basic_assoc_validation?, associations: [:show])
      expect(permitted_show_associations)
        .to eq(
              [:show]
            )
    end

    it '.permitted_create_associations' do
      authorize!(selector_helper_user, query: :basic_assoc_validation?, associations: [:create])
      expect(permitted_create_associations)
        .to eq(
              [:create]
            )
    end

    it '.permitted_update_associations' do
      authorize!(selector_helper_user, query: :basic_assoc_validation?, associations: [:update])
      expect(permitted_update_associations)
        .to eq(
              [:update]
            )
    end

    it '.primary_show_attributes' do
      authorize!(selector_helper_user, query: :basic_assoc_validation?)
      expect(primary_show_attributes)
        .to eq(
              [:show]
            )
    end

    it '.primary_create_attributes' do
      authorize!(selector_helper_user, query: :basic_assoc_validation?)
      expect(primary_create_attributes)
        .to eq(
              [:create]
            )
    end

    it '.primary_update_attributes' do
      authorize!(selector_helper_user, query: :basic_assoc_validation?)
      expect(primary_update_attributes)
        .to eq(
              [:update]
            )
    end

    it '.primary_show_associations' do
      authorize!(selector_helper_user, query: :basic_assoc_validation?, associations: [:show])
      expect(primary_show_associations)
        .to eq(
              [:show]
            )
    end

    it '.primary_create_associations' do
      authorize!(selector_helper_user, query: :basic_assoc_validation?, associations: [:create])
      expect(primary_create_associations)
        .to eq(
              [:create]
            )
    end

    it '.primary_update_associations' do
      authorize!(selector_helper_user, query: :basic_assoc_validation?, associations: [:update])
      expect(primary_update_associations)
        .to eq(
              [:update]
            )
    end

    it '.association_show_attributes' do
      authorize!(selector_helper_user, query: :basic_assoc_validation?, associations: [:show])
      expect(association_show_attributes)
        .to eq({
                 :show => [:show]
               }
            )
    end

    it '.association_create_attributes' do
      authorize!(selector_helper_user, query: :basic_assoc_validation?, associations: [:create])
      expect(association_create_attributes)
        .to eq({
                 :create => [:create]
               }
            )
    end

    it '.association_update_attributes' do
      authorize!(selector_helper_user, query: :basic_assoc_validation?, associations: [:update])
      expect(association_update_attributes)
        .to eq({
                 :update => [:update]
               }
            )
    end

    it '.association_show_associations' do
      authorize!(selector_helper_user, query: :basic_assoc_validation?, associations: [:show])
      expect(association_show_associations)
        .to eq({
                 :show => [:show]
               }
            )
    end

    it '.association_create_associations' do
      authorize!(selector_helper_user, query: :basic_assoc_validation?, associations: [:create])
      expect(association_create_associations)
        .to eq({
                 :create => [:create]
               }
            )
    end

    it '.association_update_associations' do
      authorize!(selector_helper_user, query: :basic_assoc_validation?, associations: [:update])
      expect(association_update_associations)
        .to eq({
                 :update => [:update]
               }
            )
    end

  end
end