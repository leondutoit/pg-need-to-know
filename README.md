# pg-need-to-know

A useful Mandatory Access Control setup for PostgreSQL.

- Anyone can insert data (so your app can collect data)
- Data owners are the only ones who can operate on their data by default (select, update, delete)
- Read-only access can be granted to others based on common group membership
- All data access must specify specific columns, since those containing access control and identity information are protected

## Creating a REST API using postgrest

- `/rpc/table_create`
- `/rpc/user_create`
- `/rpc/group_create`
- `/rpc/group_add_members`
- `/rpc/group_remove_members`
- `/rpc/group_delete`
- `/rpc/user_delete_data`

## LICENSE

GPL.
