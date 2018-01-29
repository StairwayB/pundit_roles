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

Please note that this gem is not affiliated with Pundit or it's creators.

* The Readme contains only a cursory overview of the gem. For an in-depth tutorial, consult the [wiki](https://github.com/StairwayB/pundit_roles/wiki)

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
falls into this role. Additionally, each role can have a set of options defined for it(like _attributes_,
_associations_ and _scope_). A basic example for a UserPolicy would be:

```ruby
class UserPolicy < ApplicationPolicy
  role :regular_user,
       attributes: {
         show: %i(username name avatar is_confirmed created_at)
       },
       scope: lambda{resource.regular_user_scope}

  role :correct_user,
       attributes: {
         show: %i(email phone_number confirmed_at updated_at),
         update: %i(username email password password_confirmation current_password name avatar)
       }
  
  # in the query methods, you define the roles which are allowed for the particular action
  def show?
    %i(regular_user correct_user)
  end

  # or with the allow helper method:
  def update?
    allow :correct_user, :some_other_role
  end
end
```

In your Controller, you simply call the authorize! method for the action you want authorized:

```ruby
class UserController < ApplicationController
  def show
    @user = User.find(params[:id])
    authorize! @user
    render jsonapi: user, fields: permitted_show_attributes
  end
end
```

An in-depth description of the features can be found on the wiki:
1. [The basics](https://github.com/StairwayB/pundit_roles/wiki/The-Basics)
2. [Defining roles](https://github.com/StairwayB/pundit_roles/wiki/Defining-roles)
3. [Declaring attributes and associations](https://github.com/StairwayB/pundit_roles/wiki/Declaring-attributes-and-associations)

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

#### *Important* 
* The `:guest` role is exclusionary by default, meaning it cannot be merged
with other roles. It is also the first role that is evaluated, and if the user is a `:guest`, it will return the guest
attributes if `:guest` is allowed, or raise `Pundit::NotAuthorizedError` if not. 
* Do **not** use a custom role for `nil` users, use `:guest`. 
If you do, it will most likely lead to unwanted errors.

### Authorizing Associations

Detailed description in the [Authorizing associations](https://github.com/StairwayB/pundit_roles/wiki/Authorizing-Associations) wiki.

* Controller
```ruby
class UsersController < ApplicationController
    def show
      user = User.where(id: 1).includes([:followers, {posts: [:comments]}]).first
      authorize!(user, associations: [:followers, {posts: [:comments]}])
      # then you just render the results, using the helper methods 
      render jsonapi: user, include: permitted_show_associations, fields: permitted_show_attributes
    end
end
```

* Policies
```ruby
class UserPolicy < ApplicationPolicy
  role :regular_user,
       attributes: {...},
       associations: {show: [:posts]},
       associated_as: {posts: [:regular_user]}
       
  role :correct_user,
         attributes: {...},
         associations: {show: [:posts]},
         associated_as: {posts: [:regular_user, :correct_user]}
                                                               
  def show? 
    allow :regular_user, :correct_user
  end
end

class PostPolicy < ApplicationPolicy
  role :regular_user,
       attributes: {...},
       associations: {show: [:comments]},
       associated_as: {posts: [:regular_user]}
       
  role :correct_user,
         attributes: {...},
         associations: {show: [:comments]},
         associated_as: {posts: [:regular_user]}
end

class CommentPolicy < ApplicationPolicy
  role :regular_user, 
       attributes: {...}
       
  role :correct_user,
       attributes: {...}
end
```

#### *Important*

* Only the **primary** model is authorized, meaning that PunditRoles will not run the 
query methods(i.e. `allow :correct_user, ...`) or the conditional methods of the roles in associated policies!
This means that you must specify which roles correspond to which roles in associated policies(check the wiki for a 
more detailed description).

### Scopes
Detailed description in the [Defining scopes for roles](https://github.com/StairwayB/pundit_roles/wiki/Defining-scopes-for-roles) wiki.

* Policy: 
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
* Controller
```ruby
def index
  @users = policy_scope!(User.all)
end
```

### Strong parameters

Detailed description in the [Strong parameters](https://github.com/StairwayB/pundit_roles/wiki/Strong-parameters) wiki.

* Controller
```ruby
def create
  authorize! User # you will need to authorize the model first, in order to get the permitted attributes
  @user = User.new(create_params)
  if @user.save!
    render jsonapi: @user, fields: {users: permitted_show_attributes}
  end
end

private
  
def create_params
  params.require(:users).permit(permitted_create_attributes)
end
```

## Porting over from Pundit
If you're already using Pundit, this gem should not conflict with any existing functionality. However, there
are a couple of things to watch out for: 
* PunditRoles uses `@resouce` instead of `@record` in the Policy. This change was made, to reflect the
fact that the Policy can have scopes as well as records passed to it.
* PunditRoles uses the bang methods `authorize!` and `policy_scope!`, instead of `authorize` and `policy_scope`.
* PunditRoles does not use the `Scope` class of Pundit, but it is included in `Policy::Base` so you may use
that as well, if you so choose.

## Planned updates
Generators, some config options, and possibly rspec helpers will be coming in the near future.

## Contributing
Bug reports are welcome on GitHub at [StairwayB](https://github.com/StairwayB/pundit_roles).

## License
The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

