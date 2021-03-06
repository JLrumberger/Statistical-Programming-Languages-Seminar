# Qload
# Loads time series data from two online sources (FRED and stooq) 
# and creates a metainformation table.

library(httr)
library(jsonlite)

# getting macroeconomic data from FRED
# Input: x contains a series id string
# Output: Data frame containting time series information from FRED
getJsonData = function(x) {
    connection        = "https://api.stlouisfed.org/fred/series/observations?"
    api_key           = "&api_key=4c5743e8fb183ff3f7f47ba1ae651683&"
    file_type         = "file_type=json&"
    observation_start = "observation_start=1992-02-01&"
    observation_end   = "observation_end=2017-01-01"
    series_id         = paste("series_id=", x, sep = "")
    
    fromJSON(paste(connection, series_id, api_key, file_type, observation_start,
        observation_end, sep = ""))
    
}
# get Time Series data from DataFrame
# Reduces complexity of other rows by moving it into a function
# Output: vector of actual time series values
getJsonValues = function(x) {
    getJsonData(x)$observations$value
}
# Get series information from a dataframe
# Reduces complexity of other rows by moving it into a function
# Output: Vector containing meta information
getSeriesValues = function(x) {
    getSeriesInfo(x)$seriess
}

# Get meta information on a specific time series
# Input: x contains a series id string
# Output: Data frame containting respective information on series
getSeriesInfo = function(x) {
    connection = "https://api.stlouisfed.org/fred/series?"
    api_key    = "&api_key=4c5743e8fb183ff3f7f47ba1ae651683&"
    file_type  = "file_type=json"
    series_id  = paste("series_id=", x, sep = "")
    fromJSON(paste(connection, series_id, api_key, file_type, sep = ""))
}

# Get time series data from Stooq
# Input: x contains a series id string
# Output: Data frame containting time series information from stooq
getStooqData = function(x) {
    connection  = "https://stooq.com/q/d/l/?"
    symbol      = paste("s=", x, "&", sep = "")
    dateandtime = "d1=19920131&d2=20161231&i=m"
    read.csv(paste(connection, symbol, dateandtime, sep = ""))$Close
}


# create time series with multiple dimensions
# Input: x is a vector of series ids
# Output: Data frame containing all data for all series in its columns
createFeatureMatrix = function(x) {
    res           = getJsonData(x[1])$observations[c("date", "value")]
    res$value     = as.numeric(res$value)
    res$date      = as.Date(res$date)
    colnames(res) = c("date", x[1])
    res           = cbind(res, as.data.frame(sapply(x[-1], getJsonValues)))
    res
}


# Create Table for Info on Series
# Input: x is a vector of series ids
# Output: Data frame containing meta information on provided series
createPrepTable = function(x) {
    columnnames = colnames(getSeriesValues(x[1]))[c(1, 4, 5, 6, 7, 9, 11)]
    res         = matrix(nrow = length(x) + 1, ncol = length(columnnames))
    
    res[1, ]    = columnnames
    res[-1, ]   = t(sapply(x, function(x) as.vector(unlist(getSeriesValues(x)[columnnames]))))
    res
}

# Read in all names
series_ids = as.vector(unlist(read.csv("frednametags.csv", stringsAsFactors = FALSE, header = FALSE)))
prepTable  = createPrepTable(series_ids)

# Create table for Info
preppedTable        = as.data.frame(prepTable[1:length(series_ids) + 1, ])
names(preppedTable) = prepTable[1, ]

# Manually enter info for 4 Series where we cannot automatically get this from FRED
gdaxi = c("GDAXI", "German DAX Index", "1992-01-31", "2016-12-30", "Monthly", "Index 1987 = 1000", 
    "Not Seasonally Adjusted")
hsi   = c("HSI", "Hang Seng Index", "1992-01-31", "2016-12-30", "Monthly", "Index 1964 = 100", 
    "Not Seasonally Adjusted")
n225  = c("N225", "Nikkei 225", "1992-01-31", "2016-12-30", "Monthly", "Index Points", 
    "Not Seasonally Adjusted")
s500  = c("S&P500", "Standard & Poor's 500", "1992-01-31", "2016-12-30", "Monthly", "Index Points", 
    "Not Seasonally Adjusted")

# add additional 4 time series from second data source to meta info table
df = as.data.frame(do.call("rbind", list(gdaxi, hsi, n225, s500)))
names(df) = names(preppedTable)

seriesDetails    = rbind(preppedTable, df)
seriesDetails$id = as.character(seriesDetails$id)
seriesDetails    = seriesDetails[order(seriesDetails$id), ]

# Create Time Series from FRED
train     = createFeatureMatrix(series_ids)
train[-1] = sapply(train[-1], function(x) as.numeric(as.character(x)))

# Add additional data for DAX,HSI,NIKKEI225,S&P500 from stooq
train[c("GDAXI", "HSI", "N225", "S&P500")] = sapply(c("^dax", "^hsi", "^nkx", "^spx"), getStooqData)

# Save data and meta information table
save(list = c("train", "seriesDetails"), file = "data.RData")
write.csv(seriesDetails, file = "seriesDetails.csv")
