import pandas as pd

cols = ["loan_amnt","term","int_rate","grade","sub_grade","emp_length",
        "home_ownership","annual_inc","verification_status","issue_d",
        "loan_status","purpose","addr_state","dti","delinq_2yrs",
        "revol_util","open_acc","total_acc"]

df = pd.read_csv("../data/accepted_2007_to_2018Q4.csv.gz", usecols=cols)
df.shape
