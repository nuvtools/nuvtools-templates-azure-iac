# PostgreSQL Database

Bicep module for creating a database on an existing **Azure Database for PostgreSQL Flexible Server**, with configurable character set and collation, following a configurable naming convention (`{workloadName}-psqldb-{environment}`).

## Naming Convention

The database name is automatically generated based on the `workloadName` and `environment` parameters:

- Pattern: `{workloadName}-psqldb-{environment}` (e.g., `myapp-psqldb-dev`)
- Override: use the `name` parameter to define a fully custom name, bypassing the automatic naming convention.

## Usage

```bicep
module postgresqlDatabase 'modules/postgresql-database/main.bicep' = {
  name: 'deploy-postgresql-database'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'myapp'
    environment: 'dev'
    postgresqlServerName: 'myapp-psql-dev'
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}
```

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | `''` | Full database name. If provided, the automatic naming convention is bypassed. |
| `workloadName` | `string` | *(required)* | Workload name. Used to compose the database name. Min: 2, Max: 20 characters. |
| `environment` | `string` | *(required)* | Deployment environment. Accepts any string (e.g., `dev`, `uat`, `hml`, `staging`, `prod`). |
| `postgresqlServerName` | `string` | *(required)* | Name of the existing PostgreSQL Flexible Server where the database will be created. |
| `charset` | `string` | `'UTF8'` | Database character set. |
| `collation` | `string` | `'en_US.utf8'` | Database collation. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created PostgreSQL database. |
| `name` | `string` | Name of the created PostgreSQL database. |
