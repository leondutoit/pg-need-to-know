
## Method overview

For the anon role:
```txt
HTTP Method     | URL
----------------|-------------------
POST            | /rpc/user_register
GET             | /rpc/token?id=id&token_type=<admin,owner,user>
```

For admin_user role:
```txt
HTTP Method     | URL
----------------|-------------------------------------------
POST            | /rpc/table_create
POST            | /rpc/table_describe
POST            | /rpc/table_describe_columns
GET             | /rpc/table_metadata?table_name=<name>
POST            | /rpc/table_group_access_grant
POST            | /rpc/table_group_access_revoke
POST            | /rpc/group_create
POST            | /rpc/group_add_members
GET             | /rpc/group_list_members?group_name=<name>
POST            | /rpc/group_remove_members
POST            | /rpc/group_delete
GET             | /rpc/user_groups?user_name=<name>
POST            | /rpc/user_delete
GET             | /table_overview
GET             | /user_registrations
GET             | /groups
GET             | /event_log_user_group_removals
GET             | /event_log_user_data_deletions
GET             | /event_log_data_access
GET             | /event_log_access_control
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

{"user_id": "12345", "type": "data_owner", "user_metadata": {"some": "info"}}
# or
{"user_id": "some_analyst", "type": "data_user", "user_metadata": {"some": "info"}}
```

- _After authenticating a user and authorizing their role_, get a token
```bash
GET /rpc/token?id=id&token_type=<admin,owner,user>
```

### For admins

- Create a new table
```bash
POST /rpc/table_create
Content-Type: application/json
Authorization: Bearer your-jwt

{"definition": {
    "table_name": "people",
    "description": "a collection of data on people",
    "columns": [
        {"name": "name", "type": "text", "description": "First name"},
        {"name": "age", "type": "int", "description": "Age in years"}
    ]},
"type": "mac" }
```

- describe your table, or change the existing description
```bash
POST /rpc/table_describe
Content-Type: application/json
Authorization: Bearer your-jwt

{"table_name": "people", "description": "some people"}
```

- describe your table columns, or change existing ones
```bash
POST /rpc/table_describe_columns
Content-Type: application/json
Authorization: Bearer your-jwt

{"table_name": "people", "column_descriptions": [{"column_name": "name", "description": "First name"}]}
```

- get column descriptions for a table
```bash
GET /rpc/table_metadata?table_name=<name>
Content-Type: application/json
Authorization: Bearer your-jwt

# returns [{column, description}, ...]
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

- Add members to the group to enable data access (choose one of three methods)
```bash
POST /rpc/group_add_members
Content-Type: application/json
Authorization: Bearer your-jwt

# 1. by naming specific user
{"group_name": "analysis1_group",
 "memberships": ["myuser", "some_analyst"]}

# 2. selecting users into the group based on metadata values
{"group_name": "analysis1_group",
 "metadata": {"key": "some", "value": "info"}}

# 3. add all existing users to a group
{"group_name": "analysis1_group",
 "add_all": true}

# 4. add all existing data owners to a group
{"group_name": "analysis1_group",
 "add_all_owners": true}

# 5. add all existing data users to a group
{"group_name": "analysis1_group",
 "add_all_users": true}
```

- Grant group access to a table
```bash
POST /rpc/table_group_access_grant
Content-Type: application/json
Authorization: Bearer your-jwt

# grant_types: select, insert, update
{"table_name": "people", "group_name": "analysis1_group", "grant_type": "select"}
```

- Revoke group access from a table
```bash
POST /rpc/table_group_access_revoke
Content-Type: application/json
Authorization: Bearer your-jwt

# grant_types: select, insert, update
{"table_name": "people", "group_name": "analysis1_group", "grant_type": "select"}
```

- List all members in a specific group
```bash
GET /rpc/group_list_members?group_name=analysis1_group
Content-Type: application/json
Authorization: Bearer your-jwt

# returns
[{"member": "myuser"}, {"member": "some_analyst"}]
```

- Remove members from a group (choose one of three methods)
```bash
POST /rpc/group_remove_members
Content-Type: application/json
Authorization: Bearer your-jwt

# 1. by naming specific user
{"group_name": "analysis1_group",
 "memberships": ["myuser", "some_analyst"]}

# 2. selecting users into the group based on metadata values
{"group_name": "analysis1_group",
 "metadata": {"key": "some", "value": "info"}}

# 3. add all existing users to a group
{"group_name": "analysis1_group",
 "remove_all": true}
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

- see table overview: name, description, group access
```bash
GET /table_overview
Content-Type: application/json
Authorization: Bearer your-jwt
```

- see an overview of registered users, along with metadata
```bash
GET /user_registrations
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
GET /event_log_user_group_removals
Content-Type: application/json
Authorization: Bearer your-jwt

# returns {removal_date, user_name, group_name}
```

- As the admin user, see user data deletion requests
```bash
GET /event_log_user_data_deletions
Content-Type: application/json
Authorization: Bearer your-jwt

# returns {user_name, request_date}
```

- get audit information about which data users access data about which data owners, when
```bash
GET /event_log_data_access
Content-Type: application/json
Authorization: Bearer your-jwt

# return which data user accessed data from which data owner, when
```

- get audit information about all group-based access control events
```bash
GET /event_log_access_control
Content-Type: application/json
Authorization: Bearer your-jwt

# returns {event_date,event_type,group_name,event_metadata}
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
GET /event_log_data_access
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
