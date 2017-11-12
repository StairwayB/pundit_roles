require_relative 'spec_helper'

describe PunditRoles do

  describe '.authorize!' do
    let(:current_user) { User.new(1) } # Specify that current_user is is User with id 1
    let(:regular_user) { User.new(153) }
    let(:correct_user) { User.new(1) }

    it 'returns a hash of options if user is permitted' do
      expect(authorize!(regular_user, query: :allow_regular?)).to be_a(Hash)
    end

    it 'raises exception if the action is not permitted' do
      expect{authorize!(regular_user, query: :allow_no_one?)}.to raise_error(Pundit::NotAuthorizedError)
    end

    it 'raises exception if the current_user is not allowed for the action' do
      expect {authorize!(regular_user, query: :allow_only_correct?) }.to raise_error(Pundit::NotAuthorizedError)
    end

    it 'allows current_user if it satisfies the conditional' do
      expect(authorize!(correct_user, query: :allow_only_correct?)).to be_a(Hash)
    end

    it 'expects Pundit default to work as intended' do
      expect(authorize!(regular_user, query: :pundit_default?)).to be_truthy
    end

    it 'raises exception if the test condition is undefined' do
      expect {authorize!(regular_user, query: :raises_no_method?) }.to raise_error(NoMethodError)
    end

  end

  describe 'guest role' do
    let(:current_user) { nil } # Specify that current_user is guest
    let(:regular_user) { User.new(153) }
    let(:scoped_user) { ScopedUser.new(2) }

    it 'returns the guest role, if guest is permitted' do
      expect(authorize!(regular_user, query: :allow_guest?)).to be_a(Hash)
    end

    it 'raises exception if user is guest, but guest is not permitted' do
      expect{authorize!(regular_user, query: :allow_regular?)}.to raise_error(Pundit::NotAuthorizedError)
    end

    it 'returns only the guest attributes, when user is a guest' do
      expect(authorize!(
               regular_user,
               query: :allow_guest?)
      )
        .to eq({attributes: {show: %i(username name),
                             create: %i(username name email phone_number password)},
                associations: {},
                roles: [:guest]
               })
    end

    it 'returns the scope if guest is permitted and user is guest' do
      expect(policy_scope!(scoped_user, query: :allows_guest?)).to eq :guest_user
    end

    it 'raises exception if user is guest, and guest is not allowed' do
      expect{policy_scope!(scoped_user, query: :doesnt_allow_guest?)}.to raise_error(Pundit::NotAuthorizedError)
    end

  end

  describe 'authorize associations' do
    let(:current_user) { AssociationPermission.new(1) }
    let(:regular_user) { AssociationPermission.new(2) }
    let(:nested_user) { AssociationPermission.new(3) }
    let(:aliased_user) {AssociationPermission.new(4)}

    it 'returns the associations and associated_as roles for the current_roles' do
      expect(authorize!(
               regular_user,
               query: :basic_assoc_validation?,
               associations: [:associated_permission])
      )
        .to eq({attributes: {show: %i(base)},
                associations: {show: %i(associated_permission)},
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
                   :associations=>{},
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
                  :associations=>{},
                  roles: {
                    for_current_model: [:regular_user],
                    for_associated_models: {}
                  }
                }
              }
            )
    end

    it 'removes unauthorized associations from the permissions for associated models' do
      authorize!(regular_user, query: :basic_assoc_validation?, associations: [:associated_permission, :not_authorized])
      expect(permitted_associations)
        .to eq(
              [:associated_permission]
            )
    end

    it 'removes unauthorized associations from the permissions for nested associated models' do
      authorize!(
        regular_user,
        query: :basic_assoc_validation?,
        associations: [
          {:associated_permission => [:not_authorized, :still_not]},
          {:not_authorized => [:indeed_not]}
        ])
      expect(permitted_associations)
        .to eq(
              [{:associated_permission=>[]}]
            )
    end

    it 'correctly guesses associations from association alias' do
      authorize!(aliased_user, query: :aliased_validation?, associations: [:assoc])
      expect(permitted_associations)
        .to eq(
              [:assoc]
            )

      # # attributes: {show: [:assoc]},
      # associations: {show: [:nested_permission]},
      #   associated_as: {:nested_permission => [:regular_user, :other_user]}

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

  end

  describe 'explicit declarations' do
    let(:current_user) { User.new(1) }  # Specify that current_user is is User with id 1
    let(:regular_user) { User.new(153) }
    let(:correct_user) { User.new(1) }

    it 'returns the permitted options correctly, specifying the fulfilled roles' do
      expect(authorize!(
               regular_user,
               query: :can_have_merged_roles?)
      )
        .to eq({attributes: {show: %i(username name created_at)},
                associations: {show: %i(posts followers following)},
                roles: {
                  for_current_model: [:logged_in_user],
                  for_associated_models: {}
                }
               })
    end

    it 'returns the permitted options, uniquely merging them when the current_user fulfils multiple roles' do
      expect(authorize!(
               correct_user,
               query: :can_have_merged_roles?)
      )
        .to eq({attributes: {show: %i(username name created_at email phone_number updated_at),
                            update: %i(username email password current_password name)},
               associations: {show: %i(posts followers following settings),
                              save: %i(settings)},
               roles: {
                 for_current_model: [:logged_in_user, :correct_user],
                 for_associated_models: {}
               }
              })
    end

  end

  describe 'implicit_declarations' do
    let(:current_user) { User.new(1) }  # Specify that current_user is is User with id 1
    let(:regular_user) { ImplicitUser.new(153) }
    let(:correct_user) { ImplicitUser.new(1) }
    let(:restricted_user) {RestrictedUser.new(2)}

    it 'correctly guesses the options, when declaring with {opt}_all' do
      expect(authorize!(
               regular_user,
               query: :implicit_declaration?)
      )
        .to eq({:attributes=>{:show=>[:column], :save=>[:column]},
                :associations=>{:show=>[:assoc]},
                roles: {
                  for_current_model: [:regular_user],
                  for_associated_models: {}
                }})
    end

    it 'correctly guesses the options, when declaring with :all and :all_minus' do
      expect(authorize!(
               correct_user,
               query: :implicit_option_declaration?)
      )
        .to eq({:attributes=>{:show=>[:column], :create=>[]},
                :associations=>{},
                roles: {
                  for_current_model: [:correct_user],
                  for_associated_models: {}
                }})
    end

    it 'removes the restricted attributes' do
      expect(authorize!(
               restricted_user,
               query: :remove_restricted?)
      )
        .to eq({:attributes=>{:show=>[:column]},
                :associations=>{},
                roles: {
                  for_current_model: [:regular_user],
                  for_associated_models: {}
                }})
    end

  end

  describe 'scopes' do
    let(:current_user) { User.new(1) }  # Specify that current_user is is User with id 1
    let(:regular_user) { ScopedUser.new(2) }
    let(:some_user) { ScopedUser.new(3) }
    let(:not_allowed_user) {ScopedUser.new(4)}

    it 'returns the scope when true' do
      expect(policy_scope!(regular_user, query: :boolean_permission?)).to eq regular_user
    end

    it 'returns the scope of the first role that the user fulfills' do
      expect(policy_scope!(regular_user, query: :index?)).to eq [:returns, :many, :things]
    end

    it 'raises Pundit::NotAuthorizedError if the user is not allowed ' do
      expect{policy_scope!(not_allowed_user, query: :index?)}.to raise_error(Pundit::NotAuthorizedError)
    end

    it 'allows the getting the permissions as well as scopes from a method' do
      expect(policy_scope!(some_user, query: :index?)).to eq :some_user
      expect(authorize!(
               some_user,
               query: :index?)
      )
        .to eq({:attributes=>{:show=>[:username, :email]},
                :associations=>{},
                roles: {
                  for_current_model: [:some_role, :some_extra_role],
                  for_associated_models: {}
                }})
    end
  end

  describe 'defaults' do
    let(:current_user) { User.new(1) }  # Specify that current_user is is User with id 1
    let(:regular_user) { User.new(153) }
    let(:correct_user) { User.new(1) }

    it 'returns false by default for index?' do
      expect{authorize!(regular_user, query: :index?)}.to raise_error(Pundit::NotAuthorizedError)
    end

    it 'returns false by default for show?' do
      expect{authorize!(regular_user, query: :show?)}.to raise_error(Pundit::NotAuthorizedError)
    end

    it 'returns false by default for create?' do
      expect{authorize!(regular_user, query: :create?)}.to raise_error(Pundit::NotAuthorizedError)
    end

    it 'returns false by default for update' do
      expect{authorize!(regular_user, query: :update?)}.to raise_error(Pundit::NotAuthorizedError)
    end

    it 'returns false by default for destroy' do
      expect{authorize!(regular_user, query: :destroy?)}.to raise_error(Pundit::NotAuthorizedError)
    end

    it 'allows providing a new set of restricted attributes, without overwriting parent' do
      expect(RestrictedUserPolicy::RESTRICTED_SHOW_ATTRIBUTES).to eq([:remove_this])
      expect(Policy::Base::RESTRICTED_SHOW_ATTRIBUTES).to eq([])
    end

    it 'allows allows adding to the restricted attributes, without overwriting parent' do
      expect(RestrictedUserPolicy::RESTRICTED_CREATE_ATTRIBUTES).to eq([:id, :created_at, :updated_at, :extra])
      expect(Policy::Base::RESTRICTED_CREATE_ATTRIBUTES).to eq([:id, :created_at, :updated_at])
    end
  end

  describe 'selector helpers' do
    let(:current_user) { AssociationPermission.new(1) }
    let(:test_helper) {AssociationPermission.new(5)}

    it '.permissions' do
      authorize!(test_helper, query: :basic_assoc_validation?, associations: [:show])
      expect(permissions)
        .to eq({
                 attributes: {
                   show: [:show],
                   create: [:create],
                   update: [:update],
                   save: [:save]
                 },
                 associations: {
                   show: [:show],
                   create: [:create],
                   update: [:update],
                   save: [:save]
                 },
                 roles: {
                   for_current_model: [:test_helper],
                   for_associated_models: {:show => [:test_helper], :create => [:test_helper], :update => [:test_helper], :save => [:test_helper]}
                 }
               }
            )
    end

    it '.permitted_associations' do
      authorize!(test_helper, query: :basic_assoc_validation?, associations: [:show])
      expect(permitted_associations)
        .to eq(
              [:show]
            )
    end

    it '.association_permissions' do
      authorize!(test_helper, query: :basic_assoc_validation?, associations: [:show])
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
      authorize!(test_helper, query: :basic_assoc_validation?, associations: [:show])
      expect(permitted_show_attributes)
        .to eq(
              [:show]
            )
    end

    it '.permitted_create_attributes' do
      authorize!(test_helper, query: :basic_assoc_validation?, associations: [:create])
      expect(permitted_create_attributes)
        .to eq(
              [:create]
            )
    end

    it '.permitted_update_attributes' do
      authorize!(test_helper, query: :basic_assoc_validation?, associations: [:update])
      expect(permitted_update_attributes)
        .to eq(
              [:update]
            )
    end

    it '.permitted_save_attributes' do
      authorize!(test_helper, query: :basic_assoc_validation?, associations: [:save])
      expect(permitted_save_attributes)
        .to eq(
              [:save]
            )
    end

    it '.permitted_show_associations' do
      authorize!(test_helper, query: :basic_assoc_validation?, associations: [:show])
      expect(permitted_show_associations)
        .to eq(
              [:show]
            )
    end

    it '.permitted_create_associations' do
      authorize!(test_helper, query: :basic_assoc_validation?, associations: [:create])
      expect(permitted_create_associations)
        .to eq(
              [:create]
            )
    end

    it '.permitted_update_associations' do
      authorize!(test_helper, query: :basic_assoc_validation?, associations: [:update])
      expect(permitted_update_associations)
        .to eq(
              [:update]
            )
    end

    it '.permitted_save_associations' do
      authorize!(test_helper, query: :basic_assoc_validation?, associations: [:save])
      expect(permitted_save_associations)
        .to eq(
              [:save]
            )
    end

    it '.association_show_attributes' do
      authorize!(test_helper, query: :basic_assoc_validation?, associations: [:show])
      expect(association_show_attributes)
        .to eq({
                 :show => [:show]
               }
            )
    end

    it '.association_create_attributes' do
      authorize!(test_helper, query: :basic_assoc_validation?, associations: [:create])
      expect(association_create_attributes)
        .to eq({
                 :create => [:create]
               }
            )
    end

    it '.association_update_attributes' do
      authorize!(test_helper, query: :basic_assoc_validation?, associations: [:update])
      expect(association_update_attributes)
        .to eq({
                 :update => [:update]
               }
            )
    end

    it '.association_save_attributes' do
      authorize!(test_helper, query: :basic_assoc_validation?, associations: [:save])
      expect(association_save_attributes)
        .to eq({
                 :save => [:save]
               }
            )
    end

    it '.association_show_associationss' do
      authorize!(test_helper, query: :basic_assoc_validation?, associations: [:show])
      expect(association_show_associations)
        .to eq({
                 :show => [:show]
               }
            )
    end

    it '.association_create_associations' do
      authorize!(test_helper, query: :basic_assoc_validation?, associations: [:create])
      expect(association_create_associations)
        .to eq({
                 :create => [:create]
               }
            )
    end

    it '.association_update_associations' do
      authorize!(test_helper, query: :basic_assoc_validation?, associations: [:update])
      expect(association_update_associations)
        .to eq({
                 :update => [:update]
               }
            )
    end

    it '.association_save_associations' do
      authorize!(test_helper, query: :basic_assoc_validation?, associations: [:save])
      expect(association_save_associations)
        .to eq({
                 :save => [:save]
               }
            )
    end
  end

end