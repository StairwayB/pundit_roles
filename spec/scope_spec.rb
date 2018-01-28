describe PunditRoles do
  describe 'scopes' do
    let(:current_user) { Base.new('current_user') }  # Specify the current_user
    let(:some_extra_role) { Scoped.new('some_extra_role') }
    let(:some_role) { Scoped.new('some_role') }
    let(:not_allowed) {Scoped.new('not_allowed')}

    it 'returns the scope when true' do
      expect(policy_scope!(some_role, query: :boolean_permission?)).to eq some_role
    end

    it 'returns the scope of the first role that the user fulfills' do
      expect(policy_scope!(some_extra_role, query: :index?)).to eq 'scope with some_extra_role'
    end

    it 'raises Pundit::NotAuthorizedError if the user is not allowed ' do
      expect{policy_scope!(not_allowed, query: :index?)}.to raise_error(Pundit::NotAuthorizedError)
    end

    it 'allows the getting the permissions as well as scopes from a method' do
      expect(policy_scope!(some_role, query: :index?)).to eq 'scope with some_role'
      expect(authorize!(some_role, query: :index?))
        .to eq({attributes:
                  {
                    show: [:some_role]
                  },
                associations: {},
                roles: {
                  for_current_model: [:some_role],
                  for_associated_models: {}
                }})
    end
  end
end


