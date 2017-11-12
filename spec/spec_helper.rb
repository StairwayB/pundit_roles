require 'coveralls'
Coveralls.wear!

# require 'simplecov'
# SimpleCov.start

require 'bundler/setup'
Bundler.setup

require 'pundit'
require 'pundit_roles'

require 'rack'
require 'rack/test'
require 'pry'
require 'active_support'
require 'active_support/core_ext'

RSpec.configure do |config|
  include Pundit
end

class User
  attr_accessor :id
  def initialize(id)
    @id = id
  end
end

class UserPolicy < Policy::Base

  role :guest,
       attributes: {
         show: %i(username name),
         create: %i(username name email phone_number password)
       },
       associations: {}

  role :logged_in_user,
       attributes: {
         show: %i(username name created_at)
       },
       associations: {
         show: %i(posts followers following)
       }


  role :correct_user,
       attributes: {
         show: %i(username email phone_number updated_at),
         update: %i(username email password current_password name)
       },
       associations: {
         show: %i(settings),
         save: %i(settings)
       }

  def allow_no_one?
    false
  end

  def allow_regular?
    allow :logged_in_user
  end

  def pundit_default?
    @user.present?
  end

  def allow_guest?
    allow :guest, :logged_in_user
  end

  def allow_only_correct?
    allow :correct_user
  end

  def can_have_merged_roles?
    allow :guest, :logged_in_user, :correct_user
  end

  def raises_no_method?
    allow :no_method
  end

  protected

  def logged_in_user?
    @user.present?
  end

  def correct_user?
    @user.id == @resource.id
  end

end

class ImplicitUser < User
  def self.column_names
    %i(column)
  end

  def self.reflect_on_all_associations
    [OpenStruct.new(:name => :assoc)]
  end
end

class ImplicitUserPolicy < Policy::Base
  role :regular_user,
       attributes: :save_all,
       associations: :show_all

  role :correct_user,
       attributes: {show: :all,
                    create: [:all_minus, :column]}

  def implicit_declaration?
    [:regular_user]
  end

  def implicit_option_declaration?
    [:correct_user]
  end

  protected

  def correct_user?
    @user.id == @resource.id
  end

  def regular_user?
    @user.present?
  end

end

class RestrictedUser < User
  def self.column_names
    %i(column remove_this)
  end
end

class RestrictedUserPolicy < Policy::Base
  RESTRICTED_SHOW_ATTRIBUTES = [:remove_this]
  RESTRICTED_CREATE_ATTRIBUTES = RESTRICTED_CREATE_ATTRIBUTES + [:extra]

  role :regular_user,
       attributes: :show_all

  def remove_restricted?
    [:regular_user]
  end

  def regular_user?
    @user.present?
  end
end

class ScopedUser < User
  def guest_user
    :guest_user
  end

  def some_user
    :some_user
  end

  def regular_user
    [:returns, :many, :things]
  end

end

class ScopedUserPolicy < Policy::Base

  role :guest, scope: lambda{resource.guest_user}
  role :some_role, scope: lambda{resource.some_user},
        attributes:{
          show: %i(username)
        }
  role :some_extra_role, scope: lambda{resource.regular_user},
        attributes:{
         show: %i(email)
        }
  role :regular_user, scope: lambda{resource.regular_user}
  role :not_allowed, scope: lambda{resource.guest_user}

  def index?
    allow :some_role, :regular_user, :some_extra_role
  end

  def allows_guest?
    allow :guest, :regular_user
  end

  def doesnt_allow_guest?
    allow :regular_user
  end

  def boolean_permission?
    true
  end

  private

  def some_role?
    @resource.id == 3
  end

  def some_extra_role?
    @resource.id == 3
  end

  def regular_user?
    @resource.id == 2
  end

  def not_allowed?
    @resource.id == 4
  end
end

class AssociationPermission < User
  def self.reflect_on_all_associations
    [OpenStruct.new(:name => :assoc, :class_name => 'AssociatedPermission'),
     OpenStruct.new(:name => :show, :class_name => 'AssociatedPermission'),
     OpenStruct.new(:name => :create, :class_name => 'AssociatedPermission'),
     OpenStruct.new(:name => :update, :class_name => 'AssociatedPermission'),
     OpenStruct.new(:name => :save, :class_name => 'AssociatedPermission')]
  end
end

class AssociationPermissionPolicy < Policy::Base
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

  role :test_helper,
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
       associated_as: {:show => [:test_helper], :create => [:test_helper], :update => [:test_helper], :save => [:test_helper]}

  def basic_assoc_validation?
    allow :regular_user, :test_helper
  end

  def nested_assoc_validation?
    allow :nested_user
  end

  def aliased_validation?
    allow :aliased_assoc
  end

  private

  def regular_user?
    @resource.id == 2
  end

  def nested_user?
    @resource.id == 3
  end

  def aliased_assoc?
    @resource.id == 4
  end

  def test_helper?
    @resource.id == 5
  end
end

class AssociatedPermission < AssociationPermission

end

class AssociatedPermissionPolicy < Policy::Base
  role :regular_user,
       attributes: {show: [:assoc]}

  role :nested_user_one,
       attributes: {show: [:assoc]},
       associations: {show: [:nested_permission]},
       associated_as: {:nested_permission => [:regular_user]}

  role :nested_user_two,
       attributes: {show: [:assoc]},
       associations: {show: [:nested_permission]},
       associated_as: {:nested_permission => [:regular_user, :other_user]}

  role :test_helper,
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
       }
end

class NestedPermission < AssociationPermission; end

class NestedPermissionPolicy < Policy::Base
  role :regular_user,
       attributes: {show: [:nested]}
  role :other_user,
       attributes: {show: [:other_nested]}
end
