# GraphQL iOS Codegen

This sub-directory handles the code generation for site reputation graphql. 
generation.

## Installation
To use the code generation, run `yarn install` from this subdirectory.
This will ensure that all the necessary packages are installed in your local
repository.

## Updating graphql schema
schema and graphql documents are copied directly from the service project source tree https://gitlab.tools.anonyome.com/platform/site-reputation/site-reputation-service/-/tree/master/schema/api.

- copy https://gitlab.tools.anonyome.com/platform/site-reputation/site-reputation-service/-/blob/master/schema/api/getSiteReputation.api.graphql -> graphql/schema/getSiteReputation.api.graphql
- copy https://gitlab.tools.anonyome.com/platform/site-reputation/site-reputation-service/-/blob/master/schema/api/getSiteReputation.document.graphql -> graphql/documents/getSiteReputation.document.graphql

## Running
The code generation will automatically input the file to its destination.
run `yarn codegen`. For more information, run `yarn codegen --help`.
