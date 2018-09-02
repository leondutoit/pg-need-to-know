# pg-need-to-know

A Mandatory Access Control setup for PostgreSQL which takes data ownership seriously.

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

Now you have the following REST API available:

- `/rpc/table_create`
- `/rpc/user_create`
- `/rpc/group_create`
- `/rpc/group_add_members`
- `/rpc/group_list`
- `/rpc/group_list_members`
- `/rpc/group_remove_members`
- `/rpc/group_delete`
- `/rpc/user_delete_data`
- `/rpc/user_delete`

## LICENSE

GPL.
