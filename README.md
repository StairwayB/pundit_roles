# PunditRoles

PunditRoles is a helper gem which works on top of [Pundit](https://github.com/elabs/pundit)
(if you are not familiar with Pundit, it is recommended you read it's documentation before continuing).
It allows you to extend Pundit's authorization system to include attributes and associations.

If you are already using Pundit, this gem should not conflict 
with any of Pundit's existing functionality. You may use Pundit's features as well as
the features from this gem interchangeably. 

Please note that this gem is not affiliated with Pundit or it's creators, but it very much
appreciates the work that they did with their amazing gem. Also note that this gem is early
in it's development and is **not** considered production ready!

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
  # def show?
  #   [...]
  # end
end
```

## Roles

PunditRoles operates around the notion of _**roles**_. Each role needs to be defined at the Policy level,
and provided with a conditional method that determines whether the @user(current_user in the context of the Policy) falls into this role. Additionally, each
role can have a set of permitted _**attributes**_ and _**associations**_(from here on collectively referred to as **_options_**) 
defined for it. A basic example for a UserPolicy would be:
```ruby
role :user, authorize_with: :logged_in_user
permitted_for :user,
              attributes: {
                show: %i(username name avatar is_confirmed created_at)
              },
              associations: {
                show: %i(posts followers following)
              }

role :correct_user, authorize_with: :correct_user
permitted_for :correct_user,
              attributes: {
                show: %i(email phone_number confirmed_at updated_at sign_in_count),
                update: %i(username email password password_confirmation current_password name avatar)
              },
              associations: {
                show: %i(settings),
                save: %i(settings)
              }
```

This assumes that there are two methods defined in the UserPolicy called `logged_in_user?` and
`correct_user?`. More on that later. 

* (_If someone is confused by the `%i(attr_one attr_two)`, 
it is simply shorthand for `[:attr_one, :attr_two]`_)

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

Finally, in your controller you call Pundit's `authorize` method and pass it's return value
to a variable: 
```ruby
class UserController < ApplicationController
  def show
    user = User.find(params[:id])
    permitted = authorize user
    # [...]
  end
end
```

The `authorize` method will return a hash of permitted attributes and associations for the corresponding action that the
user has access to. What you do with that is your business. Accessors for each segment look like this: 
```ruby
permitted[:attributes][:show]
permitted[:attributes][:create]

permitted[:associations][:show]
permitted[:associations][:update]
```

If the user does not fall into any roles permitted by a query, it will raise `Pundit::NotAuthorizedError`

#### Defining roles

Roles are defined with the `role` method. It receives the name of the role as it's first argument, and
options as it's second. Required option is the `authorize_with` attribute, in which you pass the method
which validates the role. Method must be passed as a symbol without the question mark, and declared
as a method with a question mark.

Currently there are no more options, but some, like database permissions, are planned for future updates.

```ruby
role :user, authorize_with: :logged_in_user

def logged_in_user?
  user.present?
end
```

#### Users with multiple roles

You may have noticed that in the first example, `correct_user` has fewer permitted options
defined than `user`. That is because PunditRoles does not treat roles as exclusionary, instead it treats roles as, well, roles.
Users may have one role, or they may have multiple roles within the context of the model they are trying to access.
In the previous example, a `correct_user`, meaning a `user` trying to access it's own Model, is naturally 
also a regular `user`, so it will have access to all options a regular `user` has access to, plus the 
options that a `correct_user` has access to. 

Take this example, to better illustrate what is happening: 

```ruby
role :user, authorize_with: :logged_in_user
permitted_for :user,
              attributes: {
                show: %i(username name avatar)
              }

role :correct_user, authorize_with: :correct_user
permitted_for :correct_user,
              attributes: {
                show: %i(email phone_number)
              }
              
role :admin, authorize_with: :admin
permitted_for :admin,
              attributes: {
                show: %i(email is_admin)
              }
```

Here, a user which fulfills the `admin` condition, trying to access it's own Model, would receive the 
options of all three roles, meaning the `show` attributes of the hash would look like: 
```ruby
[:username, :name, :avatar, :email, :phone_number, :is_admin]
```
Notice that there are no duplicates. This is because whenever a user tries to access an action, 
PunditRoles will evaluate whether the user falls into the roles permitted to perform said action, 
and if they do, it will uniquely merge the options hashes of all of these.

If the user is an `admin`, but is not a `correct_user`, it will not receive the `phone_number` attribute,
because that is unique to `correct_user` and vice versa.

At present, there is no way to prevent merging of roles. Such a feature may be coming in a 
future update.

#### Inheritance and the default Guest role

One thing to watch out for is that roles are inherited but options are not.
This means that you may declare commonly used roles, whose validations are 
independent of the @record of the Policy, in the ApplicationPolicy, and may reuse them
further down the line. You may also overwrite roles defined in a parent class. This will not
affect the role in the parent.

It is important to declare the options with the `permitted_for` method for each role that you permit
in your Policy, otherwise the role will return an empty hash.

With that in mind, PunditRoles comes with a default `:guest` role, which simply checks if
the user is nil. If you wish to permit guest users for a particular action, simply define the
options for it and allow it in your query method. 

```ruby
class UserPolicy < ApplicationPolicy
  permitted_for :guest,
                 attributes: {
                   show: %i(username first_name last_name avatar),
                   create: %i(username email password password_confirmation first_name last_name avatar)
                 },
                 associations: {}
  
  def show?
    allow :guest
  end
  
  def create?
    allow :guest
  end
  
end
```

* **Important!** The `:guest` role is exclusionary by default, meaning it cannot be merged
with other roles. It is also the first role that is evaluated, and if the user is a `:guest`, it will return the guest
attributes if `:guest` is allowed, or raise `PunditNotAuthorized` if not. 
Do **NOT** overwrite the `:guest` role, that can lead to unexpected side effects. 

#### Explicit declaration of options

Options are declared with the `permitted_for` method, which receives the role as it's first argument,
and the options as it's second.

Valid options for the `permitted_for` method are `:attributes` and `:associations`. 
Within these valid options are `:show`,`:create`,`:update` and `:save` or the implicit options.

#### Implicit declaration of options

PunditRoles provides a set of helpers to be able to implicitly declare the options of a role. 

 ---
Although this is a possibility, it is _highly recommended_ that you explicitly declare 
attributes for each role, to avoid any issues further in development, like say, an extra 
attribute that is added to model later down the line. 
---
* **show_all**

Will be able to view all non-restricted options.

```ruby
role :admin, authorize_with: :admin
permitted_for :admin,
              attributes: :show_all,
              associations: :show_all
```
* **create_all, update_all, save_all**

Will be able to create, update or save all non-restricted attributes. These options also
imply that the role will be able to `show_all` options. 
```ruby
role :admin, authorize_with: :admin
permitted_for :admin,
              attributes: :save_all,
              associations: :update_all
```

* **all**

Declare on a per-action basis whether the role has access to all options. 
```ruby
role :admin, authorize_with: :admin
permitted_for :admin,
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
role :admin, authorize_with: :admin
permitted_for :admin,
              attributes: {
                show: [:all_minus, :password_digest]
              }
```
The `:admin` role will now be able to view all attributes, except `password_digest`.

#### Restricted options

PunditRoles allows you to define restricted options which will be removed when declaring 
implicitly. By default, only the `:id, :created_at, :updated_at` attributes are restricted
for `create`,`update` and `save` actions. You may overwrite this behaviour on a per-policy basis: 
```ruby
private

def restricted_show_attributes
  [:attr_one, :attr_two]
end
```
Or if you want to add to it, instead of overwriting, use `super`:
```ruby
def restricted_create_attributes
  super + [:attr_one, :attr_two]
end
```

There are 8 `restricted_#{action}_#{option_type}` methods in total, where `option_type` refers
to either `attributes` or `associations` and `action` refers to `show`, `create`, `update` or `save`.

#### Planned updates

Support for Pundit's scope method should be added in the near future, along with generators,
and rspec helpers. And once the test suite is finished for this gem, it should be production
ready. 

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake 'spec'` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports are welcome on GitHub at [StairwayB](https://github.com/StairwayB/pundit_roles). If you wish to collaborate, send
your Github username to danielferencbalogh@gmail.com


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

