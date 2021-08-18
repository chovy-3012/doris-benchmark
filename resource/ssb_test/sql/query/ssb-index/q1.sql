--Q1.1
select *
from lineorder where lo_discount between 1 and 3 and lo_quantity < 25 limit 10;