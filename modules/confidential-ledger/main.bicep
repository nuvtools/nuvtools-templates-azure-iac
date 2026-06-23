// ---------------------------------------------------------------------------
// Bicep Module: Confidential Ledger
// Creates an Azure Confidential Ledger (tamper-proof, append-only ledger)
// with AAD-based security principals.
// ---------------------------------------------------------------------------

metadata name = 'Confidential Ledger'
metadata description = 'Module for creating an Azure Confidential Ledger with AAD-based security principals following configurable naming conventions.'
metadata version = '1.0.0'

// =============================================================================
// Parameters
// =============================================================================

@description('Full resource name. If provided, overrides the auto-generated naming pattern.')
param name string = ''

@description('Workload name. Used to compose the resource name when name is not provided.')
@minLength(2)
@maxLength(20)
param workloadName string

@description('Deployment environment (e.g., dev, uat, hml, staging, prod).')
param environment string

@description('Azure region where the resource will be created.')
param location string = 'brazilsouth'

@description('Tags to apply to the resource.')
param tags object = {
  ManagedBy: 'Bicep'
  Environment: environment
}

@description('Ledger access type.')
@allowed([
  'Public'
  'Private'
])
param ledgerType string = 'Public'

@description('AAD-based security principals. Each object: { principalId: string, tenantId: string, ledgerRoleName: Administrator|Contributor|Reader }.')
param aadBasedSecurityPrincipals array = []

@description('Certificate-based security principals. Each object: { cert: string, ledgerRoleName: Administrator|Contributor|Reader }.')
param certBasedSecurityPrincipals array = []

// =============================================================================
// Variables
// =============================================================================

// Pattern: {workloadName}-acl-{environment} (CAF: acl)
var autoName = '${workloadName}-acl-${environment}'
var ledgerName = empty(name) ? autoName : name

// =============================================================================
// Resources
// =============================================================================

#disable-next-line use-recent-api-versions
resource confidentialLedger 'Microsoft.ConfidentialLedger/ledgers@2023-06-28-preview' = {
  name: ledgerName
  location: location
  tags: tags
  properties: {
    ledgerType: ledgerType
    aadBasedSecurityPrincipals: aadBasedSecurityPrincipals
    certBasedSecurityPrincipals: certBasedSecurityPrincipals
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('ID of the created Confidential Ledger.')
output id string = confidentialLedger.id

@description('Name of the created Confidential Ledger.')
output name string = confidentialLedger.name

@description('Public endpoint URI of the ledger.')
output ledgerUri string = confidentialLedger.properties.ledgerUri
