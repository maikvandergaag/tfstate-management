using './main.bicep'

param name = 'tfstatebackend'
param env = 'prd'
param location = 'westeurope'
param locationshort = 'weu'

param containers = [
  'tfstate'
  'tfstateaisolution'
]
