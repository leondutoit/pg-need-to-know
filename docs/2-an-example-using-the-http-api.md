
## Using the HTTP API

The last example in  `1-access-control-model.md` showed how an administrator can use `pg-need-to-know` to set up access control rules based on data owners and data subsets, in a conceptual way. The rest of this document shows how one would use the HTTP API (provided by running `postgrest`) to implement this.

## Create tables

Firstly the admin creates tables `t1, t2, t3, t4`.

```bash
POST /rpc/table_create
Content-Type: application/json
Authorization: JWT-for-admin-user

{
    "table_name", "t1",
    "description": "demographic data about the respondents",
    "columns": [
        {"name", "country",
         "type": "text",
         "description": "Current country in which the respondent lives"
        },
        {"name", "education",
         "type": "int",
         "description": "Number of years of education"
        }
    ]
}
```

And so on with `t2, t3, t4`.

## Register users

Next, data owners `A, B, D, C, E, F` and data users `X, Y, Z` need to register.

```bash
POST /rpc/user_register
Content-Type: application/json
Authorization: JWT-for-anon-user

# for data owners
{
    "user_id": "A",
    "user_type": "data_owner",
    "user_metadata": {
        "institution": 1,
        "consent_reference": 6789
    }
}

# for data users
{
    "user_id": "X",
    "user_type": "data_user",
    "user_metadata": {
        "institution_consent": 1
    }
}
```

Internally, the `user_id` is appened to either `owner_` or `user_` and then a PostgreSQL role is created using that name. This means that even though registering a user with an ID of `A`, listing users by doing `GET /user_registrations`, the user name that will be returned will be `owner_A`.

Now recall that we need to set up the following groups:

```txt
group1
    - members: ((X, Y), (A, B, C, D))
    - table access grants: (t1, t2, t3)
group2
    - members: ((Z), (A, B, C, D, E, F))
    - table access grants: (t1, t2, t3, t4)
```

We will further suppose that owners `A, B, C, D`, belong to institution `1`, and owners `E, F` to institution `2`, and that they have consented to their data being analysed by users who have been granted access by their institution. This is indicated in the `user_metadata` fields in the example above. Later on, this metadata will be used to define group members.

The administrator should, therefore, carefully consider what type of metadata to collect at the time of user registration, since this is useful in access control management.

## Collect data

Owners can send data to `pg-need-to-know` via the HTTP API, and presumable some application that consumes the API in the following way:

```bash
POST /t1
Content-Type: application/json
Authorization: JWT-for-data-owner

{"country": "Tuvalu", "education": 18}
```

## Implement access control rules

Now the groups can be created, filled with members, and granted access to tables.

```bash
POST /rpc/group_create
Content-Type: application/json
Authorization: JWT-for-admin-user

# for institution 1
{
    "group_name": "group1",
    "group_metadata": {
        "consent_reference": 6789
        "institution": "1"
    }
}

# for institution 2
{
    "group_name": "group2",
    "group_metadata": {
        "consent_reference": 1009
        "institution": "2"
    }
}
```

Now the groups can get members:

```bash
POST /rpc/group_add_memebers
Content-Type: application/json
Authorization: JWT-for-admin-user

# 1. for members: ((X, Y), (A, B, C, D))
# 1.1 data owners
{
    "group_name": "group1",
    "metadata": {
        "key": "institution",
        "value": "1"
    }
}

# 1.2 data users
{
    "group_name": "group1",
    "metadata": {
        "key": "institution_consent",
        "value": "1"
    }
}

# 2. for members: ((Z), (A, B, C, D, E, F))
# 2.1 data owners
{
    "group_name": "group2",
    "add_all_owners": true
}

# 2.2 data users
{
    "group_name": "group2",
    "members": ["user_Z"]
}
```

Note the different methods for adding group members. A complete reference can be found in the api docs.

Finally, to ensure access the groups must be granted access to the tables:

```bash
POST /rpc/table_group_access_grant
Authorization: JWT-for-admin-user

{
    "table_name": "t1",
    "group_name": "group1",
    "grant_type": "select"
}
```

And similar for the rest of the tables and groups.

## Analyse data

Data users `X, Y` can now select data from tables `t1, t2, t3` and the administrator will know that they can only retrieve data from owners `A, B, C, D`, e.g.:

```bash
GET /t1
Authorization: JWT-for-data-user
```

Data user `Z` can select data from all tables, and get data from all owners, e.g.:

```bash
GET /t1
Authorization: JWT-for-data-user
```

## Data owner actions

Data owners can see who is using their data by checking event logs:

```bash
GET /event_log_data_access
Authorization: JWT-for-data-owner
```

They can also decide to revoke access to their data from a specific group, by removing themselves from the group:

```bash
POST /rpc/user_group_remove
Authorization: JWT-for-data-owner

{
    "group_name": "group1"
}
```

Lastly, they can delete their data:

```bash
POST /rpc/user_delete_data
Authorization: JWT-for-data-owner
```

Both the user-initiated group removal and data deletion will be recorded in event log tables.

## Audit information for administrators

Administrators can get an overview of all important events that occur in the DB. They can see all data access that has taken place - which data user accessed data from which data owner, when:

```bash
GET /event_log_data_access
Authorization: JWT-for-admin-user
```

An overview of all access control events (group creation, deletion, membership changes):

```bash
GET /event_log_access_control
Authorization: JWT-for-admin-user
```

Which users removed themselves from groups, and when:

```bash
GET /event_log_user_group_removals
Authorization: JWT-for-admin-user
```

Which user deleted their data, when:

```bash
GET /event_log_user_group_removals
Authorization: JWT-for-admin-user
```

All data changes which have been made using updates:

```bash
GET /event_log_data_updates
Authorization: JWT-for-admin-user
```

The group removal and data deletion event logs are useful to help administrators follow up by deleting downstream data artefacts which may still contain the identity of the person who deleted their data.

## Change access control

Suppose data owner `E` deleted their data, and the consent for `group1` has expired. The administrator can now manage the access control setup by deleting data owner `E`, and `group1`.

```bash
POST /rpc/user_delete
Authorization: JWT-for-admin-user

{
    "user_id": "owner_E",
    "user_type": "data_owner"
}
```

First, all members should be removed from the group:

```bash
POST /rpc/group_remove_members
Authorization: JWT-for-admin-user

{
    "group_name": "group1",
    "remove_all": true
}
```

Then it can be deleted:

```bash
POST /rpc/group_delete
Authorization: JWT-for-admin-user

{
    "group_name": "group1",
}
```

## Publishing data

A common use case is to make data available to owners after analysis. This can be accomplished in the following way: 1) grant data users insert and update rights on a table, 2) register the user who should see the published data, and 3) set the `row_owner` column to the identity of the intended recipient.

Firstly, grant insert and update rights:
```bash
POST /rpc/table_group_access_grant
Authorization: JWT-for-admin-user

{
    "table_name": "t1",
    "group_name": "group1",
    "grant_type": "update"
}
```
Secondly, register the intended recipient, if not already registered, using the same method described above. Lastly, insert the data and set the `row_owner` column to the identity of the recipient:
```bash
POST /t1
Content-Type: application/json
Authorization: JWT-for-data-user

{"country": "Sudan", "education": 12}


PATCH /t1?country=Sudan
Content-Type: application/json
Authorization: JWT-for-data-owner

{"row_owner": "the-new-owner"}
```

A real case woulc probably have a better way of identifying rows which need to be updated. Be that as it may, now only the owner can see this data.

## Further reading

Please refer to the references in `/api`, after reading through the rest of the docs.
