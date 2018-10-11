#!/bin/bash

_date=$(date +%Y-%m-%d)

echo "\
---
title: need-to-know API
output:
    html_document:
        toc: true
        toc_float: true
---
Generated on: $_date

## Features

For administrators:

- manage access control for data analysis based on group membership, and table access grants (select, insert, update)
- security and integrity by default: without explicit policies, only data owners can see or operate on their data
- extensive audit logging: data access, data updates and deletions, access control changes

For data owners:

- true data ownership: retain the right to revoke access and delete their data
- transparent insight into how their data is being used

For data users:

- extensible metadata support for describing users, groups, tables, and columns
- possibility to publish data, and make it available to specific individuals only

For application developers:

- rich HTTP and SQL API for application development
- authorization is a solved problem
- a [reference client](https://github.com/leondutoit/py-need-to-know) to see how the API can be used

" >> ntk-docs.Rmd

cat ./docs/1-access-control-model.md \
    ./docs/2-an-example-using-the-http-api.md \
    ./docs/3-auth-requirements.md \
    ./api/http-api.md  >> ntk-docs.Rmd

R -q -e "library(rmarkdown); render('ntk-docs.Rmd', output_format='html_document')"
rm ./ntk-docs.Rmd
