
# Implementation

## An example table

The best place to start is to look at an example of a table created with `pg-need-to-know`:

```sql
                                         Table "public.t2"
     Column     |  Type   | Collation | Nullable |                     Default
----------------+---------+-----------+----------+-------------------------------------------------
 row_id         | integer |           | not null | nextval('t2_id_seq'::regclass)
 row_owner      | text    |           | not null | current_setting('request.jwt.claim.user'::text)
 row_originator | text    |           | not null | current_setting('request.jwt.claim.user'::text)
 votes          | text    |           |          |
 orientation    | text    |           |          |
 outlook        | text    |           |          |
Foreign-key constraints:
    "t2_row_originator_fkey" FOREIGN KEY (row_originator) REFERENCES ntk.registered_users(_user_name)
    "t2_row_owner_fkey" FOREIGN KEY (row_owner) REFERENCES ntk.registered_users(_user_name)
Policies (forced row security enabled):
    POLICY "row_originator_update_policy" FOR UPDATE
      USING (ntk.is_row_originator(row_originator))
    POLICY "row_ownership_delete_policy" FOR DELETE
      USING (ntk.is_row_owner(row_owner))
    POLICY "row_ownership_insert_policy" FOR INSERT
      WITH CHECK (true)
    POLICY "row_ownership_select_group_policy" FOR SELECT
      USING (ntk.roles_have_common_group_and_is_data_user(row_owner))
    POLICY "row_ownership_select_policy" FOR SELECT
      USING (ntk.is_row_owner(row_owner))
    POLICY "row_ownership_update_policy" FOR UPDATE
      USING (ntk.is_row_owner(row_owner))
Triggers:
    update_trigger AFTER UPDATE ON t2 FOR EACH ROW EXECUTE PROCEDURE ntk.log_data_update()
```

In addition, the following access rules apply by default:

```sql
grant select, insert, update, delete on t2 to data_owners_group
```

And because the `table_create` function is executed as the `admin_user` role, user-created tables are owned by the `admin_user`.

## Table access rules

Now we can discuss the details of the table definition.
