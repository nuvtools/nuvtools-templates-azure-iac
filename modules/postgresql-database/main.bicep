// ---------------------------------------------------------------------------
// Bicep Module: PostgreSQL Database
// Creates a database on an existing Azure Database for PostgreSQL
// Flexible Server with configurable charset and collation.
// ---------------------------------------------------------------------------

metadata name = 'PostgreSQL Database'
metadata description = 'Module for creating a database on an existing Azure Database for PostgreSQL Flexible Server with configurable charset and collation following configurable naming conventions.'
metadata version = '1.0.0'

// =============================================================================
// Parameters
// =============================================================================

@description('Full database name. If provided, overrides the auto-generated naming pattern.')
param name string = ''

@description('Workload name. Used to compose the database name when name is not provided.')
@minLength(2)
@maxLength(20)
param workloadName string

@description('Deployment environment (e.g., dev, uat, hml, staging, prod).')
param environment string

@description('Name of the existing PostgreSQL Flexible Server where the database will be created.')
param postgresqlServerName string

@description('Database character set.')
param charset string = 'UTF8'

@description('Database collation.')
param collation string = 'en_US.utf8'

// =============================================================================
// Variables
// =============================================================================

// Pattern: {workloadName}-psqldb-{environment}
var autoName = '${workloadName}-psqldb-${environment}'
var databaseName = empty(name) ? autoName : name

// =============================================================================
// Resources
// =============================================================================

// Reference to the existing PostgreSQL Flexible Server
resource postgresqlServer 'Microsoft.DBforPostgreSQL/flexibleServers@2024-08-01' existing = {
  name: postgresqlServerName
}

resource postgresqlDatabase 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2024-08-01' = {
  name: databaseName
  parent: postgresqlServer
  properties: {
    charset: charset
    collation: collation
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('ID of the created PostgreSQL database.')
output id string = postgresqlDatabase.id

@description('Name of the created PostgreSQL database.')
output name string = postgresqlDatabase.name
