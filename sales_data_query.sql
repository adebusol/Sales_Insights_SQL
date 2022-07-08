-- Exploring the dataset
SELECT * FROM sales_data

-- let's look at some distinct values for some of the columns
SELECT DISTINCT(status) FROM sales_data
SELECT DISTINCT(year_id) FROM sales_data
SELECT DISTINCT(PRODUCTLINE) FROM sales_data
SELECT DISTINCT(COUNTRY) FROM sales_data
SELECT DISTINCT(DEALSIZE) FROM sales_data
SELECT DISTINCT(TERRITORY) FROM sales_data

-- Analysis
-- Grouping sales by their productline
SELECT PRODUCTLINE, SUM(sales) as Revenue 
FROM sales_data
GROUP BY PRODUCTLINE
ORDER BY 2 DESC

--Grouping by sales across the years
SELECT YEAR_ID, SUM(sales) as Revenue 
FROM sales_data
GROUP BY YEAR_ID
ORDER BY 2 DESC
--2005 is the year with the least sales. let's explore and possibly find out why
SELECT DISTINCT(MONTH_ID) FROM sales_data
WHERE YEAR_ID = 2005
--This company did not operate throughout in 2005. Only for 5 months

-- Grouping by dealsize
SELECT DEALSIZE, SUM(sales) as Revenue 
FROM sales_data
GROUP BY DEALSIZE
ORDER BY 2 DESC

-- What was the best month for sale in a specific year
SELECT MONTH_ID, sum(sales) Revenue, count(ORDERNUMBER) Order_Count
FROM sales_data
WHERE YEAR_ID = 2005 --change year to see for others
GROUP BY MONTH_ID
ORDER BY 2 DESC
-- November had the highest sales for 2003 & 2004
-- What product line are they selling in November
SELECT PRODUCTLINE, MONTH_ID, sum(sales) Revenue, count(ORDERNUMBER) Order_Count
FROM sales_data
WHERE YEAR_ID = 2003 and MONTH_ID = 11
GROUP BY MONTH_ID, PRODUCTLINE
ORDER BY 3 DESC

-- Who are our best customers? (RFM Analysis) I am going to be using a metric called RFM(Recency, monetary)
DROP TABLE IF EXISTS #rfm
;with rfm as
(
SELECT 
    CUSTOMERNAME, 
    SUM(sales) MonetaryValue,
    AVG(sales) AvgMonetaryValue,
    COUNT(ORDERNUMBER) Order_count,
    MAX(ORDERDATE) last_order_date,
    (SELECT MAX(ORDERDATE) FROM sales_data) max_order_date,
    DATEDIFF(DD,MAX(ORDERDATE),(SELECT MAX(ORDERDATE) FROM sales_data)) Recency
FROM sales_data
GROUP BY CUSTOMERNAME
),
rfm_calc as(
SELECT *,
    NTILE(4) OVER (ORDER BY Recency desc) rfm_recency,
    NTILE(4) OVER (ORDER BY Order_Count) rfm_order_count,
    NTILE(4) OVER (ORDER BY MonetaryValue) rfm_monetary
FROM rfm r
)
SELECT 
    *, rfm_recency + rfm_order_count + rfm_monetary as rfm_cell,
    cast(rfm_recency as varchar) + cast(rfm_order_count as varchar)+ cast(rfm_monetary as varchar) rfm_cell_string
INTO #rfm  
FROM rfm_calc c

SELECT CUSTOMERNAME, rfm_recency, rfm_order_count, rfm_monetary,
CASE
    WHEN rfm_cell_string in (111, 112, 121, 122, 123, 132, 211, 212, 114, 141) then 'lost_customers'
    WHEN rfm_cell_string in (133, 134, 143, 144, 244, 334, 343, 344) then 'Slipping away, cannot lost' --(Big spenders who haven't purchased lately)
    WHEN rfm_cell_string in (311, 411, 331) then 'new customer'
    WHEN rfm_cell_string in (222, 223, 233, 322) then 'potential churners'
    WHEN rfm_cell_string in (323, 333, 321, 422, 332, 432) then 'active' --(Customers who buy often and recently but at low price points)
    WHEN rfm_cell_string in (433, 434, 443, 444) then 'loyal'
END rfm_segment
FROM #rfm

-- What products are often sold together?
--SELECT * FROM sales_data WHERE ORDERNUMBER = 10411
SELECT DISTINCT ORDERNUMBER, STUFF(
    (SELECT ',' + PRODUCTCODE
    FROM sales_data p
    WHERE ORDERNUMBER IN(
        SELECT ORDERNUMBER
        FROM(
            SELECT ORDERNUMBER, count(*) rn
            FROM sales_data 
            WHERE STATUS = 'Shipped'
            GROUP BY ORDERNUMBER) m
    WHERE rn = 2 
)
and p.ORDERNUMBER = s.ORDERNUMBER
FOR XML PATH ('')) 
,1,1,'') ProductCodes
FROM sales_data s
ORDER BY 2 desc
