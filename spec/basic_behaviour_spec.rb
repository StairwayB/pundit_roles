require_relative 'spec_helper'
describe PunditRoles do

  describe 'basic behaviour' do
    let(:current_user) { Base.new('current_user') } # Specify the current_user
    let(:basic_role) { Basic.new('basic') }
    let(:enhanced_role) { Basic.new('enhanced') }

    it 'returns a hash of options if user is permitted' do
      expect(authorize!(basic_role, query: :allow_regular?)).to be_a(Hash)
    end

    it 'raises exception if the action is not permitted' do
      expect{authorize!(basic_role, query: :allow_no_one?)}.to raise_error(Pundit::NotAuthorizedError)
    end

    it 'raises exception if the current_user is not allowed for the action' do
      expect {authorize!(basic_role, query: :allow_only_enhanced?) }.to raise_error(Pundit::NotAuthorizedError)
    end

    it 'allows enhanced_role if it satisfies the conditional' do
      expect(authorize!(enhanced_role, query: :allow_only_enhanced?)).to be_a(Hash)
    end

    it 'expects Pundit default to work as intended' do
      expect(authorize!(basic_role, query: :pundit_default?)).to be_truthy
    end

    it 'raises exception if the test condition is undefined' do
      expect {authorize!(basic_role, query: :raises_no_method?) }.to raise_error(NoMethodError)
    end

    it 'returns the allowed attributes, associations and roles of the user' do
      expect(authorize!(basic_role, query: :returns_permitted?))
        .to eq({
                 attributes: {
                   show: [:basic, :attributes]
                 },
                 associations: {
                   show: [:basic, :associations]
                 },
                 roles: {
                   for_current_model:[:basic_role],
                   for_associated_models:{}
                 }
               })
    end

    it 'merges the fulfilled roles and returns the allowed attributes, associations and roles of the user' do
      expect(authorize!(enhanced_role, query: :merges_roles?))
        .to eq({
                 attributes: {
                   show: [:basic, :attributes, :enhanced],
                   create: [:enhanced, :attributes]
                 },
                 associations: {
                   show: [:basic, :associations, :enhanced],
                 },
                 roles: {
                   for_current_model:[:basic_role, :enhanced_role],
                   for_associated_models:{}
                 }
               })
    end

  end

end
