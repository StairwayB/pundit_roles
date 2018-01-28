require_relative 'spec_helper'
describe PunditRoles do
  describe 'guest role' do
    let(:current_user) { nil } # Specify that current_user is guest
    let(:guest_role) { Guest.new('guest') }

    it 'returns the guest role, if guest is permitted' do
      expect(authorize!(guest_role, query: :allow_guest?)).to be_a(Hash)
    end

    it 'raises exception if user is guest, but guest is not permitted' do
      expect{authorize!(guest_role, query: :dont_allow_guest?)}.to raise_error(Pundit::NotAuthorizedError)
    end

    it 'returns only the guest attributes, when user is a guest' do
      expect(authorize!(guest_role, query: :allow_guest?))
        .to eq({
                 attributes: {
                   show: [:guest, :attributes]
                 },
                 associations: {
                   show: [:guest, :associations]
                 },
                 roles: {
                   for_current_model:[:guest],
                   for_associated_models:{}
                 }
               })
    end

    it 'returns the scope if guest is permitted and user is guest' do
      expect(policy_scope!(guest_role, query: :allow_guest?)).to eq 'scope with guest'
    end

    it 'raises exception if user is guest, and guest is not allowed' do
      expect{policy_scope!(guest_role, query: :dont_allow_guest?)}.to raise_error(Pundit::NotAuthorizedError)
    end

  end
end
