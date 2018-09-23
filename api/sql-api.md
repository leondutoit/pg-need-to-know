
## Function overview

```sql
-- table operations
table_create(definition json, type text)
table_describe(table_name text, table_description text)
table_describe_columns(table_name text, columns_descriptions json)
table_metadata(table_name text)
table_group_access_grant(table_name text, group_name text)
table_group_access_revoke(table_name text, group_name text)

-- user operations
user_register(user_name text, user_type text, user_metadata json)
user_group_remove(group_name text)
user_groups(user_name text)
user_delete_data()
user_delete(user_name text)

-- group operations
group_create(group_name text, group_metadata json)
group_add_members(group_name text, memberships json, metadata json, add_all boolean)
group_list_members(user_name text)
group_remove_members(group_name text, memberships json, metadata json, remove_all boolean)
group_delete(group_name text)
```

## Views and tables

```sql
table_overview
user_registrations
groups
event_log_user_group_removals
event_log_user_data_deletions
event_log_data_access
event_log_access_control
```

For details of usage see `testing.sql`.
