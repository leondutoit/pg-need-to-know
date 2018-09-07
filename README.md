# pg-need-to-know

A Mandatory Access Control setup for PostgreSQL which takes data ownership seriously, and allows data owners to make their data available to data users on a need to know basis.


## Features

- Any registered data owner can insert data (registation is needed to enforce ownership)
- Data owners are the only ones who can operate on their data by default (select, update, delete)
- Read-only access can be granted to data users based on common group membership (data owner can never see the data of other data owners)
- All data access must specify columns explicitly, since those containing access control and identity information are protected
- Data owners can delete all their data at any time


## Creating the DB schema

```bash
# run this as the DB superuser
psql -d yourdb -1 -f need-to-know.sql

# run sql tests
psql -d yourdb -1 -f testing.sql
```

## Create a REST API using postgrest

- Download and install [postgrest](http://postgrest.org/)
- Create a [config file](http://postgrest.org/en/v5.0/install.html#configuration)
- Run `postgrest your-config-file`
- Using this API pre-supposes that you have an Identity Provider and an Authentication Server which can issue JSON Web Tokens (read more about the requirements for this in the description of the MAC model)


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
POST            | /rpc/group_remove_members                 | admin_user
POST            | /rpc/group_delete                         | admin_user
GET             | /rpc/user_groups?user_name=<name>         | admin_user
POST            | /rpc/user_delete_data                     | the data owner
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

{"group_name": "analysis1_group"}
```

- Add members to the group to enable data access
```bash
POST /rpc/group_add_members
Content-Type: application/json
Authorization: Bearer your-jwt

{"memberships": [{"user":"myuser", "group":"analysis1_group"}, {"user":"some_analyst", "group":"analysis1_group"}]}
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
[{"group_name": "analysis1_group"}]
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

- Remove members from a group
```bash
POST /rpc/group_remove_members
Content-Type: application/json
Authorization: Bearer your-jwt

{"memberships": [{"user":"myuser", "group":"analysis1_group"}]}
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

## LICENSE

GPL.
