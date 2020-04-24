import sys
import pandas as pd


resfile, exposure = sys.argv[1:4]

names_dict = {'VCF_ID': 'SNPID', 'REF': 'Allele1', 'ALT': 'Allele2', 
              'BETA_G:' + exposure: 'Beta_Interaction_1',
              'COV_G:' + exposure + '_G:' + exposure:
              'Var_Beta_Interaction_1_1',
              'PVALUE_INTER': 'P_Value_Interaction', 
              'PVALUE_BOTH': 'P_Value_Joint'}

res = (pd.read_csv(resfile, sep="\t")
       .rename(columns=names_dict)
       .filter(list(names_dict.values())))
res.to_csv("results.fmt", sep=" ", index=False, na_rep="NaN")
