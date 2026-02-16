// =============================================================================
// Default orchestrator parameters
// This file serves as a reference; use the files in environments/ for
// each specific environment.
// =============================================================================

using 'main.bicep'

param workloadName = 'myapp'
param environment = 'dev'
param location = 'brazilsouth'

// Layer toggles
param enableNetworking = true
param enableMonitoring = true
param enableSecurity = true
param enableData = false
param enableCompute = false
param enableMessaging = false
param enableGovernance = false
