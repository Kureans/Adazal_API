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

