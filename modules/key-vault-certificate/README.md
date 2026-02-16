# NuvTools - Key Vault Certificate

Bicep module for provisioning a certificate in Key Vault with a configurable policy (self-signed or CA) following the NuvTools convention. Supports self-signed certificates (`Self`) or certificates issued by a CA configured in Key Vault, with automatic renewal, configurable key type (RSA/EC), and private key export.

## Naming Convention

The certificate name is defined directly by the `certificateName` parameter, provided by the user. There is no automatic naming convention for this child resource.

## Usage

```bicep
module certificate 'modules/key-vault-certificate/main.bicep' = {
  name: 'deploy-key-vault-certificate'
  scope: resourceGroup('my-rg')
  params: {
    keyVaultName: keyVault.outputs.name
    certificateName: 'wildcard-myapp'
    subjectName: 'CN=*.myapp.com'
    issuerName: 'Self'
    validityInMonths: 12
    keyType: 'RSA'
    keySize: 2048
  }
}
```

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `keyVaultName` | `string` | *(required)* | Name of the existing Key Vault where the certificate will be created. |
| `certificateName` | `string` | *(required)* | Name of the certificate to be created in the Key Vault. Defined by the user (no automatic convention). |
| `subjectName` | `string` | *(required)* | Certificate subject name in X.500 format (e.g., `CN=example.com`). |
| `issuerName` | `string` | `'Self'` | Certificate issuer name. Use `Self` for self-signed certificates or the name of the issuer configured in the Key Vault. |
| `validityInMonths` | `int` | `12` | Certificate validity in months. |
| `keyType` | `string` | `'RSA'` | Cryptographic key type. Allowed values: `RSA`, `EC`. |
| `keySize` | `int` | `2048` | Cryptographic key size in bits (applicable only for RSA). Allowed values: `2048`, `3072`, `4096`. |
| `renewBeforeDays` | `int` | `30` | Number of days before expiration to trigger automatic renewal. |
| `exportable` | `bool` | `true` | Indicates whether the certificate's private key is exportable. |
| `contentType` | `string` | `'application/x-pkcs12'` | Content type of the secret associated with the certificate. Allowed values: `application/x-pkcs12`, `application/x-pem-file`. |
| `reuseKeyOnRenewal` | `bool` | `false` | Indicates whether the certificate should reuse the same key on renewal. |
| `tags` | `object` | `{}` | Tags to be applied to the resource. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the certificate created in the Key Vault. |
| `name` | `string` | Name of the certificate created in the Key Vault. |
| `secretId` | `string` | URI of the secret associated with the certificate, used to reference the certificate in other resources (e.g., App Gateway, App Service). |
