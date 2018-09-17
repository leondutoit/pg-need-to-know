
## Function overview

```sql
table_create(definition json, type text)
table_describe(text, text)
table_describe_columns(text, text, text)
table_metadata(text)
user_register(user_name text, user_type text, user_metadata json)
group_create(group_name text)
table_group_access_grant(text, text)
table_group_access_revoke(text, text)
group_add_members(members json)
group_list_members(user_name text)
user_group_remove(group_name text)
group_remove_members(members json)
group_delete(group_name text)
user_groups(user_name text)
user_delete_data()
user_delete(user_name text)
```

## Views

```sql
table_overview
user_registrations
groups
user_group_removals
user_data_deletions
audit_logs
```

For details of usage see `testing.sql`.
