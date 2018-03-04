library("xts")
load("../Qprepare/prepareddataSC.RData")

# first row of train only contains zeros! train = unscaled_train
train = scaledtrain

# Format data into POSIXct
train[, 1] = as.POSIXct(train[, 1])
dates = train[, 1]

# probably unnecessary!!!
end_date = as.POSIXct("2015-01-01 01:00:00 CET")
last_known_data = which(dates == end_date) - 1
origin = "1970-01-01 00:00:00"

x_raw = xts(train[, -1], order.by = train[, 1])
# Only use data until december 2014 to select the model
x.sample = x_raw["/2014-12-01"]
y.sample = (x.sample$`S&P500`)

pca = function(A) {
    ATA = t(A) %*% A
    AAT = A %*% t(A)
    eig1 = eigen(ATA)
    eig2 = eigen(AAT)
    V = as.matrix(eig1$vectors)
    U = as.matrix(eig2$vectors)
    dimnames(V) = list(colnames(A), paste0("PC", seq_len(ncol(V))))
    
    stdev = sqrt(eig2$values)/sqrt(max(1, nrow(A) - 1))
    x = A %*% V
    res = list(sdev = stdev, rotation = V, x = x)
    res
}

# Extract PCAs
pca_data = pca(x.sample)
screeplot(pca_data, main = deparse(substitute(pca_data)))

diff_index = xts(pca_data$x[, 1:5], order.by = dates[1:273])
save(diff_index, file = "diff_index.RData")
save(x.sample, file = "x.sample.RData")
save(y.sample, file = "y.sample.RData")
