# PunditRoles

[![Gem Version](https://badge.fury.io/rb/pundit_roles.svg)](https://rubygems.org/gems/pundit_roles)
[![Build Status](https://travis-ci.org/StairwayB/pundit_roles.svg?branch=master)](https://travis-ci.org/StairwayB/pundit_roles)
[![Coverage Status](https://coveralls.io/repos/github/StairwayB/pundit_roles/badge.svg?branch=master)](https://coveralls.io/github/StairwayB/pundit_roles?branch=master)
[![Maintainability](https://api.codeclimate.com/v1/badges/030ffce3612160c8e7f0/maintainability)](https://codeclimate.com/github/StairwayB/pundit_roles/maintainability)

PunditRoles is a helper gem which works on top of [Pundit](https://github.com/elabs/pundit)
(if you are not familiar with Pundit, it is recommended you read it's documentation before continuing).
It allows you to extend Pundit's authorization system to include attributes and associations, and provides a couple of
helpers for convenience.

If you are already using Pundit, this should not conflict with any of Pundit's existing functionality. 
You may use Pundit's features as well as the features from this gem interchangeably. There are
some caveats however, see the [Porting over from Pundit](#porting-over-from-pundit).

Please note that this gem is not affiliated with Pundit or it's creators, but it very much
appreciates the work that they did with their great authorization system.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'pundit_roles'
```

Add PunditRoles to your ApplicationController(Pundit is included in PunditRoles, 
so no need to add both)
```ruby
class ApplicationController < ActionController::Base
  include PunditRoles
end
```

And inherit your ApplicationPolicy from Policy::Base
```ruby
class ApplicationPolicy < Policy::Base
end
```

## Roles

PunditRoles operates around the notion of _**roles**_. Each role needs to be defined at the Policy level
and provided with a conditional method that determines whether the `@user`(the `current_user` in the context of a Policy) 
falls into this role. Additionally, each role can have a set of permitted 
_**attributes**_ and _**associations**_ defined for it. A basic example for a UserPolicy would be:
```ruby
class UserPolicy < ApplicationPolicy
  role :regular_user,
       attributes: {
         show: %i(username name avatar is_confirmed created_at)
       },
       associations: {
         show: %i(posts followers following)
       }

role :correct_user,
       attributes: {
         show: %i(email phone_number confirmed_at updated_at sign_in_count),
         update: %i(username email password password_confirmation current_password name avatar)
       },
       associations: {
         show: %i(settings),
         save: %i(settings)
       }
end
```

This assumes that there are two methods defined in the UserPolicy called `regular_user?` and
`correct_user?`.

* Please note, that there were a couple of breaking change since `0.2.1`. View the 
[changelog](https://github.com/StairwayB/pundit_roles/blob/master/CHANGELOG.md) for additional details.

And then in you query method, you simply say:
```ruby
def show?
  %i(user correct_user)
end

def update?
  %i(correct_user)
end
```
Or you may use the `allow` helper method:
```ruby
def show?
  allow :user, :correct_user
end
```

Finally, in your controller you call `authorize!` method and pass it's return value
to a variable: 
```ruby
class UserController < ApplicationController
  def show
    @user = User.find(params[:id])
    permitted = authorize! @user
    # [...]
  end
end
```

The `authorize!` method will return a hash of permitted attributes and associations for the corresponding action that the
user has access to. What you do with that is your business. Accessors for each segment look like this: 
```ruby
permitted[:attributes][:show] # ex. returns => [:username, :name, :avatar, :is_confirmed, :created_at]
permitted[:attributes][:create] # ex. returns => [:username, :email, :password, :password_confirmation]

permitted[:associations][:show]
permitted[:associations][:update]
```

The hash also contains the roles that the user has fulfilled:
```ruby
permitted[:roles] # ex. returns => [:regular_user, :correct_user]
```

If the user does not fall into any roles permitted by a query, the `authorize` method will raise `Pundit::NotAuthorizedError`

### Defining roles

Roles are defined with the `role` method. It receives the name of the role as it's first argument and the
options for the role as it's second. Additionally, you need to define a method which checks if
the user falls into that role. This method's name must be the name of the role with a question
mark at the end. For example, a `:correct_user` role's conditional method must be declared as
`correct_user?`.

Valid options for roles are:
`:attributes, :associations, :scope`

```ruby
role :correct_user,
      attributes: {show: [:name]},
      associations: {show: [:posts]}

private

def correct_user?
  @user.id == @resource.id
end
```

One thing to watch out for is that roles are not inherited, because each is unique to the model in question. 
But since the name of the role is just the conditional method for the role,
without the '?' question mark, it is encouraged to inherit from an `ApplicationPolicy`, 
and define common `role` conditionals there. 

* see [Declaring attributes and associations](#declaring-attributes-and-associations) for how to declare 
attributes and associations.

### Users with multiple roles

You may have noticed that in the first example `correct_user` has fewer permitted attributes and associations
defined than `regular_user`. That is because PunditRoles does not treat roles as exclusionary.
Users may have a single role or they may have multiple roles, within the context of the model they are trying to access.
In the previous example, a `correct_user`, meaning a `regular_user` trying to access it's own model, is naturally 
also a `regular_user`, so it will have access to all attributes and associations a `regular_user` has access to plus the 
ones that a `correct_user` has access to. 

Take this example, to better illustrate what is happening: 

```ruby
role :regular_user,
     attributes: {
       show: %i(username name avatar)
     }

role :correct_user,
     attributes: {
       show: %i(email phone_number)
     }

role :admin_user,
     attributes: {
       show: %i(email is_admin)
     }
```

Here, a user which fulfills the `admin_user` condition trying to access it's own model, would receive the 
attributes and associations of all three roles, without any duplicates, meaning the `permitted[:attributes][:show]` would look like: 
```ruby
[:username, :name, :avatar, :email, :phone_number, :is_admin]
```

If the user is an `admin`, but is not a `correct_user`, it will not receive the `phone_number` attribute,
because that is unique to `correct_user` and vice versa.

At present, there is no way to prevent merging of roles. Such a feature may be coming in a future update.

### The :guest role

PunditRoles comes with a default `:guest` role, which simply checks if
the user is nil. If you wish to permit guest users for a particular action, simply define the
options for it and allow it in your query method. 

```ruby
class UserPolicy < ApplicationPolicy

  role :guest,
       attributes: {
         show: %i(username first_name last_name avatar),
         create: %i(username email password password_confirmation first_name last_name avatar)
       },
       associations: {}
  
  def show?
    allow :guest, :some, :other, :roles
  end
  
  def create?
    allow :guest, :admin_user
  end
  
end
```

**Important** 

* The `:guest` role is exclusionary by default, meaning it cannot be merged
with other roles. It is also the first role that is evaluated, and if the user is a `:guest`, it will return the guest
attributes if `:guest` is allowed, or raise `Pundit::NotAuthorizedError` if not. 

* Do **not** use a custom role for `nil` users, use `:guest`. 
If you do, it will most likely lead to unwanted errors.

### Scopes
PunditRoles supports limiting scopes for actions which return a list of records. If you wish to do
this, define a scope option for a role as a `lambda`, and then call `policy_scope!` for the list you want to 
limit. It should look something like this: 
```ruby
role :guest,
    attributes: {
      show: %i(name avatar),
    },
    associations: {},
    scope: lambda{resource.where(visible_publicly: true)}
role :regular_user,
   attributes: {
     show: %i(username name avatar)
   },
   associations: {
     show: %i(posts followers following)
   },
   scope: lambda{resource.where.not(id: user.id)}
   
def index?
  allow :guest, :regular_user
end
```
Then in your controller you pass the list you want to limit based on what role the current user fulfills:
```ruby
def index
  @users = policy_scope!(User.all)
end
```
The `policy_scope!` method returns the scope for the role, or raises `Pundit::NotAuthorizedError` if the user is not 
allowed to perform the action. Since the syntax for permitting scopes is the same as the syntax for getting the permitted
attributes and associations, you may use both `authorize!` and `policy_scope!` for the same action. A recommended usage is
to use both(this example uses the excellent [jsonapi-rails](https://github.com/jsonapi-rb/jsonapi-rails) gem for serialization): 
```ruby
def index
  @users = policy_scope!(User.all)
  permitted = authorize! @users
  render jsonapi: @users, fields: {users: permitted[:attributes][:show]}
end
```

#### Important: Scope declaration order

While attributes and associations for roles are merged, scopes are **not**! This means that whenever you wish to authorize a list of records,
you must take care in what order you define the roles. PunditRoles will go over the allowed roles in a query method in the
order in which they were defined, and when it finds a role that the user fulfills, it will return the scope for that role.

Take this example, where there are two roles permitted for an `index` action: `regular_user` and `:admin_user`:
```ruby

role :regular_user, scope: lambda{resource.regular_user}
role :admin_user, scope: lambda{resource.admin_user}

def index?
  allow :regular_user, :admin_user
end

private

def regular_user?
  @user.present?
end

def admin_user?
  @user.admin?
end
```

Whenever an admin tries to access the `index` action, PunditRoles will first check if the admin is a `regular_user`,
which will be true, since admin is in fact logged in. Therefore, it will return the scope defined for `regular_user`,
instead of the scope defined for `admin_user`. This is not the desired behaviour. In order to avoid this, the `index?` method
needs to look like this:
```ruby
def index?
  allow :admin_user, :regular_user
end
```
In this case, `admin_user` is evaluated before `regular_user`, so admins will correctly get their own scope, instead of the
`regular_user` scope.

* The rule is: whenever a role supersedes another, declare that role first. If two or more roles are exclusionary,
meaning that there is no way that a user can fulfill more than one of these roles, then the order in which they are declared
does not matter. The guest role can be declared wherever, since PunditRoles will always evaluate whether the user is a 
`guest` first. 

### Declaring attributes and associations

* Attributes and associations in this heading are referred to collectively as _options_

#### Explicit declaration of options

Options are declared with the `attributes` and `associations` options of the role method.

Valid options for both `:attributes` and `:associations` are `:show`,`:create`,`:update` and `:save` or the implicit options.

#### Implicit declaration of options

PunditRoles provides a set of helpers to be able to implicitly declare the options of a role. 

 ---
 
Although this is a possibility, it is _highly recommended_ that you explicitly declare 
attributes for each role, to avoid any issues further in development, like say, an extra 
attribute that is added to a model later down the line. 

---
* **show_all**

    Will be able to view all non-restricted options.
    
    ```ruby
    role :admin,
         attributes: :show_all,
         associations: :show_all
    ```
* **create_all, update_all, save_all**

    Will be able to create, update or save all non-restricted attributes. These options also
    imply that the role will be able to `show_all` options. 
    ```ruby
    role :admin,
         attributes: :save_all,
         associations: :update_all
    ```

* **all**

    Declare on a per-action basis whether the role has access to all options. 
    ```ruby
    role :admin,
          attributes: {
            show: :all,
            save: %i(name username email)
          },
          associations: {
            show: :all
          }
    ```

* **all_minus**

    Can be used to allow all attributes, except those declared. 
    ```ruby
    role :admin,
          attributes: {
            show: [:all_minus, :password_digest]
          }
    ```
    The `:admin` role will now be able to view all attributes, except `password_digest`.

### Restricted options

PunditRoles allows you to define restricted options which will be removed when declaring 
implicitly. By default, only the `:id`, `:created_at`, `:updated_at` attributes are restricted
for `create`,`update` and `save` actions. You may overwrite this behaviour on a per-policy basis: 

```ruby
RESTRICTED_SHOW_ATTRIBUTES = [:attr_one, :attr_two]
```
Or if you want to add to it, instead of overwriting(here, 
the second `RESTRICTED_SHOW_ATTRIBUTES` resolves to the one declared on the parent):
```ruby
RESTRICTED_SHOW_ATTRIBUTES = RESTRICTED_SHOW_ATTRIBUTES + [:attr_one, :attr_two]
```

There are 8 `RESTRICTED_#{action}_#{option_type}` constants in total, where `option_type` refers
to either `ATTRIBUTES` or `ASSOCIATIONS` and `action` refers to `SHOW`, `CREATE`, `UPDATE` or `SAVE`.

## Porting over from Pundit
If you're already using Pundit, this gem should not conflict with any existing functionality. However, there
are a couple of things to watch out for: 
* PunditRoles uses `@resouce` instead of `@record` in the Policy. This change was made, to reflect the
fact that the Policy can have scopes as well as records passed to it.
* PunditRoles uses the bang methods `authorize!` and `policy_scope!`, instead of `authorize` and `policy_scope`.
* PunditRoles does not use the `Scope` class of Pundit, but it is included in `Policy::Base` so you may use
that as well, if you so choose.

## Planned updates
Authorizing associations, generators, and possibly rspec helpers will be coming in the near future.

## Contributing
Bug reports are welcome on GitHub at [StairwayB](https://github.com/StairwayB/pundit_roles).

## License
The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

