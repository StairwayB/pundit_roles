require_relative 'spec_helper'

describe PunditRoles do
  describe 'pundit associations' do
    let(:current_user) { Base.new('current_user') } # Specify the current_user
    let(:regular_user) { AssociationPermission.new('regular_user') }
    let(:nested_user) { AssociationPermission.new('nested_user') }
    let(:aliased_user) {AssociationPermission.new('aliased_assoc')}
    let(:raises_role) {AssociationPermission.new('raises_role')}
    let(:raises_on_association_role) {AssociationPermission.new('raises_on_association_role')}

    it 'returns the associations and associated_as roles for the current_roles' do
      expect(authorize!(regular_user, query: :basic_assoc_validation?, associations: [:associated_permission]))
        .to eq({attributes: {show: %i(base)},
                associations: {show: [:associated_permission], create: [:associated_permission], update: [:associated_permission]},
                roles: {
                  for_current_model: [:regular_user],
                  for_associated_models: {:associated_permission => [:regular_user]}
                }
               })
    end

    it 'returns the permissions for associated models' do
      authorize!(regular_user, query: :basic_assoc_validation?, associations: [:associated_permission])
      expect(association_permissions)
        .to eq({
                 associated_permission: {
                   attributes: {show: %i(assoc)},
                   associations: {},
                    roles: {
                      for_current_model: [:regular_user],
                      for_associated_models: {}
                    }}
               }
        )
    end

    it 'correctly handles nested associations' do
      authorize!(nested_user, query: :nested_assoc_validation?, associations: [:associated_permission => [:nested_permission]])
      expect(association_permissions)
        .to eq(
              {
                associated_permission: {
                  attributes: {show: %i(assoc)},
                  :associations=>{show: [:nested_permission]},
                  roles: {
                    for_current_model: [:nested_user_one],
                    for_associated_models: {:nested_permission => [:regular_user]}
                  }
                },
                nested_permission: {
                  attributes: {show: %i(nested)},
                  associations: {},
                  roles: {
                    for_current_model: [:regular_user],
                    for_associated_models: {}
                  }
                }
              }
            )
    end

    it 'removes unauthorized associations from the show permissions for associated models' do
      authorize!(regular_user, query: :basic_assoc_validation?, associations: [:associated_permission, :not_authorized])
      expect(permitted_show_associations)
        .to eq(
              [:associated_permission]
            )
    end

    it 'removes unauthorized associations from the create permissions for associated models' do
      authorize!(regular_user, query: :basic_assoc_validation?, associations: [:associated_permission, :not_authorized])
      expect(permitted_create_associations)
        .to eq(
              [:associated_permission]
            )
    end

    it 'removes unauthorized associations from the update permissions for associated models' do
      authorize!(regular_user, query: :basic_assoc_validation?, associations: [:associated_permission, :not_authorized])
      expect(permitted_update_associations)
        .to eq(
              [:associated_permission]
            )
    end

    it 'removes unauthorized associations from the show permissions for nested associated models' do
      authorize!(
        regular_user,
        query: :basic_assoc_validation?,
        associations: [
          {:associated_permission => [:not_authorized, :still_not]},
          {:not_authorized => [:indeed_not]}
        ])
      expect(permitted_show_associations)
        .to eq(
              [{:associated_permission=>[]}]
            )
    end

    it 'removes unauthorized associations from the create permissions for nested associated models' do
      authorize!(
        regular_user,
        query: :basic_assoc_validation?,
        associations: [
          {:associated_permission => [:not_authorized, :still_not]},
          {:not_authorized => [:indeed_not]}
        ])
      expect(permitted_create_associations)
        .to eq(
              [{:associated_permission=>[]}]
            )
    end

    it 'removes unauthorized associations from the update permissions for nested associated models' do
      authorize!(
        regular_user,
        query: :basic_assoc_validation?,
        associations: [
          {:associated_permission => [:not_authorized, :still_not]},
          {:not_authorized => [:indeed_not]}
        ])
      expect(permitted_update_associations)
        .to eq(
              [{:associated_permission=>[]}]
            )
    end

    it 'correctly guesses associations from association alias' do
      authorize!(aliased_user, query: :aliased_validation?, associations: [:assoc])
      expect(permitted_associations)
        .to eq(
              {:show=>[:assoc], :create=>[], :update=>[]}
            )
      expect(association_permissions)
        .to eq({
                 assoc: {
                   attributes: {show: %i(assoc)},
                   :associations=>{show: [:nested_permission]},
                   roles: {
                     for_current_model: [:nested_user_two],
                     for_associated_models: {:nested_permission => [:regular_user, :other_user]}
                   }}
               }
            )
    end

    describe 'Default associated as roles' do
      let(:default_role_on_association) {DefaultRoleDeclaration.new('default_role_on_association')}
      let(:merged_default_and_provided_role) {DefaultRoleDeclaration.new('merged_default_and_provided_role')}

      it 'will default to the default role, when it is defined and no roles are provided' do
        authorize!(default_role_on_association, query: :default_role?, associations: [:default_role_associated])
        expect(association_permissions)
          .to eq({
                   default_role_associated: {
                     attributes: {show: %i(assoc_attribute)},
                     associations: {},
                     roles: {
                       for_current_model: [:default_associated_role],
                       for_associated_models: {}
                     }}
                 }
              )
      end

      it 'will merge the default and provided roles if both are present' do
        authorize!(merged_default_and_provided_role, query: :merge_default_and_provided?, associations: [:default_role_associated])
        expect(association_permissions)
          .to eq({
                   default_role_associated: {
                     attributes: {show:[:merged_attribute, :assoc_attribute]},
                     associations: {},
                     roles: {
                       for_current_model: [:merged_default_and_provided_role, :default_associated_role],
                       for_associated_models: {}
                     }}
                 }
              )
      end
    end

    it 'raises NameError, if association could not be found' do
      expect{authorize!(raises_role, query: :raises_name_error?, associations: [:doesnt_exist])}.to raise_error(NameError)
    end

    it 'raises ArgumentError, if invalid declaration found' do
      expect{authorize!(regular_user, query: :basic_assoc_validation?, associations: [1, 2])}.to raise_error(ArgumentError)
    end

    it 'raises NotAuthorizedError, if associated roles are not present, and Default role is not defined' do
      expect{authorize!(
        raises_on_association_role,
        query: :raises_on_association?,
        associations: [
          :associated_permission,
        ])}.to raise_error(Pundit::NotAuthorizedError)
    end

  end
end