# pg-need-to-know

A useful Mandatory Access Control setup for PostgreSQL.

- Anyone can insert data (so your app can collect data)
- Data owners are the only ones who can operate on their data by default (select, update, delete)
- Read-only access can be granted to others based on common group membership

## Features

- create tables `table_create` with MAC policies
- register data owners `user_create` before data collection
- create groups `group_create`
- add mmembers to groups `group_add_members`
- remove members from groups `group_remove_members`, using `revoke`
- delete groups `group_delete`
- user deletes their own data `user_delete_data`

## Creating a REST API

Use postgrest.

## LICENSE

GPL.
