drop table if exists users , shop , category , manufacturer , product , sells , coupon_batch , issued_coupon , orders , orderline , comment , review_version , reply , reply_version , employee , refund_request , complaint , shop_complaint , comment_complaint , delivery_complaint, review 
cascade;

CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    address TEXT,
    name TEXT,
    account_closed BOOLEAN
);

CREATE TABLE shop (
    id SERIAL PRIMARY KEY,
    name TEXT
);

-- Combines Category, Has
CREATE TABLE category (
    id SERIAL PRIMARY KEY,
    name TEXT,
    parent INTEGER REFERENCES category(id)
);

CREATE TABLE manufacturer (
    id SERIAL PRIMARY KEY,
    name TEXT,
    country TEXT
);

-- Combines Product, Belongs to, Manufactured by
CREATE TABLE product (
    id SERIAL PRIMARY KEY,
    name TEXT,
    description TEXT,
    -- Enforce Key+TP constraint
    category INTEGER NOT NULL REFERENCES category(id),
    -- Enforce Key+TP constraint
    manufacturer INTEGER NOT NULL REFERENCES manufacturer(id)
);

CREATE TABLE sells (
    shop_id INTEGER REFERENCES shop(id),
    product_id INTEGER REFERENCES product(id),
    sell_timestamp TIMESTAMP,
    price NUMERIC,
    quantity INTEGER,
    PRIMARY KEY (shop_id, product_id, sell_timestamp)
);

CREATE TABLE coupon_batch (
    id SERIAL PRIMARY KEY,
    valid_period_start DATE,
    valid_period_end DATE,
    reward_amount NUMERIC,
    min_order_amount NUMERIC,
    -- Enforce constraint that reward amount is lower than minimum order_amount
    CHECK (reward_amount <= min_order_amount),
    -- Enforce cnonstraint that start date <= end date
    CHECK (valid_period_start <= valid_period_end)
);

CREATE TABLE issued_coupon (
    user_id INTEGER REFERENCES users(id),
    coupon_id INTEGER REFERENCES coupon_batch(id),
    PRIMARY KEY (user_id, coupon_id)
);

-- Combines Order, Places, Applies
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
     -- Enforce Key+TP constraint
    user_id INTEGER REFERENCES users(id) NOT NULL,
    coupon_id INTEGER,
    shipping_address TEXT,
    payment_amount NUMERIC,
    -- Enforce constraint that user can only use a coupon that was issued to them
    FOREIGN KEY (user_id, coupon_id) REFERENCES issued_coupon(user_id, coupon_id),
    -- Enforce constraint that a particular issued coupon can only be applied once
    UNIQUE (user_id, coupon_id)
);

CREATE TYPE orderline_status AS ENUM (
    'being_processed', 
    'shipped', 
    'delivered'
);

-- Rename Involves to Orderline
CREATE TABLE orderline (
    order_id INTEGER REFERENCES orders(id),
    shop_id INTEGER,
    product_id INTEGER,
    sell_timestamp TIMESTAMP,
    quantity INTEGER,
    shipping_cost NUMERIC,
    status orderline_status,
    delivery_date DATE,
    FOREIGN KEY (shop_id, product_id, sell_timestamp) REFERENCES sells(shop_id, product_id, sell_timestamp),
    PRIMARY KEY (order_id, shop_id, product_id, sell_timestamp),
    -- Enforce constraint that delivery date is null when being_processed, and not null otherwise
    CHECK ((status = 'being_processed' AND delivery_date IS NULL) OR (status <> 'being_processed' AND delivery_date IS NOT NULL))
);

-- Combines Comment, Makes
CREATE TABLE comment (
    id SERIAL PRIMARY KEY,
    -- Enforce Key+TP constraint
    user_id INTEGER REFERENCES users(id) NOT NULL
);

-- Combines Review, On
CREATE TABLE review (
    id INTEGER PRIMARY KEY REFERENCES comment(id) ON DELETE CASCADE,
    -- Enforce Key+TP constraint
    order_id INTEGER NOT NULL,
    shop_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    sell_timestamp TIMESTAMP NOT NULL,
    FOREIGN KEY (order_id, shop_id, product_id, sell_timestamp) REFERENCES orderline(order_id, shop_id, product_id, sell_timestamp),
    -- Enforce constraint that a particular product purchase can only be reviewed once
    UNIQUE (order_id, shop_id, product_id, sell_timestamp)
);

-- Combines ReviewVersion, HasReviewVersion
CREATE TABLE review_version (
    review_id INTEGER REFERENCES review ON DELETE CASCADE,
    review_timestamp TIMESTAMP,
    content TEXT,
    rating INTEGER,
    PRIMARY KEY (review_id, review_timestamp),
    -- Enforce range of values for rating
    CHECK (1 <= rating AND rating <= 5)
);

-- Combines Reply, To
CREATE TABLE reply (
    id INTEGER PRIMARY KEY REFERENCES comment(id) ON DELETE CASCADE,
    -- Enforce Key+TP constraint
    other_comment_id INTEGER REFERENCES comment(id) NOT NULL
);

-- Combines Reply_Version, HasReplyVersion
CREATE TABLE reply_version (
    reply_id INTEGER REFERENCES reply ON DELETE CASCADE,
    reply_timestamp TIMESTAMP,
    content TEXT,
    PRIMARY KEY (reply_id, reply_timestamp)
);

CREATE TABLE employee (
    id SERIAL PRIMARY KEY,
    name TEXT,
    salary NUMERIC
);

CREATE TYPE refund_status AS ENUM (
    'pending',
    'being_handled',
    'accepted',
    'rejected'
);

-- Combines RefundRequest, HandlesRefund, For
CREATE TABLE refund_request (
    id SERIAL PRIMARY KEY,
    -- Enforce key constraint
    handled_by INTEGER REFERENCES employee(id),
    -- Enforce key + tp constraint
    order_id INTEGER NOT NULL,
    shop_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    sell_timestamp TIMESTAMP NOT NULL,
    quantity INTEGER,
    request_date DATE,
    status refund_status,
    handled_date DATE,
    rejection_reason TEXT,
    FOREIGN KEY (order_id, shop_id, product_id, sell_timestamp) REFERENCES orderline(order_id, shop_id, product_id, sell_timestamp),
    -- Enforce constraint that refund is accepted/rejected after the request is made
    CHECK (handled_date >= request_date),
    -- Enforce constraint that rejection reason should be null unless refund request is rejected
    CHECK ((status = 'rejected' AND rejection_reason IS NOT NULL) OR (status <> 'rejected' AND rejection_reason IS NULL)),
    -- Enforce constraint that refund handled_date should be null unless refund is handled
    CHECK (((status = 'pending' OR status = 'being_handled') AND handled_date IS NULL) OR ((status = 'accepted' OR status = 'rejected') AND handled_date IS NOT NULL)),
    -- Enforce constraint that refund handled_by should be null if status is pending, and non-null otherwise
    CHECK (((status = 'pending' AND handled_by IS NULL) OR (status <> 'pending' AND handled_by IS NOT NULL)))
);

CREATE TYPE complaint_status AS ENUM (
    'pending',
    'being_handled',
    'addressed'
);

-- Combines Complaint, HandlesComplaint, Files
CREATE TABLE complaint (
    id SERIAL PRIMARY KEY,
    content TEXT,
    status complaint_status,
    user_id INTEGER REFERENCES users(id),
    -- Enforce key constraint
    handled_by INTEGER REFERENCES employee(id),
    -- Enforce valid values for status and handled_by
    CHECK ((status = 'pending' AND handled_by IS NULL) OR (status <> 'pending' AND handled_by IS NOT NULL))
);

-- Combines ShopComplaint, ConcernsShop
CREATE TABLE shop_complaint (
    id INTEGER PRIMARY KEY REFERENCES complaint(id) ON DELETE CASCADE,
    -- Enforce Key+TP constraint
    shop_id INTEGER REFERENCES shop(id) NOT NULL
);

-- Combines CommentComplaint, ConcernsComment
CREATE TABLE comment_complaint (
    id INTEGER PRIMARY KEY REFERENCES complaint(id) ON DELETE CASCADE,
    -- Enforce Key+TP constraint
    comment_id INTEGER REFERENCES comment(id) NOT NULL
);

-- Combines DeliveryComplaint, ConcernsDelivery
CREATE TABLE delivery_complaint (
    id INTEGER PRIMARY KEY REFERENCES complaint(id) ON DELETE CASCADE,
    -- Enforce Key+TP constraint
    order_id INTEGER NOT NULL,
    shop_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    sell_timestamp TIMESTAMP NOT NULL,
    FOREIGN KEY (order_id, shop_id, product_id, sell_timestamp) REFERENCES orderline(order_id, shop_id, product_id, sell_timestamp)
);








/*

insert into users values
(1, 'Address One', 'Alice', false),
(2, 'Address Two', 'Bob', false),
(3, 'Address Three', 'Carol', false),
(4, 'Address Four', 'Dork', false),
(5, 'Address Five', 'Elis', false),
(6, 'Address Six', 'Fargo', false),
(7, 'Address Seven', 'George', false),
(8, 'Address Eight', 'Henry', false);


insert into shop values
(1, 'Shop One'),
(2, 'Shop Two'),
(3, 'Shop Three'),
(4, 'Shop Four'),
(5, 'Shop Five'),
(6, 'Shop Six'),
(7, 'Shop Seven'),
(8, 'Shop Eight');


insert into category values
(1, 'Cat 1', null),
(2, 'Cat 2', null),
(3, 'Cat 3', null),
(4, 'Cat 4', 2),
(5, 'Cat 5', 1);

insert into manufacturer values
(1, 'Manufacturer 1', 'SG'),
(2, 'Manufacturer 2', 'Sweden'),
(3, 'Manufacturer 3', 'Kazahkstan'),
(4, 'Manufacturer 4', 'China'),
(5, 'Manufacturer 5', 'Iran');


insert into product values
(1, 'Product 1', 'pest control', 1, 1),
(2, 'Product 2', 'Electronics', 2, 1),
(3, 'Product 3', 'Decorations', 3, 2),
(4, 'Product 4', 'Kitchen', 4, 3),
(5, 'Product 5', 'Art', 5, 3),
(6, 'Product 6', 'Music', 1, 3),
(7, 'Product 7', 'Food', 2, 1),
(8, 'Product 8', 'Books', 3, 2),
(9, 'Product 9', 'Photography', 4, 5),
(10, 'Product 10', 'Blah blah', 3, 4),
(11, 'Product 11', 'Hello Desc', 4, 3),
(12, 'Product 12', 'Best item', 2, 4);


--shop_id, prod_id, selltime,price,qty
insert into sells values
(1, 1, '2022-03-08 04:05:06' , 10, 10),
(2, 2, '2022-03-09 04:05:06' , 22, 10),
(3, 3, '2022-03-10 04:05:06' , 33, 3),
(4, 4, '2022-03-11 04:05:06' , 40, 3),
(5, 5, '2022-03-12 04:05:06' , 50, 8),
(6, 6, '2022-03-13 04:05:06' , 60, 8),
(1, 7, '2022-03-14 04:05:06' , 70, 70),
(1, 8, '2022-03-15 04:05:06' , 33, 60),
(1, 9, '2022-03-16 04:05:06' , 80, 5),
(2, 10, '2022-03-17 04:05:06' , 30, 10),
(5, 2, '2022-03-18 04:05:06' , 22, 1),
(5, 1, '2022-03-18 05:05:06' , 30, 1),
(5, 4, '2022-03-18 06:05:06' , 30, 1),
(5, 7, '2022-03-18 07:05:06' , 30, 1),
(6, 8, '2022-03-18 08:05:06' , 30, 1),
(6, 5, '2022-03-18 09:05:06' , 30, 1),
(6, 10, '2022-03-18 10:05:06' , 30, 1),
(7, 8, '2022-03-18 11:05:06' , 30, 1),
(7, 4, '2022-03-18 12:05:06' , 30, 1),
(7, 3, '2022-03-18 13:05:06' , 33, 1),
(1, 1, '2022-03-09 04:05:06' , 10, 399),
(3, 3, '2022-03-18 14:05:06' , 33, 1);

insert into coupon_batch values 
(1, '2022-03-08', '2022-03-15', 10, 50),
(2, '2022-03-08', '2022-03-15', 3, 30),
(3, '2022-03-08', '2022-03-15', 1, 10);


insert into issued_coupon values 
(1, 1),
(2, 1),
(3, 2),
(3, 3),
(4, 1),
(5, 2),
(6, 3),
(6, 2),
(6, 1);


insert into orders values
(1, 1, null, 'Ship Add1', 80),
(2, 2, 1, 'Ship Add2', 80),
(3, 3, 3, 'Ship Add3', 80),
(4, 4, 1, 'Ship Add4', 80),
(5, 5, 2, 'Ship Add5', 80),
(6, 6, 2, 'Ship Add6', 80),
(7, 6, null, 'Ship Add6', 80),
(8, 6, null, 'Ship Add6', 80),
(9, 6, null, 'Ship Add6', 80),
(10, 6, null, 'Ship Add6', 80),
(11, 6, null, 'Ship Add6', 80),
(12, 6, null, 'Ship Add6', 80),
(13, 6, null, 'Ship Add6', 80);

--orderid, shopid, prod_id, selltime, qty, shipcost, status, deli_date
insert into orderline values
(1,1,1,'2022-03-08 04:05:06', 100, 3, 'delivered', '2022-03-10' ),
(13,1,1,'2022-03-09 04:05:06', 399, 3, 'shipped', '2022-03-10' ),
(2,2,2,'2022-03-09 04:05:06', 22, 3, 'delivered', '2022-03-16' ),
(3,3,3,'2022-03-10 04:05:06', 33, 3, 'delivered', '2022-03-17' ),
(4,4,4,'2022-03-11 04:05:06', 40, 3, 'delivered', '2022-03-18' ),
(5,5,5,'2022-03-12 04:05:06', 9, 3, 'shipped', '2022-03-19' ), 
(6,2,2,'2022-03-09 04:05:06 ', 10, 3, 'shipped', '2022-03-19' ), -- here
(7,5,2,'2022-03-18 04:05:06', 22, 3, 'delivered', '2022-03-19' ),
(8,3,3,'2022-03-10 04:05:06', 33, 3, 'delivered', '2022-03-19' ),
(9,7,3,'2022-03-18 13:05:06', 33, 3, 'delivered', '2022-03-19' ),
(10,3,3,'2022-03-18 14:05:06', 33, 3, 'delivered', '2022-03-19' );



insert into comment values
(1, 1),
(2, 2),
(3, 3),
(4, 4),
(5, 5),
(6, 1),
(7, 2),
(8, 3);

insert into review values
(1,1,1,1,'2022-03-08 04:05:06' ),
(2,2,2,2,'2022-03-09 04:05:06' ),
(3,3,3,3,'2022-03-10 04:05:06' ),
(4,4,4,4,'2022-03-11 04:05:06' );

insert into review_version values
(1,'2022-03-08 04:05:06', 'Review Text 1', 5 ),
(2,'2022-03-08 09:05:06', 'Review Text 2', 4 );


insert into reply values
(1, 5),
(2, 6),
(3, 7);

insert into reply_version values
(1,'2022-03-08 04:05:06', 'Reply Text 1'),
(2,'2022-03-08 09:05:06', 'Reply Text 2' );


insert into employee values
(1, 'Emp 1', 5000),
(2, 'Emp 2', 6000),
(3, 'Emp 3', 6000),
(4, 'Emp 4', 7000),
(5, 'Emp 5', 8000),
(6, 'Emp 6', 9000);

-- id, handledby, orderid, shopid, prodid selltime, qty, reqdate, status, handled, rej
insert into refund_request values
(1,3,1,1,1, '2022-03-08 04:05:06', 50, '2022-03-10', 'accepted', '2022-04-02', null),
(2,2,1,1,1, '2022-03-08 04:05:06', 10, '2022-03-11', 'accepted', '2022-04-02', null),
(3,1,1,1,1, '2022-03-08 04:05:06', 40, '2022-04-01', 'accepted','2022-04-02', null),
(4,2,4,4,4, '2022-03-11 04:05:06', 2, '2022-04-01', 'being_handled', null, null), 
(5,3,5,5,5, '2022-03-12 04:05:06', 2, '2022-04-01', 'being_handled', null, null),
(6,2,6,2,2, '2022-03-09 04:05:06', 9, '2022-04-01', 'accepted', '2022-04-02', null),
 (7,1,6,2,2, '2022-03-12 04:05:06', 5, '2022-04-01', 'accepted', '2022-04-02', null), 
(8,2,7,5,2, '2022-03-18 04:05:06', 10, '2022-04-01', 'accepted', '2022-04-02', null),
(9,2,3,3,3, '2022-03-10 04:05:06', 2, '2022-04-01', 'accepted', '2022-04-02', null),
(10,2,8,3,3, '2022-03-10 04:05:06', 2, '2022-04-01', 'accepted', '2022-04-02', null),
(11,2,9,7,3, '2022-03-18 13:05:06', 2, '2022-04-01', 'accepted', '2022-04-02', null),
(12,2,10,3,3, '2022-03-18 14:05:06 ', 2, '2022-04-01', 'accepted', '2022-04-02', null);

insert into complaint values 
(1, 'this shop sux!', 'being_handled', 3, 6),
(2, 'this shop is bad!', 'addressed', 3, 2);

insert into shop_complaint values
(1, 4);


insert into comment_complaint values
(1, 3);



insert into delivery_complaint values
(1,1,1,1,'2022-03-08 04:05:06');

*/



