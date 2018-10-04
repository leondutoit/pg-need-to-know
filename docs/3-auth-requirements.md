
## Assumptions

- anyone can be a data owners
- only some can be data users
- only some can be admin users

Given these assumptions, `pg-need-to-know` does not provide any authentication mechanisms. It is up to applications to integrate with other identity providers and authentication servers to establish the authenticity of persons, and to determine whether the person is authorized to be a data user or a data owner. `pg-need-to-know` therefore assumes that identity management, and rights management associated with data users and admin users is handled by external systems. This also means that applications can perform authentication and authorization using any mechanism they want. `pg-need-to-know` does not force anything.

`pg-need-to-know` does, however, provide a token endpoint which issues JWT for the three role types: `data_owner`, `data_user`, and `admin_user`. The only checks that are performed when issuing tokens are whether the identities of the data owner and user for which tokens are being requested, exist. This is not for the purpose of authentication though, but merely to prevent subsequent requests from being made, because they will fail (owners and users must be registered first).

It is also possible for applications to implement token issuing themselves, instead of using `pg-need-to-know`'s endpoint.

## Integration

The process can be represented as follows:

```txt
# 1. Generic user authentication
User (credentials) -> app -> IdP + Auth Server (rights management)
                          <- ID

# 2. Getting an access token with an authenticated and authorized ID
                      app -> GET /rpc/token?user_id=<id>&token_type=<admin,owner,user>
                          <- JWT {exp:exp, role:role, user:user_id}

# 3. An authenticated request
HTTP + JWT -> postgrest (authenticator) -> DB (role + session variable): SQL (security context)
           <- HTTP response             <- authorized dataset
```

Firstly, apps must authenticate end-users, and determine their rights: whether they are data owners, data users, or admin users. Presumably, the IdP and Authentication Server will return some form of user ID, if the authentication is successful. This is the step where applications must determine whether the person has the right to request a data owner, data user, or admin user token. It may well be the case that different authentication systems are used for different roles.

Secondly, the app can get a token by doing `GET /rpc/token?user_id=<id>&token_type=<admin,owner,user>` - an endpoint provided by `pg-need-to-know`. If a token for a data user or data owner is being requested `pg-need-to-know` will check if the person has registered. If an admin token is requested, no check will be done. This emphasises the importance of managing rights in another system. The app will then receive a JWT with an expiry, and a role which is compatible with `pg-need-to-know`'s requirements. _Please note this is NOT authentication or authorization, the app is reponsible for establishing the authenticity of persons, and whether they are allowed to get specific token types._

Lastly, the app can then include the JWT in the Authorization header in the following HTTP request. `postgrest` will then switch into the provided role, set a session variable called `request.jwt.claim.user` to the value of the `user` claim, and execute the implied SQL in the role's security context, thereby enforcing authorization. An authorized dataset will be returned in the HTTP response.

## Tokens, roles and postgrest

`pg-need-to-know` was designed to be used with `postgrest` - an application server which creates a REST API from a PostgreSQL database. `postgrest` uses JWT to integrate with authentication systems. The following claims _must_ be present in the JWT:

```json
{
    "role": "some_role",
    "user": "some_id",
    "exp": 210849818
}
```

The `exp` field is the time when the token should expire. In practice, tokens should be short-lived. `pg-need-to-know` issues tokens which are valid for 30 minutes.

The `role` claim plays a very specific role in `postgrest`: before the SQL query implied by the HTTP request is executed, `postgrest` switches into the role provided in the claim. In `pg-need-to-know`, `postgrest` is intended to connect to the DB with a role called the `authenticator`. This is a special role which has not other rights in the DB, other than the ability to connect to it, and to switch to other roles. By switching to the role provided in the JWT claim before executing the SQL query implied by the HTTP request, postgrest ensures that the DB system enforces security policies associated with that role. The functions in `pg-need-to-know` use the identity information carried in the `user` claim to enforce authorization policies, in addition to roles.

## Establishing trust with apps

To ensure that only trusted applications integrate with your instance of `pg-need-to-know` one can do two simple things:

1. Run postgrest behing an nginx proxy and limit direct API requests to a specific IP or IP range
2. Additionally, have a shared secret between the app and `pg-need-to-know`, which can be sent in a request header, and validated in a `postgrest` pre-request handler

`pg-need-to-know` does not make any design decision about this either way, so it is up to the developer to decide and implement a solution.

## Own REST API implementations and authentication

If you wanted to implement your own token generation endpoint, you must therefore conform to the above requirements. And if you wanted to implement your own REST API, consuming `pg-need-to-know`'s SQL API, then you need to also perform DB connection and SQL queries in a similar way to `postgrest`.
