
## Consider
- http://postgrest.org/en/v5.0/api.html#accessing-request-headers-cookies
- http://postgrest.org/en/v5.0/api.html#setting-response-headers

## Helpful
- https://www.postgresql.org/docs/9.6/static/errcodes-appendix.html

## Maybes
- expiry dates on groups - to coincide with consent constraints
    - if compulsory, then need the ability to change the end date too
    - and update the RLS function to check the end date

## TODO
- add assert false to tests for more robust checks
- log all updates: person, time, table, colname, old, new
    - see: https://wiki.postgresql.org/wiki/Audit_trigger
- test that table creation is idempotent, and can add new columns
- make a presentation, with visual representations of the model

## IP
- HTTP client tests (correctness, and configurable scalability tests)

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
- add informational views in http api overview, with explanations
- only allow data_owners to insert into tables, update model
- move functions into ntk - which should not be exopsed to the api
- expose audit logs to data owners and admin via RLS
- describe audit log table in readme
- rename informational tables and views to be more consistent
- enforce group level table access and implement grant and revoke
- create table_information view, document
- add table descriptions using comments, ability to change them, show in table_information
- add ability to retrieve table columns and comments
- add ability to comment on columns, and add/modify them later
- test metadata
- test group access management
- test audit log table - access rules, content
- test permissions on informational views
- delete audit logs from tests in teardown
- ability to add (remove) group members based on user metadata vals (and all users), add tests
- rename audit_logs -> event_log_data_access
- event_log_access_control
- test event_log_access_control
- make code DRYer - utility functions for common asserts (like user and groups)
- write about the model - on MAC, three use cases - data organisation up to the admin
- write about auth requirements
- implement /rpc/token, document
- for group_add, also provide: all_owners, and all_users
- remove hard-coded non-generic names check all todos
- fix return type in /rpc/token
- default data access policies:
    - table grant types: read, write so that users can be granted the right to insert and/or update
    - this can be used to "publish data" - set the owner explicitly to the person for whom it is being published
    - `table_policy_grant(table, type<select,insert,update>, user_type<data_owner,data_user>)`
