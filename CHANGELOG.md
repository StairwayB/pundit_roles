# PunditRoles

## 0.2.0 (2017-10-30)

- Roles and permitted options are no longer separately declared with `role` and 
  `permitted_for` methods. Declaration of options has been consolidated into the 
  `role` method.
- Roles can no longer be inherited from the superclass.
- Test conditions for the roles are now guessed from the name of the role, 
  instead of being declared explicitly with the `authorize_with` option.