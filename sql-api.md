
## Function overview

```sql
table_create(definition json, type text)
user_register(user_name text, user_type text, user_metadata json)
user_create(user_name text, user_type text, user_metadata json)
group_create(group_name text)
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
registered_users
groups
user_initiated_group_removals
user_data_deletion_requests
audit_logs
```

For details of usage see `testing.sql`.
