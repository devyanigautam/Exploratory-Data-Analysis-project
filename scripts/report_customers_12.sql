/*
==========================================================================================
                                   
                                   CUSTOMER REPORT

==========================================================================================
Purpose:
  -  This report consolidates key customer metrics and behaviours

HIGHLIGHTS:

 1. Gathers essential fields such as 
      * names
      * ages
      * transaction details

 2. Segments customers into categories ( VIP , Regular , New ) and age groups.
 3. Aggregates customer - level metrics:
          - total orders
          - total sales
          - total quantity purchased
          - total products
          - lifespan (in months)
 4. Calculates valuable KPIs:
    - recency (months since last order)
    - average order value
    - average monthly spend
==========================================================================================
*/

 -- =============================================================================
-- Create Report: gold.report_customers
-- =============================================================================
IF OBJECT_ID('gold.report_customers', 'V') IS NOT NULL
    DROP VIEW gold.report_customers;
GO

  Create VIEW gold.report_customers as
  with base_query as(
  /*-----------------------------------------------------------------
    1) Base Query : Retrieves core columns from tables  
  -------------------------------------------------------------------*/
  select
  fs.order_number,fs.product_key,fs.order_date,fs.sales_amount,
  fs.quantity,dc.customer_key,dc.customer_number,
  concat(dc.first_name,' ',dc.last_name) fullname, 
  datediff (year,dc.birthdate,GETDATE()) age
  from gold.fact_sales fs
  left join gold.dim_customers dc
  on fs.customer_key=dc.customer_key
  where fs.order_date is not null)
  
  ,customer_aggregation as(
  /*-----------------------------------------------------------------
   3) Customer Aggregations : Summarizes key metrics at the customer level
  -------------------------------------------------------------------*/
  select customer_key,customer_number,fullname,age,
  count(distinct order_number) totalorders,
  count(distinct product_key) totalproducts,
  sum(sales_amount) total_sales,
  sum(quantity) total_quantity,
  max(order_date) last_order_date,
  datediff(month,min(order_date),max(order_date)) lifespan
  from base_query
  group by 
    customer_key,customer_number,fullname,age
)
select
 customer_key,customer_number,fullname,age
/*-----------------------------------------------------------------
   2) Segments customers into categories ( VIP , Regular , New ) and age groups.
  -------------------------------------------------------------------*/
 ,case
     when age<20 then   'Under 20'
     when age between 20 and 29 then '20-29'
     when age between 30 and 39 then '30-39'
     when age between 40 and 49 then '40-49'
     else  '50 & Above'
  
  end age_group
  ,case
     when lifespan>=12 and total_sales>5000 then   'VIP'
     when lifespan>=12 and total_sales<=5000 then  'Regular'
     else  'NEW'
  
  end as customer_segmentation,
 last_order_date,
 DATEDIFF(month,last_order_date,getdate()) recency,
 totalorders,total_sales,total_quantity,totalproducts
 -- Compute average order value(AOV)  [average order value=total sales/total nr.of orders]
  ,case 
     when total_sales=0 then 0
     else (total_sales/totalorders)
  end avg_order_value
  -- Compute average monthly spend(AMS)  [average monthly spend = Total Sales/Nr. of months ]
  ,case 
      when lifespan=0 then total_sales
      else total_sales/lifespan
  end avg_monthly_spend  
 from customer_aggregation 

 -- select * from gold.report_customers
