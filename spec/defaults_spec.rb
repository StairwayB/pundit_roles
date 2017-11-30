describe PunditRoles do
  describe 'defaults' do
    let(:current_user) { Base.new('current_user') } # Specify the current_user
    let(:defaults) { Defaults.new('user') }

    it 'returns false by default for index?' do
      expect{authorize!(defaults, query: :index?)}.to raise_error(Pundit::NotAuthorizedError)
    end

    it 'returns false by default for show?' do
      expect{authorize!(defaults, query: :show?)}.to raise_error(Pundit::NotAuthorizedError)
    end

    it 'returns false by default for create?' do
      expect{authorize!(defaults, query: :create?)}.to raise_error(Pundit::NotAuthorizedError)
    end

    it 'returns false by default for update' do
      expect{authorize!(defaults, query: :update?)}.to raise_error(Pundit::NotAuthorizedError)
    end

    it 'returns false by default for destroy' do
      expect{authorize!(defaults, query: :destroy?)}.to raise_error(Pundit::NotAuthorizedError)
    end

    it 'allows providing a new set of restricted attributes, without overwriting parent' do
      expect(DefaultsPolicy::RESTRICTED_SHOW_ATTRIBUTES).to eq([:restricted])
      expect(Policy::Base::RESTRICTED_SHOW_ATTRIBUTES).to eq([])
    end

    it 'allows allows adding to the restricted attributes, without overwriting parent' do
      expect(DefaultsPolicy::RESTRICTED_CREATE_ATTRIBUTES).to eq([:id, :created_at, :updated_at, :restricted])
      expect(Policy::Base::RESTRICTED_CREATE_ATTRIBUTES).to eq([:id, :created_at, :updated_at])
    end
  end
end