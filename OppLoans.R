
library(xgboost)

# Read in data from downloaded file
loan_data <- read.csv("C:/Users/jd5ja/Desktop/OppLoans/lending-club-loan-data/loan.csv")

bad_indicators <- c("Charged Off ",
                    "Charged Off",
                    "Default",
                    "Does not meet the credit policy. Status:Charged Off",
                    "In Grace Period", 
                    "Default Receiver", 
                    "Late (16-30 days)",
                    "Late (31-120 days)")
loan_data$target <- ifelse(loan_data$loan_status %in% bad_indicators,1,0)

# Get rid of all columns that have null or empty values in the first row
# From looking over the data, this was a good indicator if the variable was generally null or not
good_cols <- c()

for(i in c(1:length(loan_data))){
  if(!is.na(loan_data[1,i]) && !loan_data[1,i] == ""){
    good_cols <- c(good_cols, i)
  }
}

loan_data <- loan_data[good_cols]


# Get rid of columns that are essentially duplicates of each other
loan_data <- loan_data[-c(2,4,5,10,16,18:23,35,37)]

# More clean up of the data to get rid of observations with missing data
loan_data <- loan_data[complete.cases(loan_data),]

# Change variable types to numeric
loan_data$term = as.numeric(loan_data$term)
loan_data$grade = as.numeric(loan_data$grade)

loan_data$home_ownership <- factor(loan_data$home_ownership, levels = c("NONE", "OTHER", "ANY", "MORTGAGE", "RENT", "OWN"))
loan_data$home_ownership <- as.numeric(loan_data$home_ownership)
loan_data$verification_status <- as.numeric(loan_data$verification_status)

# Only use the year from these variables 
loan_data$issue_d <- substring(loan_data$issue_d, 5, 8)
loan_data$issue_d <- as.numeric(loan_data$issue_d)
loan_data$earliest_cr_line <- substring(loan_data$earliest_cr_line, 5, 8)
loan_data$earliest_cr_line <- as.numeric(loan_data$earliest_cr_line)
loan_data$last_pymnt_d <- substring(loan_data$last_pymnt_d, 5, 8)
loan_data$last_pymnt_d <- as.numeric(loan_data$last_pymnt_d)
loan_data$last_credit_pull_d <- substring(loan_data$last_credit_pull_d, 5, 8)
loan_data$last_credit_pull_d <- as.numeric(loan_data$last_credit_pull_d)

# More of making everything a numeric type
loan_data$pymnt_plan <- as.numeric(loan_data$pymnt_plan)
loan_data$initial_list_status <- as.numeric(loan_data$initial_list_status)
loan_data$application_type <- as.numeric(loan_data$application_type)
loan_data$emp_length <- as.numeric(loan_data$emp_length)

# Run tests to see which of the variables is significant - get rid of the variables that seem to be insignificant

loan_data <- loan_data[complete.cases(loan_data),]
fit <- aov(loan_data$target ~., data = loan_data)
summary(fit)
loan_data <- loan_data[-c(1, 22, 26, 28, 33, 34, 35)]

# Run tests again until all variables are significant
fit <- aov(loan_data$target ~., data = loan_data)
summary(fit) 
loan_data <- loan_data[-c(9,29)]

fit <- aov(loan_data$target ~., data = loan_data)
summary(fit) 

# Check feature selection results with a logistic model and F-tests to ensure significant varaibles are being used
model <- glm(target ~ ., data = loan_data, family = "binomial")
summary(model)
drop1(fit,~.,test="F")

# Create "target" as its own list and remove it from the loan_data dataset so that it isn't being used in the xgboost model
target <- loan_data$target
loan_data <- loan_data[-c(length(loan_data))]

# Create train and test data with the first 75% of loan_data and the last 25% respectively
num_train <- ceiling(nrow(loan_data)*.75)
num_train2 <- num_train + 1
training_data <- loan_data[1:num_train,]
testing_data <- loan_data[num_train2:nrow(loan_data),]

# Create the logistic model using xgboost
# This was first tested with 20 rounds of training, and then limited to 10 based on the training results below
xgb <- xgboost(data = data.matrix(training_data[,-1]), label = target[1:num_train], nround=10, objective = "binary:logistic", verbose = 1)

# Training Errors
# [1] train-error:  .041378
# [5] train-error:  .031368
# [9] train-error:  .026431
# [10] train-error: .026112
# [11] train-error: .026227

# Use the xgboost model to predict the target values for the test data
prediction <- predict(xgb, data.matrix(testing_data[,-1]))
prediction <- as.numeric(prediction > .5)

# Calculate the test results 
error <- mean((target[num_train2:nrow(loan_data)] - prediction)**2)
print(error)

## error = .03435
## 96.6% of observatios in the test data predicted correctly


