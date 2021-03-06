root = this

lumenize = require('/lumenize')
{timeSeriesGroupByCalculator, ChartTime} = lumenize
utils = lumenize.utils

cfdCalculator = (results, config) ->
  ###
  Takes the "results" from a query to Rally's Analytics API (or similar MVCC-based implementation)
  and returns the data points for a cumulative flow diagram (CFD). 
  ###
  
  # Find the last day for this CFD
  
  lastTrackingDate = results[results.length - 1]._ValidFrom
  lastTrackingCT = new ChartTime(lastTrackingDate, 'day', config.timezone).add(1)
  
  # Find the first record where something moves into the `startTrackingGroupByFieldValue`.
  firstTrackingDate = ''  # !TODO: Upgrade this to match timeSeriesCalculator
  for row, i in results
    if row[config.groupByField] == config.startTrackingGroupByFieldValue
      firstTrackingDate = row._ValidFrom
      break
  if firstTrackingDate == ''
    throw new Error("Couldn't find any data whose #{config.groupByField} transitioned into groupByFieldValue #{config.startTrackingGroupByFieldValue}")
    
  firstTrackingCT = new ChartTime(firstTrackingDate, 'day', config.timezone)
  
  if config.maxDaysBack?
    maxDaysBackCT = lastTrackingCT.add(-1 * config.maxDaysBack, 'day')
    if firstTrackingCT.$lt(maxDaysBackCT)
      firstTrackingCT = maxDaysBackCT
    
  rangeSpec =
    workDays: config.workDays
    holidays: config.holidays
    start: firstTrackingCT
    pastEnd: lastTrackingCT
  
  console.log('RangeSpec:\n' + JSON.stringify(rangeSpec, undefined, 4))
    
  timeSeriesGroupByCalculatorConfig = 
    rangeSpec: rangeSpec
    timezone: config.timezone
    groupByField: config.groupByField
    groupByFieldValues: config.groupByFieldValues
    useAllGroupByFieldValues: config.useAllGroupByFieldValues
    aggregationField: config.aggregationField
    aggregationFunction: config.aggregationFunction
    snapshotValidFromField: '_ValidFrom'
    snapshotValidToField: '_ValidTo'
    snapshotUniqueID: 'ObjectID'

  {listOfAtCTs, groupByAtArray, uniqueValues} = timeSeriesGroupByCalculator(results, timeSeriesGroupByCalculatorConfig)
  
  # Get it into HighCharts form
  if config.useAllGroupByFieldValues
    series = lumenize.groupByAtArray_To_HighChartsSeries(groupByAtArray, config.groupByField, 'GroupBy')
    drillDownObjectIDs = lumenize.groupByAtArray_To_HighChartsSeries(groupByAtArray, config.groupByField, 'DrillDown', uniqueValues, true)
  else
    series = lumenize.groupByAtArray_To_HighChartsSeries(groupByAtArray, config.groupByField, 'GroupBy', config.groupByFieldValues)
    drillDownObjectIDs = lumenize.groupByAtArray_To_HighChartsSeries(groupByAtArray, config.groupByField, 'DrillDown', config.groupByFieldValues, true)
    
  # HighCharts needs a categories Array for the x-axis so...
  categories = ("#{ct.toString()}" for ct in listOfAtCTs)  # !TODO: Should be smarter about skipping some when we have more than will fit on the x-axis

  # find the min for the last state
  lowestValueInLastState = null
  unless config.useAllGroupByFieldValues
    lowestValueInLastState = lumenize.functions.$min(series[series.length-1].data)

  return {series, categories, drillDownObjectIDs, lowestValueInLastState}
  
root.cfdCalculator = cfdCalculator