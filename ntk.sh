#!/bin/bash

if [ $# -lt 1 ]; then
    echo "Missing arguments, exiting"
    echo "For help do: ./ntk.sh --guide"
    exit 1
fi

_guide="\

    ntk - need to know
    ------------------

    To set up the DB schema do the following:

    export SUPERUSER=db-super-user-name
    export DBOWNER=db-owner-user-name
    export DBNAME=db-name

    Create a .pgpass file so you can connect to the DB.

    ./ntk.sh OPTIONS

    Options
    -------
    --setup     Create the DB schema.
    --sqltest   Run SQL tests to ensure the DB schema works.
    --httptest  Run HTTP tests (postgrest must be running, python dependencies must be installed)
    --guide     Print this guide

"

setup() {
    psql -U $SUPERUSER -d $DBNAME -f ./src/need-to-know.sql
    psql -U $SUPERUSER -d $DBNAME -f ./src/need-to-know-token.sql
}

sqltest() {
    psql -U $SUPERUSER -d $DBNAME -1 -f ./src/testing.sql
}

while (( "$#" )); do
    case $1 in
        --setup)           shift; setup; exit 0 ;;
        --sqltest)         shift; sqltest; exit 0 ;;
        --httptest)        shift; httptest; exit 0 ;;
        --guide)           printf "%s\n" "$_guide"; exit 0 ;;
        *) break ;;
    esac
done
