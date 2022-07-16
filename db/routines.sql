/* Procedure 1 */
CREATE OR REPLACE PROCEDURE place_order
    (user_id INTEGER, coupon_id INTEGER, shipping_address TEXT,
    shop_ids INTEGER[], product_ids INTEGER[], sell_timestamps TIMESTAMP[],
    quantities INTEGER[], shipping_costs NUMERIC[])
AS $$
DECLARE
    arr_count_flag INTEGER;
    arr_itr INTEGER = 1;
    i INTEGER;
    paymentAmount NUMERIC = 0;
    rewardAmount NUMERIC;
    prod_price NUMERIC;
    shop_prod_qty INTEGER;
BEGIN

    SELECT array_length(shop_ids, 1) INTO arr_count_flag;  
    SELECT reward_amount INTO rewardAmount FROM coupon_batch WHERE id = coupon_id;
    SELECT (COALESCE(max(id), 0) + 1) INTO i FROM orders;   
    INSERT INTO orders VALUES (i, user_id, coupon_id, shipping_address, NULL);
    WHILE arr_itr <= arr_count_flag LOOP
        SELECT quantity INTO shop_prod_qty FROM Sells
        WHERE (shop_id = shop_ids[arr_itr] AND product_id = product_ids[arr_itr] 
        AND sell_timestamp = sell_timestamps[arr_itr]); 
        IF (shop_prod_qty < quantities[arr_itr]) THEN
            RAISE EXCEPTION 'Ordered amount for product id % is greater than the amount the shop currently owns', product_ids[arr_itr]; 
        END IF;
        SELECT price INTO prod_price FROM Sells 
        WHERE (shop_id = shop_ids[arr_itr] AND product_id = product_ids[arr_itr] 
        AND sell_timestamp = sell_timestamps[arr_itr]); 
        
        paymentAmount = paymentAmount + (prod_price * quantities[arr_itr] + shipping_costs[arr_itr]);

        INSERT INTO orderline VALUES (i, shop_ids[arr_itr], product_ids[arr_itr], 
        sell_timestamps[arr_itr], quantities[arr_itr], shipping_costs[arr_itr], 
        'being_processed', NULL);
        UPDATE Sells SET quantity = (quantity - quantities[arr_itr]) WHERE (shop_id = shop_ids[arr_itr] 
        AND product_id = product_ids[arr_itr] AND sell_timestamp = sell_timestamps[arr_itr]); 
        arr_itr = arr_itr + 1;
    END LOOP;

    IF (coupon_id IS NOT NULL) THEN
        IF (paymentAmount > (SELECT min_order_amount FROM coupon_batch WHERE id = coupon_id)) THEN
            paymentAmount = paymentAmount - rewardAmount;
        ELSE
            RAISE NOTICE 'Total payment amount does not meet the minimum order amount of the coupon. Coupon will not be applied to the order.';
        END IF;
    END IF; 
    UPDATE orders SET payment_amount = paymentAmount WHERE id = i;
END
$$ LANGUAGE plpgsql;




/* Procedure 2 */
CREATE OR REPLACE PROCEDURE review
(user_id INTEGER, order_id INTEGER, shop_id INTEGER, 
product_id INTEGER, sell_timestamp TIMESTAMP, content TEXT, 
rating INTEGER, comment_timestamp TIMESTAMP)
AS $$
DECLARE
    comment_id INTEGER;
BEGIN
    comment_id = (SELECT COALESCE(max(id), 0) FROM comment) + 1;
    INSERT INTO comment VALUES (comment_id, user_id);
    INSERT INTO review VALUES (
        comment_id, order_id, shop_id, product_id, sell_timestamp
    );
    INSERT INTO review_version VALUES (
        comment_id, comment_timestamp, content, rating
    );
END
$$ LANGUAGE plpgsql;




/* Procedure 3 */
CREATE OR REPLACE PROCEDURE reply (
    user_id INTEGER,
    other_comment_id INTEGER,
    content TEXT,
    reply_timestamp TIMESTAMP
)
AS $$
DECLARE 
    comment_id INTEGER;
BEGIN
    comment_id = (SELECT COALESCE(max(id), 0) FROM comment) + 1;
    INSERT INTO Comment VALUES (comment_id, user_id);
    INSERT INTO Reply VALUES (comment_id, other_comment_id);
    INSERT INTO Reply_Version VALUES (comment_id, reply_timestamp, content);
END
$$ LANGUAGE plpgsql;




/* Function 1 */
CREATE OR REPLACE FUNCTION view_comments( 
    shop_id INTEGER, 
    product_id INTEGER, 
    sell_timestamp TIMESTAMP 
)
RETURNS TABLE (
    username TEXT, 
    content TEXT, 
    rating INTEGER,
    comment_timestamp TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE r_comment AS (
        SELECT DISTINCT 
            R1.id AS id,
            (CASE WHEN U1.account_closed THEN 'A Deleted User' ELSE U1.name END) AS name, 
            S1.content AS content,
            S1.rating AS rating,
            S1.review_timestamp AS comment_timestamp
        FROM Review R1, Review_Version S1, Comment C1, Users U1
        WHERE R1.shop_id = $1
        AND R1.product_id = $2
        AND R1.sell_timestamp = $3
        AND R1.id = S1.review_id
        AND S1.review_timestamp IN (
            SELECT MAX(review_timestamp)
            FROM Review_Version
            GROUP BY review_id
        )
        AND C1.id = R1.id
        AND C1.user_id = U1.id

        UNION

        SELECT DISTINCT 
            R2.id AS id,
            (CASE WHEN U2.account_closed THEN 'A Deleted User' ELSE U2.name END) AS name, 
            S2.content AS content, 
            0 AS rating,
            S2.reply_timestamp AS comment_timestamp
        FROM Reply R2, Reply_Version S2, Comment C2, Users U2, r_comment Z
        WHERE R2.other_comment_id = Z.id
        AND R2.id = S2.reply_id
        AND S2.reply_timestamp IN (
            SELECT MAX(reply_timestamp)
            FROM Reply_Version
            GROUP BY reply_id
        )
        AND C2.id = R2.id
        AND C2.user_id = U2.id
    )
    SELECT A.name, A.content, A.rating, A.comment_timestamp 
    FROM r_comment A 
    ORDER BY A.comment_timestamp, A.id;
END;
$$ LANGUAGE plpgsql;




/* Function 2 */
CREATE OR REPLACE FUNCTION get_most_returned_products_from_manufacturer(IN manufacturer_id integer, n INTEGER)
RETURNS TABLE(product_id INTEGER, product_name TEXT, return_rate NUMERIC(3, 2)) 
as $$ 

BEGIN

return query

with 
product_returned_quantity as (
    select r.product_id, sum(quantity) as total_returned
    from refund_request r
    where status = 'accepted'
    group by r.product_id
), 

product_delivered_quantity as (
    select p.id as product_id , p.name as product_name,  coalesce(sum(o.quantity), 0) as total_delivered
    from orderline o full join product p
    on p.id = o.product_id
    where manufacturer = manufacturer_id
    and (status = 'delivered' 
    or status is null)
    group by p.id, p.name
)


select 
d.product_id, d.product_name, 
case 
when d.total_delivered = 0 then 0.00
else (total_returned::numeric/total_delivered::numeric)::numeric(3,2) 
end as return_rate
from product_returned_quantity r natural right join  product_delivered_quantity d
order by return_rate desc
limit n;


END; 
$$ LANGUAGE plpgsql; 




/* Function 3 */
CREATE OR REPLACE FUNCTION get_worst_shops(IN n integer)
RETURNS TABLE(shop_id INTEGER, shop_name TEXT, num_negative_indicators INTEGER) as $$ 
DECLARE  
BEGIN
    IF (n < 1) THEN 
        RAISE EXCEPTION 'Value of n must be greater than 0';
    ELSE 
        RETURN QUERY
        WITH shop_refund_requests_num AS (
            SELECT DISTINCT sid, COUNT(*) AS num_refund_requests
            FROM (
                SELECT DISTINCT order_id, R.shop_id AS sid, product_id, sell_timestamp 
                FROM refund_request R
            ) AS DR
            GROUP BY sid
        ),
        shop_complaint_num AS (
            SELECT DISTINCT S.shop_id AS sid, COUNT(id) AS num_shop_complaints 
            FROM shop_complaint S
            GROUP BY S.shop_id
        ),
        delivery_complaint_num AS (
            SELECT DISTINCT sid, COUNT(*) AS num_delivery_complaints 
            FROM (
                SELECT DISTINCT order_id, D.shop_id AS sid, product_id, sell_timestamp 
                FROM delivery_complaint D
            ) AS distinct_orderline_delivery_complaints
            GROUP BY sid
        ),
        one_star_review_num AS (
            SELECT DISTINCT R.shop_id AS sid, COUNT(*) AS num_one_star_reviews
            FROM review R
            WHERE id IN (
                SELECT DISTINCT LR.review_id 
                FROM (
                    SELECT review_id, MAX(review_timestamp) AS latest
                    FROM review_version
                    GROUP BY review_id
                ) AS LR INNER JOIN review_version AS RV ON LR.review_id = RV.review_id
                WHERE review_timestamp = latest AND rating = 1
            )
            GROUP BY R.shop_id
        ),
        shop_negative_indicators AS (
            SELECT DISTINCT id, name, 
                COALESCE(num_refund_requests, 0) AS n1, 
                COALESCE(num_shop_complaints, 0) AS n2,
                COALESCE(num_delivery_complaints, 0) AS n3,
                COALESCE(num_one_star_reviews, 0) AS n4
            FROM ((((shop
                FULL OUTER JOIN shop_refund_requests_num AS R ON id = R.sid)
                FULL OUTER JOIN shop_complaint_num AS S ON id = S.sid) 
                FULL OUTER JOIN delivery_complaint_num AS C ON id = C.sid) 
                FULL OUTER JOIN one_star_review_num AS O ON id = O.sid)
        )
        SELECT DISTINCT id AS shop_id, 
            name AS shop_name, (n1 + n2 + n3 + n4)::int AS num_negative_indicators 
        FROM shop_negative_indicators
        ORDER BY num_negative_indicators DESC, shop_id ASC
        LIMIT n;
    END IF;
END; 
$$ LANGUAGE plpgsql; 