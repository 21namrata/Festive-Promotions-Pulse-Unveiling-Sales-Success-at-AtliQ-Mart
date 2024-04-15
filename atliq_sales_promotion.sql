#AD_HOC REQUESTS

# Consider the below calculation steps only for 'BOGOF' promo type.
-- In the BOGOF offer, the free item is not initially counted in the quantity. (2 units are bundled and counted as one)
-- To get the adjusted quantity (units), we need to multiply quantity by 2.
-- Calculate the promotional price by halving the base price (promo_price = base_price * 0.5).
-- Multiply the adjusted quantity by the promotional price to obtain the total revenue after promo. 

update fact_events
set `quantity_sold(after_promo)`=`quantity_sold(after_promo)` * 2
where promo_type='BOGOF';

# I made two columns for before promo price and after promo price
alter table fact_events
add column before_promo_price decimal(10,2),
add column after_promo_price decimal(10,2);


#inserting values in these above column 
update fact_events
set before_promo_price = `quantity_sold(before_promo)` * base_price; 

update fact_events
set after_promo_price = case 
        when promo_type = 'BOGOF' then  `quantity_sold(after_promo)` * base_price * 0.5
        else  `quantity_sold(after_promo)` * base_price
    end;

 
 -- 1. provide a list of products with a base price greater than 500 and that are featured 
-- in promo type 'BOGOF' ( Buy on e get one free) .This information will 
-- help us identify high - value products that are currently being heavily discounted,
-- which can be helpful in evaluating our price  and promotion strategies.

select distinct(p.product_code) ,p.product_name,e.base_price,e.promo_type from dim_products p
right join fact_events e on p.product_code=e.product_code
having base_price > 500 and promo_type ='BOGOF';



-- 2. generate a report that provides an overview of the number of stores in each city.
-- the result will be sorted in descending order of the store counts.
select city , count(city) as 'store_count' from dim_stores
group by city
order by  store_count desc;



-- 3. generate a report that displays each campaign along with total revenue generated before and after campaign ?
-- The report includes three key fields: 
-- Campaign_name,tota_revenue(before_promotion), total_revenue(after_promotion).display the value in million
select c.campaign_name, sum(e.before_promo_price)/1000000 as 'total_revenue(before_promotion) in million',
sum(e.after_promo_price)/1000000 as 'total_revenue(after_promotion) in million' from fact_events e
left join dim_campaigns c on e.campaign_id=c.campaign_id
group by c.campaign_name;


-- 4. Produce a report that calculates the Incremental Sold Quantity (ISU%) for each category during the Diwali campaign. 
-- Additionally, provide rankings for the categories based on their ISU%. 
-- The report will include three key fields: category, isu%, and rank order. 
-- This information will assist in assessing the category-wise success and impact of the Diwali campaign on incremental sales.

select p.category,
((sum(e.`quantity_sold(after_promo)`) - sum(e.`quantity_sold(before_promo)`))/sum(e.`quantity_sold(before_promo)`))*100 as 'ISU%',
rank() over(order by ((sum(e.`quantity_sold(after_promo)`) - sum(e.`quantity_sold(before_promo)`))/sum(e.`quantity_sold(before_promo)`))*100  
desc) as'Rank Order '
from fact_events e
left join dim_products p on e.product_code=p.product_code
left join dim_campaigns c on e.campaign_id=c.campaign_id
where c.campaign_name='Diwali' 
group by p.category;



-- 5.Create a report featuring the Top 5 products, ranked by Incremental Revenue Percentage (IR%), 
-- across all campaigns. The report will provide essential information including product name, category, and ir%. 
-- This analysis helps identify the most successful products in terms of incremental revenue across our campaigns, 
-- assisting in product optimization.

select p.product_name,p.category,
((sum(e.after_promo_price) - sum(e.before_promo_price))/sum(e.before_promo_price))*100 as 'IR%',
rank() over(order by ((sum(e.after_promo_price) - sum(e.before_promo_price))/sum(e.before_promo_price))*100 desc) as'Rank Order '
from fact_events e
left join dim_products p on e.product_code=p.product_code
group by p.product_name,p.category
limit 5;


#INSIGHTS
#Store Performance Analysis:
-- • Which are the top 10 stores in terms of Incremental Revenue (IR) generated from the promotions?

select e.store_id,s.city,
((sum(e.after_promo_price) - sum(e.before_promo_price))/sum(e.before_promo_price))*100 as 'IR%',
rank() over(order by ((sum(e.after_promo_price) - sum(e.before_promo_price))/sum(e.before_promo_price))*100 desc) as'Rank Order'
from fact_events e
left join dim_stores s on e.store_id=s.store_id
group by e.store_id,s.city
limit 10;


-- • Which are the bottom 10 stores when it comes to Incremental Sold Units (ISU) during the promotional period?
select e.store_id,s.city,
((sum(e.`quantity_sold(after_promo)`) - sum(e.`quantity_sold(before_promo)`))/sum(e.`quantity_sold(before_promo)`))*100 as 'ISU%',
rank() over(order by ((sum(e.`quantity_sold(after_promo)`) - sum(e.`quantity_sold(before_promo)`))/sum(e.`quantity_sold(before_promo)`))*100  asc) as'Rank Order '
from fact_events e
left join dim_stores s on e.store_id=s.store_id
group by  e.store_id,s.city
limit 10;


#Promotion Type Analysis:
-- What are the top 2 promotion types that resulted in the highest Incremental Revenue?
select promo_type,
((sum(after_promo_price) - sum(before_promo_price))/sum(before_promo_price))*100 as 'IR%',
rank() over(order by ((sum(after_promo_price) - sum(before_promo_price))/sum(before_promo_price))*100 desc) as'Rank Order'
from fact_events 
group by promo_type
limit 2;

#• What are the bottom 2 promotion types in terms of their impact on Incremental Sold Units?
select promo_type,
((sum(`quantity_sold(after_promo)`) - sum(`quantity_sold(before_promo)`))/sum(`quantity_sold(before_promo)`))*100 as 'ISU%',
rank() over(order by ((sum(`quantity_sold(after_promo)`) - sum(`quantity_sold(before_promo)`))/sum(`quantity_sold(before_promo)`))*100  asc) as'Rank Order '
from fact_events 
group by promo_type
limit 2;

#Product and Category Analysis:
-- • Which product categories saw the most significant lift in sales from the promotions?
select p.category,
((sum(e.after_promo_price) - sum(e.before_promo_price))/sum(e.before_promo_price))*100 as 'IR%',
rank() over(order by ((sum(e.after_promo_price) - sum(e.before_promo_price))/sum(e.before_promo_price))*100 desc) as'Rank Order'
from fact_events e
left join dim_products p on e.product_code=p.product_code
group by p.category;


select p.category,
sum(e.after_promo_price) , sum(e.before_promo_price)
from fact_events e
left join dim_products p on e.product_code=p.product_code
group by p.category;

select e.promo_type,
sum(e.after_promo_price) , sum(e.before_promo_price)
from fact_events e
left join dim_products p on e.product_code=p.product_code
group by e.promo_type;






-- • Are there specific products that respond exceptionally well or poorly to promotions?
select p.product_name,
((sum(e.after_promo_price) - sum(e.before_promo_price))/sum(e.before_promo_price))*100 as 'IR%',
rank() over(order by ((sum(e.after_promo_price) - sum(e.before_promo_price))/sum(e.before_promo_price))*100 desc) as'Rank Order'
from fact_events e
left join dim_products p on e.product_code=p.product_code
group by p.product_name;

select p.product_name,
((sum(e.`quantity_sold(after_promo)`) - sum(e.`quantity_sold(before_promo)`))/sum(e.`quantity_sold(before_promo)`))*100 as 'ISU%',
rank() over(order by ((sum(e.`quantity_sold(after_promo)`) - sum(e.`quantity_sold(before_promo)`))/sum(e.`quantity_sold(before_promo)`))*100  desc) as'Rank Order '
from fact_events e
left join dim_products p on e.product_code=p.product_code
group by p.product_name;




-- • What is the correlation between product category and promotion type effectiveness?
select p.category,e.promo_type,
((sum(e.`quantity_sold(after_promo)` * base_price *0.5) - sum(e.`quantity_sold(before_promo)` * base_price))/sum(e.`quantity_sold(before_promo)` * base_price))*100 as 'IR%',
rank() over(order by ((sum(e.`quantity_sold(after_promo)` * base_price *0.5) - sum(e.`quantity_sold(before_promo)` * base_price))/sum(e.`quantity_sold(before_promo)` * base_price))*100 desc) as'Rank Order '
from fact_events e
left join dim_products p on e.product_code=p.product_code
group by p.category,e.promo_type;



select p.category,
((sum(e.`quantity_sold(after_promo)`) - sum(e.`quantity_sold(before_promo)`))/sum(e.`quantity_sold(before_promo)`))*100 as 'ISU%',
rank() over(order by ((sum(e.`quantity_sold(after_promo)`) - sum(e.`quantity_sold(before_promo)`))/sum(e.`quantity_sold(before_promo)`))*100 desc) as'Rank Order '
from fact_events e
left join dim_products p on e.product_code=p.product_code
group by p.category;





