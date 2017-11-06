require_relative 'spec_helper'

describe PunditRoles do

  describe '.authorize!' do
    let(:current_user) { User.new(1) } # Specify that current_user is is User with id 1
    let(:regular_user) { User.new(153) }
    let(:correct_user) { User.new(1) }

    it 'returns a hash of options if user is permitted' do
      expect(authorize!(regular_user, :allow_regular?)).to be_a(Hash)
    end

    it 'raises exception if the action is not permitted' do
      expect{authorize!(regular_user, :allow_no_one?)}.to raise_error(Pundit::NotAuthorizedError)
    end

    it 'raises exception if the current_user is not allowed for the action' do
      expect {authorize!(regular_user, :allow_only_correct?) }.to raise_error(Pundit::NotAuthorizedError)
    end

    it 'allows current_user if it satisfies the conditional' do
      expect(authorize!(correct_user, :allow_only_correct?)).to be_a(Hash)
    end

    it 'expects Pundit default to work as intended' do
      expect(authorize!(regular_user, :pundit_default?)).to be_truthy
    end

    it 'raises exception if the test condition is undefined' do
      expect {authorize!(regular_user, :raises_no_method?) }.to raise_error(NoMethodError)
    end

  end

  describe 'guest role' do
    let(:current_user) { nil } # Specify that current_user is guest
    let(:regular_user) { User.new(153) }
    let(:scoped_user) { ScopedUser.new(2) }

    it 'returns the guest role, if guest is permitted' do
      expect(authorize!(regular_user, :allow_guest?)).to be_a(Hash)
    end

    it 'raises exception if user is guest, but guest is not permitted' do
      expect{authorize!(regular_user, :allow_regular?)}.to raise_error(Pundit::NotAuthorizedError)
    end

    it 'returns only the guest attributes, when user is a guest' do
      expect(authorize!(regular_user, :allow_guest?)).to eq({attributes: {show: %i(username name),
                                                                                   create: %i(username name email phone_number password)},
                                                                      associations: {},
                                                                      roles: [:guest]
                                                                     })
    end

    it 'returns the scope if guest is permitted and user is guest' do
      expect(policy_scope!(scoped_user, :allows_guest?)).to eq :guest_user
    end

    it 'raises exception if user is guest, and guest is not allowed' do
      expect{policy_scope!(scoped_user, :doesnt_allow_guest?)}.to raise_error(Pundit::NotAuthorizedError)
    end

  end

  describe 'explicit declarations' do
    let(:current_user) { User.new(1) }  # Specify that current_user is is User with id 1
    let(:regular_user) { User.new(153) }
    let(:correct_user) { User.new(1) }

    it 'returns the permitted options correctly, specifying the fulfilled roles' do
      expect(authorize!(regular_user, :can_have_merged_roles?)).to eq({attributes: {show: %i(username name created_at)},
                                                                      associations: {show: %i(posts followers following)},
                                                                      roles: [:logged_in_user]
                                                                     })
    end

    it 'returns the permitted options, uniquely merging them when the current_user fulfils multiple roles' do
      expect(authorize!(correct_user, :can_have_merged_roles?)).to eq({attributes: {show: %i(username name created_at email phone_number updated_at),
                                                                                   update: %i(username email password current_password name)},
                                                                      associations: {show: %i(posts followers following settings),
                                                                                     save: %i(settings)},
                                                                      roles: [:logged_in_user, :correct_user]
                                                                     })
    end

  end

  describe 'implicit_declarations' do
    let(:current_user) { User.new(1) }  # Specify that current_user is is User with id 1
    let(:regular_user) { ImplicitUser.new(153) }
    let(:correct_user) { ImplicitUser.new(1) }
    let(:restricted_user) {RestrictedUser.new(2)}

    it 'correctly guesses the options, when declaring with {opt}_all' do
      expect(authorize!(regular_user, :implicit_declaration?)).to eq({:attributes=>{:show=>[:column], :save=>[:column]},
                                                                     :associations=>{:show=>[:assoc]},
                                                                     :roles=>[:regular_user]})
    end

    it 'correctly guesses the options, when declaring with :all and :all_minus' do
      expect(authorize!(correct_user, :implicit_option_declaration?)).to eq({:attributes=>{:show=>[:column], :create=>[]},
                                                                     :associations=>{},
                                                                     :roles=>[:correct_user]})
    end

    it 'removes the restricted attributes' do
      expect(authorize!(restricted_user, :remove_restricted?)).to eq({:attributes=>{:show=>[:column]},
                                                                            :associations=>{},
                                                                            :roles=>[:regular_user]})
    end

  end

  describe 'scopes' do
    let(:current_user) { User.new(1) }  # Specify that current_user is is User with id 1
    let(:regular_user) { ScopedUser.new(2) }
    let(:some_user) { ScopedUser.new(3) }
    let(:not_allowed_user) {ScopedUser.new(4)}

    it 'returns the scope of the first role that the user fulfills' do
      expect(policy_scope!(regular_user, :index?)).to eq [:returns, :many, :things]
    end

    it 'raises Pundit::NotAuthorizedError if the user is not allowed ' do
      expect{policy_scope!(not_allowed_user, :index?)}.to raise_error(Pundit::NotAuthorizedError)
    end

    it 'allows the getting the permissions as well as scopes from a method' do
      expect(policy_scope!(some_user, :index?)).to eq :some_user
      expect(authorize!(some_user, :index?)).to eq({:attributes=>{:show=>[:username, :email]},
                                                     :associations=>{},
                                                     :roles=>[:some_role, :some_extra_role]})
    end
  end

  describe 'defaults' do
    let(:current_user) { User.new(1) }  # Specify that current_user is is User with id 1
    let(:regular_user) { User.new(153) }
    let(:correct_user) { User.new(1) }

    it 'returns false by default for index?' do
      expect{authorize!(regular_user, :index?)}.to raise_error(Pundit::NotAuthorizedError)
    end

    it 'returns false by default for show?' do
      expect{authorize!(regular_user, :show?)}.to raise_error(Pundit::NotAuthorizedError)
    end

    it 'returns false by default for create?' do
      expect{authorize!(regular_user, :create?)}.to raise_error(Pundit::NotAuthorizedError)
    end

    it 'returns false by default for update' do
      expect{authorize!(regular_user, :update?)}.to raise_error(Pundit::NotAuthorizedError)
    end

    it 'returns false by default for destroy' do
      expect{authorize!(regular_user, :destroy?)}.to raise_error(Pundit::NotAuthorizedError)
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

end