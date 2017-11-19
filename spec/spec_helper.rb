# require 'simplecov'
# SimpleCov.start

require 'coveralls'
Coveralls.wear!

require 'bundler/setup'
Bundler.setup

require 'pundit'
require 'pundit_roles'

require 'rack'
require 'rack/test'
require 'pry'
require 'active_support'
require 'active_support/core_ext'

RSpec.configure do
  include Pundit
end

class Base
  attr_accessor :id
  def initialize(id)
    @id = id
  end

  def where(opt)
    return "scope with #{opt}"
  end
end

class BasePolicy < Policy::Base
  private

  def basic_role?
    @user.present?
  end

  def enhanced_role?
    @resource.id == 'enhanced'
  end
end

############################
# describe 'basic behaviour'
############################

class Basic < Base; end

class BasicPolicy < BasePolicy

  role :basic_role,
       attributes: {
         show: [:basic, :attributes]
       },
       associations: {
         show: [:basic, :associations]
       }

  role :enhanced_role,
       attributes: {
         show: [:enhanced, :attributes],
         create: [:enhanced, :attributes]
       },
       associations: {
         show: [:enhanced, :associations]
       }

  def allow_no_one?
    false
  end

  def allow_regular?
    allow :basic_role
  end

  def pundit_default?
    @user.present?
  end

  def allow_only_enhanced?
    allow :enhanced_role
  end

  def raises_no_method?
    allow :no_method
  end

  def returns_permitted?
    allow :basic_role
  end

  def merges_roles?
    allow :basic_role, :enhanced_role
  end

end

#######################
# describe 'guest role'
#######################

class Guest < Base; end

class GuestPolicy < BasePolicy
  role :guest,
       attributes: {
         show: [:guest, :attributes],
       },
       associations: {
         show: [:guest, :associations]
       },
       scope: lambda{@resource.where('guest')}

  role :other,
       attributes: {
         show: [:other, :attributes]
       }

  def return_scope?
    allow :guest, :other
  end

  def allow_guest?
    allow :guest, :other
  end

  def dont_allow_guest?
    allow :other
  end

  def other?
    @resource.id == 'other'
  end
end

###############################
# describe 'option declaration'
###############################

class ExplicitDeclaration < Base; end

class ExplicitDeclarationPolicy < BasePolicy

  role :basic_role,
       attributes: {
         show: [:basic],
         create: [:basic]
       },
       associations: {
         show: [:basic]
       }

  role :enhanced_role,
       attributes: {
         show: [:enhanced],
         update: [:enhanced]
       },
       associations: {
         show: [:enhanced]
       }

  role :save_option_role,
       attributes: {
         show: [:save_option],
         save: [:save_option]
       },
       associations: {
         save: [:save_option]
       }

  def explicit_declaration?
    allow :basic_role, :enhanced_role, :guest
  end

  def handles_save_option?
    allow :save_option_role
  end

  private

  def save_option_role?
    @resource.id == 'save_option'
  end

end

class ImplicitDeclaration < Base
  def self.column_names
    [:attributes, :names, :id]
  end

  def self.reflect_on_all_associations
    [OpenStruct.new(:name => :association)]
  end
end

class ImplicitDeclarationPolicy < BasePolicy

  role :show_all_role,
       attributes: :show_all,
       associations: :show_all

  role :create_update_all_role,
       attributes: :create_all,
       associations: :update_all

  role :save_all_role,
       attributes: :save_all,
       associations: :save_all

  role :all_role,
       attributes: {
         show: :all,
         create: :all
       },
       associations: {
         create: :all
       }

  role :removes_restricted_role,
       attributes: {
         create: :all
       }

  def implicit_declaration?
    allow :show_all_role, :create_update_all_role, :save_all_role, :all_role
  end

  private

  def show_all_role?
    @resource.id == 'show_all_role'
  end

  def create_update_all_role?
    @resource.id == 'create_update_all_role'
  end

  def save_all_role?
    @resource.id == 'save_all_role'
  end

  def all_role?
    @resource.id == 'all_role'
  end

end

###################
# describe 'scopes'
###################

class Scoped < Base; end

class ScopedPolicy < BasePolicy
  role :guest, scope: lambda{resource.where('guest_user')}
  role :some_role, scope: lambda{resource.where('some_role')},
        attributes:{
          show: [:some_role]
        }
  role :some_extra_role, scope: lambda{resource.where('some_extra_role')},
        attributes:{
         show: [:some_extra_role]
        }
  role :not_allowed, scope: lambda{resource.where('not_allowed')}

  def index?
    allow :some_role, :some_extra_role
  end

  def allow_guest?
    allow :guest, :some_role
  end

  def dont_allow_guest?
    allow :some_role
  end

  def boolean_permission?
    true
  end

  private

  def some_role?
    @resource.id == 'some_role'
  end

  def some_extra_role?
    @resource.id == 'some_extra_role'
  end

  def not_allowed?
    @resource.id == 'not_allowed'
  end
end

#####################
# describe 'defaults'
#####################

class Defaults < Base; end

class DefaultsPolicy < BasePolicy
  RESTRICTED_SHOW_ATTRIBUTES = [:restricted]
  RESTRICTED_CREATE_ATTRIBUTES = BasePolicy::RESTRICTED_CREATE_ATTRIBUTES + [:restricted]
end

#####################################
# describe 'pundit associations'
# describe 'pundit selectors'
#####################################


class AssociationPermission < Base
  def self.reflect_on_all_associations
    [OpenStruct.new(:name => :assoc, :class_name => 'AssociatedPermission'),
     OpenStruct.new(:name => :show, :class_name => 'AssociatedPermission'),
     OpenStruct.new(:name => :create, :class_name => 'AssociatedPermission'),
     OpenStruct.new(:name => :update, :class_name => 'AssociatedPermission'),
     OpenStruct.new(:name => :save, :class_name => 'AssociatedPermission')]
  end
end

class AssociationPermissionPolicy < BasePolicy
  role :regular_user,
       attributes: {show: [:base]},
       associations: {show: [:associated_permission]},
       associated_as: {:associated_permission => [:regular_user]}

  role :nested_user,
       attributes: {show: [:base]},
       associations: {show: [:associated_permission]},
       associated_as: {:associated_permission => [:nested_user_one]}

  role :aliased_assoc,
       attributes: {show: [:base]},
       associations: {show: [:assoc]},
       associated_as: {:assoc => [:nested_user_two]}

  role :selector_helper_user,
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
       associated_as: {:show => [:test_helper], :create => [:test_helper], :update => [:test_helper], :save => [:test_helper]}

  role :raises_role,
       associations: {
         show: [:doesnt_exist]
       },
       associated_as: {:show => [:doesnt_exist]}

  def basic_assoc_validation?
    allow :regular_user, :selector_helper_user
  end

  def nested_assoc_validation?
    allow :nested_user
  end

  def aliased_validation?
    allow :aliased_assoc
  end

  def raises_name_error?
    allow :raises_role
  end

  private

  def regular_user?
    @resource.id == 'regular_user'
  end

  def nested_user?
    @resource.id == 'nested_user'
  end

  def aliased_assoc?
    @resource.id == 'aliased_assoc'
  end

  def selector_helper_user?
    @resource.id == 'selector_helper_user'
  end

  def raises_role?
    @resource.id == 'raises_role'
  end
end

class AssociatedPermission < AssociationPermission; end

class AssociatedPermissionPolicy < BasePolicy
  role :regular_user,
       attributes: {show: [:assoc]}

  role :nested_user_one,
       attributes: {show: [:assoc]},
       associations: {show: [:nested_permission]},
       associated_as: {:nested_permission =>:regular_user}

  role :nested_user_two,
       attributes: {show: [:assoc]},
       associations: {show: [:nested_permission]},
       associated_as: {:nested_permission => [:regular_user, :other_user]}

  role :test_helper,
       attributes: {
         show: [:show],
         create: [:create],
         update: [:update]
       },
       associations: {
         show: [:show],
         create: [:create],
         update: [:update]
       }
end

class NestedPermission < AssociationPermission; end

class NestedPermissionPolicy < BasePolicy
  role :regular_user,
       attributes: {show: [:nested]}
  role :other_user,
       attributes: {show: [:other_nested]}
end
