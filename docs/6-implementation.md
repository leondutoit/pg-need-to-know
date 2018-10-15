
# Implementation

## Tables

The best place to start is to look at an example of a table created with `pg-need-to-know`:

```sql
                                       Table "public.t2"
     Column     | Type | Collation | Nullable |                     Default
----------------+------+-----------+----------+-------------------------------------------------
 row_id         | uuid |           | not null | gen_random_uuid()
 row_owner      | text |           | not null | current_setting('request.jwt.claim.user'::text)
 row_originator | text |           | not null | current_setting('request.jwt.claim.user'::text)
 votes          | text |           |          |
 orientation    | text |           |          |
 outlook        | text |           |          |
Check constraints:
    "t2_row_originator_check" CHECK (row_originator = current_setting('request.jwt.claim.user'::text))
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
      USING (ntk.roles_have_common_group_and_is_data_user(row_id, row_owner))
    POLICY "row_ownership_select_policy" FOR SELECT
      USING (ntk.is_row_owner(row_owner))
    POLICY "row_ownership_update_policy" FOR UPDATE
      USING (ntk.is_row_owner(row_owner))
Triggers:
    immutable_trigger BEFORE UPDATE ON t2 FOR EACH ROW EXECUTE PROCEDURE ntk.ensure_internal_columns_are_immutable()
    update_trigger AFTER UPDATE ON t2 FOR EACH ROW EXECUTE PROCEDURE ntk.log_data_update()
```

In addition, the following access rules apply by default:

```sql
grant select, insert, update, delete on t2 to data_owners_group
```

And because the `table_create` function is executed as the `admin_user` role, user-created tables are owned by the `admin_user`. Now we can discuss the details of the table definition.

### Internal columns

The three columns, `row_id`, `row_owner`, and `row_originator` are default columns, created and maintend by `pg-need-to-know`. The `row_id` column contains Universally Unique Identifier (UUID), which allows audit records to refer to specific rows in tables. Both the `row_owner` and `row_originator` columns have default values set to the session variable `request.jwt.claim.user`.

As discussed in previous sections, the REST API extracts the `user` claim from the JWT, and sets the session variable to that value. The implication is that those rows will be filled with the authenticated `user` claim's value. This is how ownership is identified. By default, row owners are the same as row originators, but this does not have to be the case. The `row_originator` has an additional check constraint ensuring that it is _always_ set to the value of the current session user.

Both the `row_owner` and `row_originator` columns have foreign key constraints, referencing the `_user_name` column in the `ntk.registered_users` table. This is how `pg-need-to-know` enforces that only registered users can upload data.

Lastly, the `immutable_trigger` ensures that all three internal columns cannot be changed once their values are set.

### Row level security policies

The first important detail to note is: `(forced row security enabled)`. This means that the table owner, the `admin_user`, cannot bypass the security policies. This is an integral part of the access control system. `admin_user`s actually do not have access to the data at all. They have to register as data users just like anyone else if they want access.

Now let's consider the policies that apply to data owners. There are four relevant policies, each on a different SQL operation: `insert`, `select`, `update`, and `delete`. The policy on insert always evaluates to `true`. In combination with the foreign key constraints this means that any data owner can insert data, if registered. The remaining three policies simply check that the value in the `row_owner` column matches the value set in `request.jwt.claim.user` - in other words, that the authenticated request has been initiated by the owner of the data.

Recall that all these SQL operations were granted to the `data_owners_group`. This group has a role called `data_owner` as a member. All SQL operations done by authenticated data owners, must be executed as this DB role. The API, therefore switches into this role, `request.jwt.claim.user` sets the session variable, and then executes the query. The implication is that some external authentication system has to determine which people have the right to be assigned the `data_owner` role.

Lastly, let's look at the data user policies. The only policy that is specified is for `select`, and is called `row_ownership_select_group_policy`. This invokes a function called `ntk.roles_have_common_group_and_is_data_user` which does what it says: it checks whether the session user and the row owner are in the same group. If so, then the select is granted.

Notice though that there is no DB group or role granting data users access to the table - by default, data users do not have any access to data. This is where explicit table grants become relevant.

### Auditing

The trigger function on the table updates an audit log with information about changes made to data when updating rows. The `ntk.roles_have_common_group_and_is_data_user` function also logs which data user sees data about which data owner.

## Groups and table grants

Databases with `pg-need-to-know` installed have a `data_users_group` and `data_user` role. As the previous section about tables explained, data users to not have table access, or row access by default. Administrators can, however, use groups to give table and row access to data users.

Firstly, a new group must be created, using the `pg-need-to-know` API. Then, the administrator can add members, and grant either `select`, `insert`, and/or `update` access to the table for the group. What happens in the background is that the `data_users_group` is then given the necessary permissions on the table, and this is inherited by its members. Revoking access works in the same way.

These policies then combine with the existing row-level security policies which ensure that data users can only `select` from rows where they share group membership with data owners. `update` grants are also quite narrow: data users can only update rows which they have inserted themselves.
