--Q1.2
select *
from lineorder where lo_orderkey>=1000000 and  lo_discount between 5 and 7 and lo_quantity < 25 limit 10;