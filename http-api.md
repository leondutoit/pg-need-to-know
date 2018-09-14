
## Method overview

For the anon role:
```txt
HTTP Method     | URL
----------------|-------------------
POST            | /rpc/user_register
```

For admin_user role:
```txt
HTTP Method     | URL
----------------|-------------------------------------------
POST            | /rpc/table_create
POST            | /rpc/group_create
POST            | /rpc/group_add_members
GET             | /rpc/group_list_members?group_name=<name>
POST            | /rpc/group_remove_members
POST            | /rpc/group_delete
GET             | /rpc/user_groups?user_name=<name>
POST            | /rpc/user_delete
GET             | /registered_users
GET             | /groups
GET             | /user_initiated_group_removals
GET             | /user_data_deletion_requests
GET             | /audit_logs
```

For data_owners:
```txt
HTTP Method     | URL
----------------|-----------------------
GET             | /rpc/user_groups
POST            | /rpc/user_group_remove
POST            | /rpc/user_delete_data
```


## REST API

### For anayone

- Register as a new user, either a data owner, or a data user
```bash
POST /rpc/user_register
Content-Type: application/json
Authorization: Bearer your-jwt

{"user_name": "owner_12345", "type": "data_owner", "user_metadata": {"some": "info"}}
# or
{"user_name": "user_some_analyst", "type": "data_user", "user_metadata": {"some": "info"}}
```

### For admins

- Create a new table
```bash
POST /rpc/table_create
Content-Type: application/json
Authorization: Bearer your-jwt

{"definition": {"table_name": "people", "columns": [ {"name": "name", "type": "text"}, {"name": "age", "type": "int"} ]}, "type": "mac" }
```

- Collect data from `myuser`
```bash
POST /people
Content-Type: application/json
Authorization: Bearer your-jwt

{"name": "Frank", "age": 90}
```

- Create a new group
```bash
POST /rpc/group_create
Content-Type: application/json
Authorization: Bearer your-jwt

{"group_name": "analysis1_group", "group_metadata": {"consent_reference": 1}}
```

- Add members to the group to enable data access
```bash
POST /rpc/group_add_members
Content-Type: application/json
Authorization: Bearer your-jwt

{"memberships": [{"user_name":"myuser", "group_name":"analysis1_group"}, {"user_name":"some_analyst", "group_name":"analysis1_group"}]}
```

- List all members in a specific group
```bash
GET /rpc/group_list_members?group_name=analysis1_group
Content-Type: application/json
Authorization: Bearer your-jwt

# returns
[{"member": "myuser"}, {"member": "some_analyst"}]
```

- Remove members from a group
```bash
POST /rpc/group_remove_members
Content-Type: application/json
Authorization: Bearer your-jwt

{"memberships": [{"user_name":"myuser", "group_name":"analysis1_group"}]}
```

- Delete a group
```bash
POST /rpc/group_delete
Content-Type: application/json
Authorization: Bearer your-jwt

{"group_name": "analysis1_group"}
# will fail if the group still has members
```

- List all groups belonging to a user
```bash
GET /rpc/user_groups?user_name=myuser
Content-Type: application/json
Authorization: Bearer your-jwt

# returns
[{"group_name": "analysis1_group"}]
```

- Delete a user identity
```bash
POST /rpc/user_delete
Content-Type: application/json
Authorization: Bearer your-jwt

{"user_name": "myuser"}
```

- see an overview of registered users, along with metadata
```bash
GET /registered_users
Content-Type: application/json
Authorization: Bearer your-jwt

# returns {registration_date, user_name, user_type, user_metadata}
```

- see all user defined groups, with metadata
```bash
GET /groups
Content-Type: application/json
Authorization: Bearer your-jwt

# returns {group_name, group_metadata}
```

- As the admin user, see user initiated group removals
```bash
GET /user_initiated_group_removals
Content-Type: application/json
Authorization: Bearer your-jwt

# returns {removal_date, user_name, group_name}
```

- As the admin user, see user data deletion requests
```bash
GET /user_data_deletion_requests
Content-Type: application/json
Authorization: Bearer your-jwt

# returns {user_name, request_date}
```

- get audit information about which data users access data about which data owners, when
```bash
GET /audit_logs
Content-Type: application/json
Authorization: Bearer your-jwt

# return which data user accessed data from which data owner, when
```

### For data owners

- Remove yourself from a group, as a data owner
```bash
POST /rpc/user_group_remove
Content-Type: application/json
Authorization: Bearer your-jwt

{"group_name": "analysis1_group"}
```

- A data owner deletes all their data
```bash
POST /rpc/user_delete_data
Content-Type: application/json
Authorization: Bearer your-jwt
```

- List all groups that one belongs to (as a data owner)
```bash
GET /rpc/user_groups
Content-Type: application/json
Authorization: Bearer your-jwt

# returns {group_name, group_metadata}
```

- Get audit logs about who accessed your data, when
```bash
GET /audit_logs
Content-Type: application/json
Authorization: Bearer your-jwt
```

### For data users

- As the data user `some_analyst`, get data to analyse
```bash
GET /people
Content-Type: application/json
Authorization: Bearer your-jwt

# returns
[{"name": "Frank", "age": 90}]
# all data some_analyst has access to
# as defined by group membership
# for more query capabilities see postgrest docs
```
