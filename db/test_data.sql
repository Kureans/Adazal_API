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
-- insert into refund_request values
-- (1,3,1,1,1, '2022-03-08 04:05:06', 50, '2022-03-10', 'accepted', '2022-04-02', null),
-- (2,2,1,1,1, '2022-03-08 04:05:06', 10, '2022-03-11', 'accepted', '2022-04-02', null),
-- (3,1,1,1,1, '2022-03-08 04:05:06', 40, '2022-04-01', 'accepted','2022-04-02', null),
-- (4,2,4,4,4, '2022-03-11 04:05:06', 2, '2022-04-01', 'being_handled', null, null), 
-- (5,3,5,5,5, '2022-03-12 04:05:06', 2, '2022-04-01', 'being_handled', null, null),
-- (6,2,6,2,2, '2022-03-09 04:05:06', 9, '2022-04-01', 'accepted', '2022-04-02', null),
--  (7,1,6,2,2, '2022-03-12 04:05:06', 5, '2022-04-01', 'accepted', '2022-04-02', null), 
-- (8,2,7,5,2, '2022-03-18 04:05:06', 10, '2022-04-01', 'accepted', '2022-04-02', null),
-- (9,2,3,3,3, '2022-03-10 04:05:06', 2, '2022-04-01', 'accepted', '2022-04-02', null),
-- (10,2,8,3,3, '2022-03-10 04:05:06', 2, '2022-04-01', 'accepted', '2022-04-02', null),
-- (11,2,9,7,3, '2022-03-18 13:05:06', 2, '2022-04-01', 'accepted', '2022-04-02', null),
-- (12,2,10,3,3, '2022-03-18 14:05:06 ', 2, '2022-04-01', 'accepted', '2022-04-02', null);
insert into complaint values 
(1, 'this shop sux!', 'being_handled', 3, 6),
(2, 'this shop is bad!', 'addressed', 3, 2);
insert into shop_complaint values
(1, 4);
insert into comment_complaint values
(1, 3);
insert into delivery_complaint values
(1,1,1,1,'2022-03-08 04:05:06');