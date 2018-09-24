
## Using the HTTP API

The last example in  `1-access-control-model.md` showed how an administrator can use `pg-need-to-know` to set up access control rules based on data owners and data subsets, in a conceptual way. The rest of this document shows how one would use the HTTP API (provided by running `postgrest`) to implement this.

## Create tables

Firstly the admin created tables `t1, t2, t3, t4`.

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
    "user_name": "owner_A",
    "user_type": "data_owner",
    "user_metadata": {
        "institution": 1,
        "consent_reference": 6789
    }
}

# for data users
{
    "user_name": "user_X",
    "user_type": "data_user",
    "user_metadata": {
        "institution_consent": 1
    }
}
```

Notice that data owners' user names _must_ be prefixed with `owner_` and data users' user names _must_ be prefixed with `user_`. This is to allow two things: 1) that the same person, with some external ID, might be able to register as both an owner and a user, and 2) to ensure that the names are consistent with PostgreSQL's requirements for internal role names.

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
    "metadata": {
        "key": "institution",
        "value": "1"
    }
}

# and:
{
    "group_name": "group2",
    "metadata": {
        "key": "institution",
        "value": "2"
    }
}

# 2.2 data users
{
    "group_name": "group2",
    "members": ["user_Z"]
}
```

Note that one can add members based on metadata values, naming them directly, or as documented in the api refernce, by adding everyone to a group.

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

- see who is using their data
- revoke data access
- delete data

## Audit information for administrators

Event logs:
- data access
- access control
- group removals
- data deletions

## Change access control
