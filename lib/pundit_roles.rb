require 'active_support/core_ext/hash/slice'
require 'active_support/core_ext/array/extract_options'
require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/object/blank'

require 'pundit_roles/version'
require 'pundit_roles/pundit'
require 'pundit_roles/policy/base'
require 'pundit'

module PunditRoles
  include Pundit
end