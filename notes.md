
## Consider
- http://postgrest.org/en/v5.0/api.html#accessing-request-headers-cookies
- http://postgrest.org/en/v5.0/api.html#setting-response-headers

## Helpful
- https://www.postgresql.org/docs/9.6/static/errcodes-appendix.html

## TODO
- expose audit logs to data owners and admin via RLS and a view
- add tests for audit log table
- describe audit log table in readme
- consider how and who to give access to audit logs
- test permissions on informational views
- full review of docs
- write about the model
- HTTP client tests
- make a presentation, with visual representations of the model

## IP
- add informational views in http api overview, with explanations
- RLS policy to only allow data_owners to insert into tables, update model

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
- data owners: remove themselves from groups and update an accounting table ntk.group_removal_logs
- test anon permissions on user_group_remove
- update http and sql api docs
    - group_create, group_list (metadata)
- document group removal logging view
- document user_data_deletion_requests
- metadata for users (so admins can sort and search on this when creating groups), update docs, registation date
- registration function for data_owners and data_users
    - exec as anon
    - use user_create internally, adapt privileges
    - require and enforce owner_ and user_ to indicate owner and user, and to ensure uniqueness in the case where the same person registers for both roles
    - update docs (http api - with new naming conventions)
- give admin_user access to registered user via a view, remove user_list function
- replace group_list with a groups view
