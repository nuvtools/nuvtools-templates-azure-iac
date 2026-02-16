// ---------------------------------------------------------------------------
// Bicep Module: Key Vault Certificate
// Creates a certificate in Key Vault using a certificate policy,
// supporting self-signed (Self) or CA-issued certificates.
// ---------------------------------------------------------------------------

metadata name = 'Key Vault Certificate'
metadata description = 'Module for creating a certificate in Key Vault with configurable policy (self-signed or CA) following configurable naming conventions.'
metadata version = '1.0.0'

// =============================================================================
// Parametros
// =============================================================================

@description('Name of the existing Key Vault where the certificate will be created.')
param keyVaultName string

@description('Name of the certificate to be created in the Key Vault.')
param certificateName string

@description('Certificate subject name in X.500 format (e.g., CN=example.com).')
param subjectName string

@description('Certificate issuer name. Use "Self" for self-signed certificates or the issuer name configured in Key Vault.')
param issuerName string = 'Self'

@description('Certificate validity in months.')
param validityInMonths int = 12

@description('Certificate cryptographic key type.')
@allowed([
  'RSA'
  'EC'
])
param keyType string = 'RSA'

@description('Cryptographic key size in bits. Applicable only to RSA keys.')
@allowed([
  2048
  3072
  4096
])
param keySize int = 2048

@description('Number of days before expiry to trigger automatic renewal.')
param renewBeforeDays int = 30

@description('Indicates whether the certificate private key is exportable.')
param exportable bool = true

@description('Content type of the secret associated with the certificate.')
@allowed([
  'application/x-pkcs12'
  'application/x-pem-file'
])
param contentType string = 'application/x-pkcs12'

@description('Indicates whether the certificate should be reused on renewal (use the same key).')
param reuseKeyOnRenewal bool = false

@description('Tags to apply to the resource.')
param tags object = {}

// =============================================================================
// Resources
// =============================================================================

// Reference to the existing Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2024-11-01' existing = {
  name: keyVaultName
}

#disable-next-line BCP081
resource certificate 'Microsoft.KeyVault/vaults/certificates@2024-11-01' = {
  name: certificateName
  parent: keyVault
  tags: tags
  properties: {
    certificatePolicy: {
      issuerParameters: {
        name: issuerName
      }
      keyProperties: {
        keyType: keyType
        keySize: keySize
        reuseKey: reuseKeyOnRenewal
        exportable: exportable
      }
      secretProperties: {
        contentType: contentType
      }
      x509CertificateProperties: {
        subject: subjectName
        validityInMonths: validityInMonths
      }
      lifetimeActions: [
        {
          trigger: {
            daysBeforeExpiry: renewBeforeDays
          }
          action: {
            actionType: issuerName == 'Self' ? 'AutoRenew' : 'EmailContacts'
          }
        }
      ]
    }
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('ID of the certificate created in Key Vault.')
output id string = certificate.id

@description('Name of the certificate created in Key Vault.')
output name string = certificate.name

@description('Secret URI associated with the certificate, used to reference the certificate in other resources (e.g., App Gateway, App Service).')
output secretId string = certificate.properties.secretId
