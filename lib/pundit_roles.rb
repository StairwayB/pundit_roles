require 'pundit_roles/version'
require 'pundit_roles/application_policy/base'
require 'pundit_roles/pundit'


module PunditRoles
  include Pundit
  include PunditRoles::Pundit
end
