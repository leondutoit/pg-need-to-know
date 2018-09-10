
## Consider
- http://postgrest.org/en/v5.0/api.html#accessing-request-headers-cookies
- http://postgrest.org/en/v5.0/api.html#setting-response-headers

## Helpful
- https://www.postgresql.org/docs/9.6/static/errcodes-appendix.html

## TODO
- document and expose user_data_deletion_requests
- add tests for audit log table
- describe audit log table in readme
- consider how and who to give access to audit logs
- move accounting and other internal tables into own schema
- write up SQL API
- separate SQL API and HTTP API into two docs
- HTTP client tests
- write about the model
- make a presentation, with visual representations of the model

## IP
- review function, table and view ownership and access - lock down
- group_add,remove_members - allow data owners to remove themselves
    - and corresponding right grant and revoke
    - and update tests accordingl

## Done
- review query build statements and input sanitsation - see: https://www.postgresql.org/docs/9.6/static/plpgsql-statements.html
- implement user_groups
- implement user_list (list all users)
- logging table
- add test to ensure we cannot drop internal roles (for users and groups)
- add asserts to test_group_delete for tighter checks
- review consitency of parameter names: group, group_name, user, user_name
