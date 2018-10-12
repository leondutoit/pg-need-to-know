
# Implementation

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

And because the `table_create` function is executed as the `admin_user` role, user-created tables are owned by the `admin_user`. Now we can discuss the details of the table definition.

### Internal columns

The three columns, `row_id`, `row_owner`, and `row_originator` are default columns, created and maintend by `pg-need-to-know`. The `row_id` column is simple a sequence of integers, which allows audit records to refer to specific rows in tables. Both the `row_owner` and `row_originator` columns have default values set to the session variable `request.jwt.claim.user`.

As discussed in previous sections, the REST API extracts the `user` claim from the JWT, and sets the session variable to that value. The implication is that those rows will be filled with the authenticated `user` claim's value. This is how ownership is identified. By default, row owners are the same as row originators, but as we will see later, this does not have to be the case.

Both the `row_owner` and `row_originator` columns have foreign key constraints, referencing the `_user_name` column in the `ntk.registered_users` table. This is how `pg-need-to-know` enforces that only registered users can upload data.

### Row level security policies

- admin user
- data owners
- data users

### Auditing

- update trigger
