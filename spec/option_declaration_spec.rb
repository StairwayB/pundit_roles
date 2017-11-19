require_relative 'spec_helper'
describe PunditRoles do
  describe 'option declaration' do
    describe 'explicit declarations' do
      let(:current_user) { Base.new('current_user') } # Specify the current_user
      let(:explicit_declaration) { ExplicitDeclaration.new('enhanced') }
      let(:save_option) { ExplicitDeclaration.new('save_option') }

      it 'returns the permitted options correctly, specifying the fulfilled roles' do
        expect(authorize!(explicit_declaration, query: :explicit_declaration?)[:attributes])
          .to eq({
                   show: [:basic, :enhanced],
                   create: [:basic],
                   update: [:enhanced]
                 })

        expect(authorize!(explicit_declaration, query: :explicit_declaration?)[:associations])
          .to eq({
                   show: [:basic, :enhanced]
                 })
      end

      it 'resolves the :save option to :create and :update, but not :show' do
        expect(authorize!(save_option, query: :handles_save_option?)[:attributes])
          .to eq({
                   show: [:save_option],
                   create: [:save_option],
                   update: [:save_option]
                 })
        expect(authorize!(save_option, query: :handles_save_option?)[:associations])
          .to eq({
                   create: [:save_option],
                   update: [:save_option]
                 })
      end
    end

    describe 'implicit_declarations' do
      let(:current_user) { Base.new('current_user') } # Specify the current_user
      let(:show_all_role) { ImplicitDeclaration.new('show_all_role') }
      let(:create_update_all_role) { ImplicitDeclaration.new('create_update_all_role') }
      let(:save_all_role) { ImplicitDeclaration.new('save_all_role') }
      let(:all_role) { ImplicitDeclaration.new('all_role') }

      it 'correctly guesses the options when declaring with :show_all and removes restricted' do
        expect(authorize!(show_all_role, query: :implicit_declaration?)[:attributes])
          .to eq({
                   show: [:attributes, :names, :id],
                 })
        expect(authorize!(show_all_role, query: :implicit_declaration?)[:associations])
          .to eq({
                   show: [:association],
                 })
      end

      it 'correctly guesses the options when declaring with :create_all or :update_all and removes restricted' do
        expect(authorize!(create_update_all_role, query: :implicit_declaration?)[:attributes])
          .to eq({
                   show: [:attributes, :names, :id],
                   create: [:attributes, :names],
                 })
        expect(authorize!(create_update_all_role, query: :implicit_declaration?)[:associations])
          .to eq({
                   show: [:association],
                   update: [:association],
                 })
      end

      it 'correctly resolves the options when declaring with :save_all and removes restricted' do
        expect(authorize!(save_all_role, query: :implicit_declaration?)[:attributes])
          .to eq({
                   show: [:attributes, :names, :id],
                   create: [:attributes, :names],
                   update: [:attributes, :names],
                 })
        expect(authorize!(save_all_role, query: :implicit_declaration?)[:associations])
          .to eq({
                   show: [:association],
                   create: [:association],
                   update: [:association],
                 })
      end

      it 'correctly guesses the options, when declaring with :all and removes restricted' do
        expect(authorize!(all_role, query: :implicit_declaration?)[:attributes])
          .to eq({
                   show: [:attributes, :names, :id],
                   create: [:attributes, :names]
                 })
        expect(authorize!(all_role, query: :implicit_declaration?)[:associations])
          .to eq({
                   create: [:association],
                 })
      end

    end
  end
end

