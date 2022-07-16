/* Trigger 1 */
CREATE OR REPLACE FUNCTION product_check_fn() RETURNS TRIGGER
AS $$
DECLARE
    prod_count INT;
BEGIN
    SELECT count(shop_id) INTO prod_count
    FROM Sells
    WHERE shop_id = NEW.id;
    IF (prod_count = 0) THEN
        RAISE NOTICE 'ERROR: Each shop must sell at least 1 product.';
        DELETE FROM Shop WHERE id = NEW.id;
    END IF;
    RETURN NULL;
END
$$ LANGUAGE plpgsql;

/*
Triggers after a deferred INSERT into the Shops
table to ensure that a corresponding transaction has also inserted a
product into Sells that belongs to shop_id.
*/
DROP TRIGGER IF EXISTS product_check_trigger ON Shop;
CREATE CONSTRAINT TRIGGER product_check_trigger
AFTER INSERT ON Shop 
DEFERRABLE INITIALLY DEFERRED 
FOR EACH ROW EXECUTE FUNCTION product_check_fn();




/* Trigger 2 */
CREATE OR REPLACE FUNCTION order_check_fn() RETURNS TRIGGER
AS $$
DECLARE
    prod_count INT;
    shop_count INT;
BEGIN
    SELECT count(product_id) INTO prod_count
    FROM Orderline
    WHERE order_id = NEW.id;
    SELECT count(shop_id) INTO shop_count
    FROM Orderline
    WHERE order_id = NEW.id;
    IF (prod_count = 0 OR shop_count = 0) THEN
        RAISE NOTICE 'ERROR: An order must involve one or more products
                  from one or more shops.';
        DELETE FROM Orders WHERE id = NEW.id;
    END IF;
    RETURN NULL;
END
$$ LANGUAGE plpgsql;

/*
Triggers only after a deferred INSERT into Orders
to ensure that a corresponding transaction can insert corresponding
products and shops into the Orderline table.
*/

DROP TRIGGER IF EXISTS order_check_trigger ON Orders;
CREATE CONSTRAINT TRIGGER order_check_trigger
AFTER INSERT ON Orders
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION order_check_fn();




/* Trigger 3 */
CREATE OR REPLACE FUNCTION coupon_check_fn() RETURNS TRIGGER 
AS $$
DECLARE
    min_order_amt NUMERIC;
BEGIN
    SELECT min_order_amount INTO min_order_amt
    FROM coupon_batch
    WHERE id = NEW.coupon_id;
    IF (NEW.payment_amount < min_order_amt) THEN
        RAISE NOTICE 'A coupon can only be used on an order whose total amount 
        (before the coupon is applied) exceeds the minimum order amount.';
        NEW.coupon_id = NULL;
    END IF;
    RETURN NEW;
END
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS coupon_check_trigger ON Orders;
CREATE TRIGGER coupon_check_trigger
BEFORE INSERT ON Orders
FOR EACH ROW EXECUTE FUNCTION coupon_check_fn(); 




/* Trigger 4 */
CREATE OR REPLACE FUNCTION refund_quantity_valid()
RETURNS TRIGGER AS
$$
DECLARE totalCurrentRefundQuantity integer;
DECLARE totalOrderQuantity integer;
BEGIN

select sum(quantity) into totalCurrentRefundQuantity 
from refund_request 
where order_id = NEW.order_id
and shop_id = NEW.shop_id 
and product_id = NEW.product_id 
and status <> 'rejected';

IF totalCurrentRefundQuantity is null then
    totalCurrentRefundQuantity = 0;
end if;

select quantity into totalOrderQuantity 
from orderline 
where order_id = NEW.order_id
and shop_id = NEW.shop_id 
and product_id = NEW.product_id ;

IF totalCurrentRefundQuantity + NEW.quantity <= totalOrderQuantity then
    return NEW;
end if;

raise notice 'Refund Quantity cannot exceed Order Quantity';
return NULL;

END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER refund_quantity_valid_trigger
BEFORE INSERT 
ON refund_request
FOR EACH ROW
EXECUTE FUNCTION refund_quantity_valid();


/* Trigger 5 */
CREATE OR REPLACE FUNCTION refund_date_valid()
RETURNS TRIGGER AS
$$
DECLARE deliveryDate date;
BEGIN
    select delivery_date into deliveryDate 
    from orderline
    where order_id = NEW.order_id
    and shop_id = NEW.shop_id 
    and product_id = NEW.product_id 
    and sell_timestamp = NEW.sell_timestamp;

    if NEW.request_date <= deliveryDate + interval '30' day 
        AND NEW.request_date >= deliveryDate then
        return NEW;
    end if;

    raise notice 'outside 30 days';
    return NULL;

END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER refund_date_valid_trigger
BEFORE INSERT 
ON refund_request
FOR EACH ROW
EXECUTE FUNCTION refund_date_valid();




/* Trigger 6 */
CREATE OR REPLACE FUNCTION refund_delivered_status_only()
RETURNS TRIGGER AS
$$
DECLARE orderStatus orderline_status;
BEGIN
    select status into orderStatus 
    from orderline
    where order_id = NEW.order_id
    and shop_id = NEW.shop_id 
    and product_id = NEW.product_id 
    and sell_timestamp = NEW.sell_timestamp;

    if orderStatus = 'delivered' then
        return NEW; 
    end if;

    raise notice 'cannot refund undelivered order';
    return NULL;

END;
$$
LANGUAGE plpgsql;


CREATE OR REPLACE TRIGGER refund_delivered_status_only_trigger
BEFORE INSERT 
ON refund_request
FOR EACH ROW
EXECUTE FUNCTION refund_delivered_status_only();




/* Trigger 7 */
CREATE OR REPLACE FUNCTION review_trigger_func()
RETURNS TRIGGER AS $$
BEGIN
    IF (NEW.order_id NOT IN (
        SELECT O.id
        FROM Comment C, Users U, Orders O, Orderline L
        WHERE C.user_id = U.id
        AND U.id = O.user_id
        AND O.id = L.order_id
        AND C.id = NEW.id
    )) THEN
        RAISE EXCEPTION 'User has not bought this product hence cannot review!';
        RETURN NULL;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS review_trigger ON Review;
CREATE TRIGGER review_trigger
BEFORE INSERT ON Review
FOR EACH ROW EXECUTE FUNCTION review_trigger_func();




/* Trigger 8 */
CREATE OR REPLACE FUNCTION check_comment_type()
RETURNS TRIGGER AS $$
BEGIN
    IF ((
        SELECT COUNT(*) 
        FROM Reply 
        WHERE id = NEW.id
    ) = 1) THEN
        RETURN NEW;
    ELSIF ((
        SELECT COUNT(*) 
        FROM Review
        WHERE id = NEW.id 
    ) = 1) THEN
        RETURN NEW;
    ELSE
        RAISE EXCEPTION 'Each comment must be either a review or a reply';
        RETURN NULL;
    END IF;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS check_comment_type_trigger ON Comment;
CREATE CONSTRAINT TRIGGER check_comment_type_trigger
AFTER INSERT ON Comment
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION check_comment_type();

CREATE OR REPLACE FUNCTION insert_review_trigger_func()
RETURNS TRIGGER AS $$
BEGIN
    IF (NEW.id IN (SELECT id FROM Reply)) THEN
        RAISE EXCEPTION 'This comment is already a reply!';
        RETURN NULL;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS insert_review_trigger ON Review;
CREATE TRIGGER insert_review_trigger
BEFORE INSERT ON Review
FOR EACH ROW EXECUTE FUNCTION insert_review_trigger_func();


CREATE OR REPLACE FUNCTION insert_reply_trigger_func()
RETURNS TRIGGER AS $$
BEGIN
    IF (NEW.id IN (SELECT id FROM Review)) THEN
        RAISE EXCEPTION 'This comment is already a review!';
        RETURN NULL;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS insert_reply_trigger ON Reply;
CREATE TRIGGER insert_reply_trigger
BEFORE INSERT ON Reply
FOR EACH ROW EXECUTE FUNCTION insert_reply_trigger_func();




/* Trigger 9 */
CREATE OR REPLACE FUNCTION reply_version_trigger_func()
RETURNS TRIGGER AS $$
BEGIN
    IF ((
        SELECT COUNT(reply_timestamp) 
        FROM Reply_Version 
        WHERE reply_id = NEW.id
    ) > 0) THEN 
        RETURN NEW;
    ELSE
        RAISE EXCEPTION 'Each new reply must be added with a reply_verison in the same transaction';
        RETURN NULL;
    END IF;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS reply_version_trigger ON Reply;
CREATE CONSTRAINT TRIGGER reply_version_trigger
AFTER INSERT ON Reply
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION reply_version_trigger_func();




/* Trigger 10 */
CREATE OR REPLACE FUNCTION check_num_review_version()
RETURNS TRIGGER AS $$   
BEGIN
    IF ((
        SELECT COUNT(review_timestamp) 
        FROM review_version 
        WHERE review_id = NEW.id
    ) > 0) THEN
        RETURN NEW;
    ELSE
        RAISE EXCEPTION 'Each new review must be added with a review_verison in the same transaction';
        RETURN NULL;
    END IF;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS num_review_version_trigger ON review;
CREATE CONSTRAINT TRIGGER num_review_version_trigger
AFTER INSERT ON review 
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION check_num_review_version();




/* Trigger 11 */
CREATE OR REPLACE FUNCTION check_valid_delivery_complaint()
RETURNS TRIGGER AS $$   
BEGIN
    IF ((
        SELECT DISTINCT status FROM orderline
        WHERE order_id = NEW.order_id AND shop_id = NEW.shop_id 
        AND product_id = NEW.product_id 
        AND sell_timestamp = NEW.sell_timestamp
    ) = 'delivered') THEN
        RETURN NEW;
    ELSE
        RAISE NOTICE 'Delivery complaints can only be made once product has been delivered';
        RETURN NULL;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER valid_delivery_complaint_trigger
BEFORE INSERT ON delivery_complaint
FOR EACH ROW EXECUTE FUNCTION check_valid_delivery_complaint();




/* Trigger 12 */
CREATE OR REPLACE FUNCTION check_overlapped_shop_complaint()
RETURNS TRIGGER AS $$   
BEGIN
    IF (EXISTS(SELECT 1 FROM comment_complaint WHERE id = NEW.id)) THEN
        RAISE NOTICE 'Comment complaint with that id already exists, overlapping complaints are not allowed';
        RETURN NULL;
    ELSIF (EXISTS(SELECT 1 FROM delivery_complaint WHERE id = NEW.id)) THEN
        RAISE NOTICE 'Delivery complaint with that id already exists, overlapping complaints are not allowed';
        RETURN NULL;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER overlapped_shop_complaint_trigger
BEFORE INSERT ON shop_complaint
FOR EACH ROW EXECUTE FUNCTION check_overlapped_shop_complaint();


CREATE OR REPLACE FUNCTION check_overlapped_comment_complaint()
RETURNS TRIGGER AS $$   
BEGIN
    IF (EXISTS(SELECT 1 FROM shop_complaint WHERE id = NEW.id)) THEN
        RAISE NOTICE 'Shop complaint with that id already exists, overlapping complaints are not allowed';
        RETURN NULL;
    ELSIF (EXISTS(SELECT 1 FROM delivery_complaint WHERE id = NEW.id)) THEN
        RAISE NOTICE 'Delivery complaint with that id already exists, overlapping complaints are not allowed';
        RETURN NULL;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER overlapped_comment_complaint_trigger
BEFORE INSERT ON comment_complaint
FOR EACH ROW EXECUTE FUNCTION check_overlapped_comment_complaint();


CREATE OR REPLACE FUNCTION check_overlapped_delivery_complaint()
RETURNS TRIGGER AS $$   
BEGIN
    IF (EXISTS(SELECT 1 FROM shop_complaint WHERE id = NEW.id)) THEN
        RAISE NOTICE 'Shop complaint with that id already exists, overlapping complaints are not allowed';
        RETURN NULL;
    ELSIF (EXISTS(SELECT 1 FROM comment_complaint WHERE id = NEW.id)) THEN
        RAISE NOTICE 'Comment complaint with that id already exists, overlapping complaints are not allowed';
        RETURN NULL;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER overlapped_delivery_complaint_trigger
BEFORE INSERT ON delivery_complaint
FOR EACH ROW EXECUTE FUNCTION check_overlapped_delivery_complaint();




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
