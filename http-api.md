
## Method overview

```txt
HTTP Method     | URL                                       | required role
----------------|-------------------------------------------|--------------
POST            | /rpc/table_create                         | admin_user
POST            | /rpc/user_create                          | admin_user
POST            | /rpc/group_create                         | admin_user
POST            | /rpc/group_add_members                    | admin_user
GET             | /rpc/group_list                           | admin_user
GET             | /rpc/group_list_members?group_name=<name> | admin_user
GET             | /rpc/user_list                            | admin_user
POST            | /rpc/user_group_remove                    | data owner
POST            | /rpc/group_remove_members                 | admin_user
POST            | /rpc/group_delete                         | admin_user
GET             | /rpc/user_groups?user_name=<name>         | admin_user
GET             | /rpc/user_groups                          | data owner
POST            | /rpc/user_delete_data                     | data owner
POST            | /rpc/user_delete                          | admin_user
```


## REST API

- Create a new table
```bash
POST /rpc/table_create
Content-Type: application/json
Authorization: Bearer your-jwt

{"definition": {"table_name": "people", "columns": [ {"name": "name", "type": "text"}, {"name": "age", "type": "int"} ]}, "type": "mac" }
```

- Create a new user, either a data owner, or a data user
```bash
POST /rpc/user_create
Content-Type: application/json
Authorization: Bearer your-jwt

{"user_name": "myuser", "type": "data_owner"}
# or
{"user_name": "some_analyst", "type": "data_user"}
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

- List all groups in the db
```bash
GET /rpc/group_list
Content-Type: application/json
Authorization: Bearer your-jwt

# returns
[{"group_name": "analysis1_group", "group_metadata": {"consent_reference": 1}}]
```

- List all members in a specific group
```bash
GET /rpc/group_list_members?group_name=analysis1_group
Content-Type: application/json
Authorization: Bearer your-jwt

# returns
[{"member": "myuser"}, {"member": "some_analyst"}]
```

- List all users
```bash
POST /rpc/user_list
Content-Type: application/json
Authorization: Bearer your-jwt

# returns
[{"user_name": "myuser", "user_type": "data_owner"}, {"user_name": "some_analyst", "user_type": "data_user"}]
```

- Remove yourself from a group, as a data owner
```bash
POST /rpc/user_group_remove
Content-Type: application/json
Authorization: Bearer your-jwt

{"group_name": "analysis1_group"}
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

- List all groups that one belongs to (as a data owner)
```bash
GET /rpc/user_groups
Content-Type: application/json
Authorization: Bearer your-jwt

# returns {group_name, group_metadata}
```

- A data owner deletes all their data
```bash
POST /rpc/user_delete_data
Content-Type: application/json
Authorization: Bearer your-jwt
```

- Delete a user identity
```bash
POST /rpc/user_delete
Content-Type: application/json
Authorization: Bearer your-jwt

{"user_name": "myuser"}
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
