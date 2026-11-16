metadata info = {
  title: 'Storage Account Module'
  version: '1.1.0'
  author: 'Databalance'
}

metadata description = '''
Module for creating a storage account
'''

@description('The name of the storageaccount will be in the format azstr[name][environment]')
param name string

param containers string[] = [
  'tfstate'
]

@description('The location of the storageaccount')
param location string = resourceGroup().location

@description('The SKU of the storage account')
param storageSKU string = 'Standard_LRS'
@allowed([
  'tst'
  'acc'
  'prd'
  'dev'
])
@description('The environment where the service is being deployed to (tst, acc, prd, dev)')
param env string

param locationshort string

var storageName = toLower('st${take(replace(name, '-',''),15)}${locationshort}${env}')

resource storage 'Microsoft.Storage/storageAccounts@2025-01-01' = {
  name: storageName
  location: location
  sku: {
    name: storageSKU
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowSharedKeyAccess: false
    defaultToOAuthAuthentication: true
  }
}

resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2025-01-01' = {
  name: 'default'
  parent: storage
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 30
      allowPermanentDelete: false
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 30
      allowPermanentDelete: false
    }
    isVersioningEnabled: true
  }
}

resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-01-01' = [for container in containers: {
  name: container
  properties: {
    publicAccess: 'None'
  }
  parent: blobServices
}]

output name string = storage.name
