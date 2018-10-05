
## Guidelines

- Your app should connect to postgres as the `authenticator`
- If a HTTP request arrives without an Authorization header, then after connecting to the DB, the implied SQL query should be executed as the `anon` role
- Authenticated requests, which have an Authorization header, should contain JWT tokens with `role` and `user` claimss in it, along with and `exp` claim; before executing any SQL query, your app should set the role in the DB to the one specified in the JWT claim, and the session variable `request.jwt.claim.user` to the value of the `user` claim
- all JWT signatures should be validated, and expiry should be checked
- read more about the `pg-need-to-know`'s SQL API in `/api/sql-api.md` and see it in action in `/src/testing.sql`
- have a look at the [python client](https://github.com/leondutoit/py-need-to-know)
