
## Consider
- http://postgrest.org/en/v5.0/api.html#accessing-request-headers-cookies
- http://postgrest.org/en/v5.0/api.html#setting-response-headers

## Helpful
- https://www.postgresql.org/docs/9.6/static/errcodes-appendix.html

## TODO
- update http and sql api docs
    - group_create, group_list (metadata),
    - user_groups, new signature, metadata
    - user_group_remove
- document group removal logging view
- metadata for users (so admins can sort and search on this when creating groups), update docs
- separate registration functions for data_owners and data_users
    - use user_create internally, adapt privileges
    - o_ and u_ to indicate owner and user, and to ensure uniqueness in the case where the same person registers for both roles
    - update docs
- RLS policy to only allow data_owners to insert into tables, update model
- document and expose user_data_deletion_requests
- add tests for audit log table
- describe audit log table in readme
- consider how and who to give access to audit logs
- HTTP client tests
- write about the model
- make a presentation, with visual representations of the model

## IP
- data owners: remove themselves from groups and update an accounting table ntk.group_removal_logs

## Done
- review query build statements and input sanitsation - see: https://www.postgresql.org/docs/9.6/static/plpgsql-statements.html
- implement user_groups
- implement user_list (list all users)
- logging table
- add test to ensure we cannot drop internal roles (for users and groups)
- add asserts to test_group_delete for tighter checks
- review consitency of parameter names: group, group_name, user, user_name
- write up SQL API
- separate SQL API and HTTP API into two docs
- move accounting and other internal tables into own schema
- review function, table and view ownership and access - lock down, test
- metadata for groups
- data owners view their group membership, with metadata
- reimplement user_data_deletion_requests as a view, with the table being in ntk schema (similar to group removal logs)
