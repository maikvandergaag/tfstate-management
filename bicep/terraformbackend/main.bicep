targetScope = 'subscription'

metadata info = {
  title: 'Bicep file for Terraform Backend'
  version: '1.0.0'
  author: 'Databalance'
}

@description('Location for all resources.')
param location string = deployment().location

@description('Name used in the storage account and container for Terraform state files. Must be globally unique.')
param name string

@allowed([
  'tst'
  'acc'
  'prd'
  'dev'
])
@description('The environment where the service is being deployed to (tst, acc, prd, dev)')
param env string

param locationshort string

param containers string[]


resource rg 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: 'gaag-rg-${name}-${locationshort}-${env}'
  location: location
}

module storageAccount '../modules/storage.bicep' = {
  params: {
    name: name
    locationshort:locationshort
    location: location
    env: env
    containers: containers
  }
  scope: rg
}

output storageAccountName string = storageAccount.outputs.name
