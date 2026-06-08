// Stage 4 — Azure Monitor Alert Rules (soak gate trip wires)
targetScope = 'resourceGroup'

param location string
param appiName string
param appName string
param actionGroupName string
param alertEmailAddress string

resource appi 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appiName
}

resource appService 'Microsoft.Web/sites@2023-12-01' existing = {
  name: appName
}

// Stage 4.2 — Action group: email on-call
resource actionGroup 'Microsoft.Insights/actionGroups@2023-09-01-preview' = {
  name: actionGroupName
  location: 'Global'
  properties: {
    groupShortName: 'dev-oncall'
    enabled: true
    emailReceivers: [
      {
        name: 'email-on-call'
        emailAddress: alertEmailAddress
        useCommonAlertSchema: true
      }
    ]
  }
}

// Stage 4.2 — Alert 1: Failed requests > 5 over 5 minutes (App Insights metric)
resource alertFailedRequests 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-bidirectional-dev-error-rate'
  location: 'Global'
  properties: {
    description: 'Soak gate: failed requests exceeded threshold — investigate before advancing deployment ring'
    severity: 1
    enabled: true
    scopes: [appi.id]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'FailedRequestsThreshold'
          criterionType: 'StaticThresholdCriterion'
          metricName: 'requests/failed'
          metricNamespace: 'microsoft.insights/components'
          operator: 'GreaterThan'
          threshold: 5
          timeAggregation: 'Count'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
        webHookProperties: {}
      }
    ]
  }
}

// Stage 4.3 — Alert 2: HTTP 5xx > 0 over 1 minute (App Service metric)
resource alertHttp5xx 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-bidirectional-dev-5xx'
  location: 'Global'
  properties: {
    description: 'Soak gate: HTTP 5xx spike on App Service — possible regression'
    severity: 2
    enabled: true
    scopes: [appService.id]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT1M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'Http5xxThreshold'
          criterionType: 'StaticThresholdCriterion'
          metricName: 'Http5xx'
          metricNamespace: 'microsoft.web/sites'
          operator: 'GreaterThan'
          threshold: 0
          timeAggregation: 'Total'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
        webHookProperties: {}
      }
    ]
  }
}
