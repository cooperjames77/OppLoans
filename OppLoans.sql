
# 1.
SELECT custid, COUNT(loanid) AS num_loans
FROM all_loans
GROUP BY custid;

# 2.
ALTER TABLE all_loans
ADD loanenddate VARCHAR(255);

# set the new column equal to either payoffdate or writeoffdate depending on which one isn't null
UPDATE all_loans SET loanenddate = payoffdate
WHERE payoffdate IS NOT NULL;

UPDATE all_loans SET loanenddate = writeoffdate
WHERE writeoffdate IS NOT NULL;

COMMIT WORK;

# create a flag that is 1 if the the row below it is the same customer and has an approve date before the current end date
SELECT custid, loanid, approvedate, loanenddate,
	CASE WHEN (LEAD(custid) = custid) AND (LEAD(approvedate) < loanenddate) THEN 1 
		 ELSE 0 END 
		 AS multiple_loan_flag         
INTO new_table         
FROM all_loans
ORDER BY custid, loanid;

# multiple_loan_flag is 1 if a customer ever had more than one loan at one time 
SELECT custid, MAX(multiple_loan_flag)
FROM new_table
GROUP BY custid;

# 3
SELECT custid, loanid, amount, MIN(approvedate) AS startdate
INTO new_table
FROM all_loans
GROUP BY custid;

# create a target date (6 months out from the first approvedate) to compare to eowdates
SELECT custid, amount, date_add(month, 6, startdate) AS targetdate, eowdate, totpaid, totprincpaid
INTO new_table2
FROM new_table
INNER JOIN all_loanhist
ON all_loans.loanid = all_loanhist.loanid;

# create a flag that is 1 when the date of payment is before the target date specified above
SELECT custid, amount, totpaid, totprincpaid,
	CASE WHEN eowdate < targetdate THEN 1
		 ELSE 0 END
		 AS six_mo_flag
INTO new_table3
FROM new_table2
ORDER BY custid;

# create columns that are equal to totpaid and totprincpaid, except 0 when it's after the target date
# totprincpaid also becomes a percentage of the total amount of the loan
SELECT custid, totpaid * six_mo_flag AS totpaid2, 100.0 * six_mo_flag * totprincpaid / amount AS totprincpaid2
INTO new_table4
FROM new_table3;

# sum up the values over each customer
SELECT custid, SUM(totpaid2) AS pmt_received_six_mo, SUM(totprincpaid2) AS pct_princ_paid_six_mo
FROM new_table4
GROUP BY custid
ORDER BY custid;

# 4.
SELECT all_loans.loanid, approvedate, eowdate
INTO new_table
FROM all_loans
INNER JOIN all_loanhist
ON all_loans.loanid = all_loanhist.loanid;

SELECT loanid, approvedate, MIN(eowdate) AS first_pmt_date
INTO new_table2
FROM new_table
GROUP BY loanid;

# create a flag that is 1 when the approvedate of a loan is more than one month before the first payment on that loan
SELECT loanid,
	CASE WHEN approvedate < date_add(month, -1, first_pmt_date) THEN 1
		 ELSE 0 END
		 AS missing_first_mo_pmt_flag
INTO new_table3
FROM new_table2
ORDER BY loanid;

SELECT AVG(missing_first_mo_pmt_flag)
FROM new_table3;
