-- ================================================================
-- Olist 电商 SQL 刷题 · 第 2 组：业务指标（共 8 题）
-- 环境：本地 MySQL 5.7 ｜ 库：olist
-- 这组全是数据分析面试的「业务题」——复购率 / RFM / 配送准时率
-- 这些词出现在简历上比「会写SQL」值钱得多，做完要能讲清口径
-- 卡壳超 30 分钟 → 看《00_答案_卡住再看.sql》
-- ================================================================

-- ============================================================
-- 第 6 题 ｜ 复购率：下过 ≥2 单的客户占全部客户的比例
-- 考察：先按客户聚合订单数，再二次聚合算比例（派生表两层）
-- 涉及表：orders / customers
-- 提示：客户口径用 customer_unique_id！这是本数据集最大的坑
--      —— customer_id 是「一单一个」，customer_unique_id 才是真人
--      直接按 customer_id 算复购率会得出接近 0% 的错误结论
-- ▶ 我的结论：
--
-- ============================================================
-- 在下面写你的 SQL：
SELECT COUNT(*) AS 客户总数,
SUM(CASE 
    WHEN cnt >= 2 THEN 1  
    ELSE 0 
END) AS 复购客户数,
ROUND(COUNT(*)*100/SUM(CASE 
    WHEN cnt >= 2 THEN 1 
    ELSE  0
END),2) AS 复购率
FROM(SELECT c.customer_unique_id, COUNT(DISTINCT o.order_id) AS cnt
FROM customers c
JOIN orders o on c.customer_id = o.customer_id 
GROUP BY c.customer_unique_id) as T

-- ============================================================
-- 第 7 题 ｜ 每月新客数 vs 老客数（新客 = 人生第一单在这个月下的）
-- 考察：首购时间（MIN）+ 派生表 JOIN
-- 涉及表：orders / customers
-- 提示：分两步 —— 先算每个客户(customer_unique_id)的首购时间，
--      按首购月份 GROUP BY 得到「每月新客数」；
--      再算「每月活跃客户数」（当月下过单的客户），
--      老客数 = 活跃客户数 - 新客数，两个结果按月份 JOIN 起来
-- ▶ 我的结论：
--
-- ============================================================
-- 在下面写你的 SQL：
SELECT M.月份,M.活跃客户数,T.新客数,M.活跃客户数-T.新客数 as 老客数
FROM(SELECT DATE_FORMAT(o.order_purchase_timestamp,'%Y-%M') AS 月份,count(DISTINCT c.customer_unique_id) as 活跃客户数
FROM customers c
JOIN orders o on c.customer_id=o.customer_id
GROUP BY 月份) as M
JOIN(SELECT DATE_FORMAT(first_order,'%Y-%M') AS 月份,COUNT(*) as 新客数
FROM(SELECT c.customer_unique_id,MIN(o.order_purchase_timestamp)as first_order
FROM customers c JOIN orders o on c.customer_id=o.customer_id
GROUP BY c.customer_unique_id ) F
GROUP BY 月份  ) T
on M.月份 = T.月份
ORDER BY M.月份  

-- ============================================================
-- 第 8 题 ｜ RFM 客户分层：给每个客户算 R / F / M 三项打分，分出高价值客户
-- 考察：多字段聚合 + CASE 打分 + 综合分层（本组压轴大题）
-- 涉及表：customers / orders / order_items
-- 提示：R = 最近一次购买距「数据集最后一天」的天数（越小越好）
--      F = 下单次数；M = 累计消费金额
--      打分（1-3 分）阈值自己定合理就行，例如：
--        R：≤90 天=3 分，≤180 天=2 分，更久=1 分
--        F：≥4 单=3 分，2-3 单=2 分，1 单=1 分
--        M：≥500 雷亚尔=3 分，≥200=2 分，更低=1 分
--      总分 ≥8 = 高价值，6-7 = 潜力，其他 = 一般
--      「数据集最后一天」用 (SELECT MAX(order_purchase_timestamp) FROM orders) 代替硬编码
-- ▶ 我的结论：
--
-- ============================================================
-- 在下面写你的 SQL：
SELECT D.customer_unique_id as 客户,R1+F1+M1 AS 总分,CASE 
    WHEN R1+F1+M1>=8 THEN  '高价值'
    WHEN 5<R1+F1+M1<8 THEN '潜力'
    ELSE  '一般'
END as 客户分层
FROM (SELECT c.customer_unique_id,CASE 
    WHEN R<=90 THEN  3
    WHEN R<=180 THEN 2
    ELSE  1
END R1,CASE 
    WHEN F>=4 THEN 3 
    WHEN 1<F<4 THEN 2
    ELSE  1
END F1,CASE 
    WHEN M>=500 THEN  3
    WHEN 200<=F<500 THEN 2
    ELSE  1
END M1
FROM
(SELECT a.customer_unique_id,DATEDIFF(a.数据集最后一天,a.最近购买日期) as R
FROM(SELECT c.customer_unique_id, MAX(o.order_purchase_timestamp) as 最近购买日期,(SELECT MAX(order_purchase_timestamp) FROM orders) as 数据集最后一天
FROM orders o
JOIN customers c on o.customer_id=c.customer_id
GROUP BY c.customer_unique_id) a ) A JOIN

(SELECT customer_unique_id,COUNT(DISTINCT o.order_id) as F
FROM customers c JOIN orders o on c.customer_id=o.customer_id
GROUP BY c.customer_unique_id) C on A.customer_unique_id = C.customer_unique_id

JOIN(SELECT c.customer_unique_id,SUM(b.price) as M
FROM(SELECT o.customer_id,oi.price
FROM order_items oi
JOIN orders o ON oi.order_id=o.order_id) b JOIN customers c on b.customer_id=c.customer_id
GROUP BY c.customer_unique_id) B on A.customer_unique_id=B.customer_unique_id) D
ORDER BY 总分 DESC


-- ============================================================
-- 第 9 题 ｜ 平均配送时长（天）与准时率（实际送达 ≤ 预计送达的占比）
-- 考察：DATEDIFF + CASE WHEN 条件聚合 + 空值过滤
-- 涉及表：orders
-- 提示：配送时长 = DATEDIFF(order_delivered_customer_date, order_purchase_timestamp)
--      只统计已送达订单：order_status = 'delivered' 且实际送达时间非空
--      准时率 = SUM(准时记1否则记0) / COUNT(*) × 100
-- ▶ 我的结论：
--
-- ============================================================
-- 在下面写你的 SQL：
SELECT AVG(DATEDIFF(order_delivered_customer_date, order_purchase_timestamp)) as 平均配送时长,SUM(CASE 
    WHEN order_delivered_customer_date<=order_estimated_delivery_date THEN  1
    ELSE  0
END)/COUNT(*) as 准时率
FROM orders
WHERE order_status = 'delivered' and order_delivered_customer_date is not NULL


-- ============================================================
-- 第 10 题 ｜ 各品类平均评分与差评率（评分≤2 占比），找口碑最差的 10 个品类
-- 考察：多表 JOIN + 评分口径处理（本组最绕的一题）
-- 涉及表：reviews / order_items / products / category_translation
-- 提示：三个口径坑，全踩明白这题就通了：
--      ① 一个订单可能有多条评价 → 先按 order_id 平均成一个分
--      ② 一个订单多件商品共享这个分 → 同订单同品类只算一次（DISTINCT）
--      ③ 品类名是葡语 → JOIN translation 表拿英文名
--      样本太少的品类没代表性，HAVING 过滤掉样本 < 50 的
-- ▶ 我的结论：
--
-- ============================================================
-- 在下面写你的 SQL：

SELECT b.品类,AVG(b.score),SUM(CASE 
    WHEN b.score<=2 THEN  1
    ELSE  0
END)*100/COUNT(*) as 差评率
FROM(SELECT DISTINCT oi.order_id,t.product_category_name_english as 品类,a.score
FROM(SELECT order_id,AVG(review_score) as score
FROM reviews r 
GROUP BY  order_id) a
JOIN order_items oi on a.order_id=oi.order_id
JOIN products p on oi.product_id=p.product_id
JOIN category_translation t on p.product_category_name=t.product_category_name) b
GROUP  BY b.品类
HAVING COUNT(*) >=50
ORDER BY 差评率 DESC
LIMIT 10
-- ============================================================
-- 第 11 题 ｜ 高评分订单（≥4 分）和低评分订单（≤2 分）的平均配送时长差多少？
-- 考察：分组对比（评分档 CASE + AVG + DATEDIFF）
-- 涉及表：orders / reviews
-- 提示：这题是在回答一个业务假设 ——「差评是不是配送慢造成的」
--      同样先按 order_id 平均评分；只算已送达的订单
-- ▶ 我的结论：

--
-- ============================================================
-- 在下面写你的 SQL：
SELECT b.评分档,COUNT(DISTINCT b.order_id) as 订单数,AVG(DATEDIFF(o.order_delivered_customer_date,o.order_purchase_timestamp)) as 配送时长
FROM(SELECT a.order_id,a.score as 评分 ,CASE 
    WHEN a.score>=4 THEN  '高评分'
    WHEN a.score<=2 THEN '低评分'
    ELSE  '中评分' 
END as 评分档
from(SELECT order_id,AVG(review_score) as score
FROM reviews
GROUP BY order_id) a) b 
JOIN orders o on b.order_id=o.order_id
WHERE o.order_status = 'delivered' and  o.order_delivered_customer_date IS NOT NULL
GROUP BY b.评分档
ORDER BY 配送时长 DESC
-- ============================================================
-- 第 12 题 ｜ 订单件数分布：1 件 / 2 件 / 3 件及以上的订单各占多少
-- 考察：先聚合（每单件数）再分桶（CASE 档位）
-- 涉及表：order_items
-- 提示：第一步按 order_id 数件数；第二步按 1/2/3+ 分档，
--      分母是全部订单数，算各档占比
-- ▶ 我的结论：
--
-- ============================================================
-- 在下面写你的 SQL：

SELECT CASE 
    WHEN a.件数=1 THEN  '一件'
    WHEN a.件数=2 THEN '两件'
    ELSE  '三件以上'
END as 档位,COUNT(*) as 订单数,COUNT(*)*100/(SELECT COUNT(DISTINCT order_id) as 总订单数 FROM orders )
FROM(SELECT order_id,COUNT(*) as 件数
FROM order_items
GROUP BY order_id) a 
GROUP BY 档位
ORDER BY 订单数 DESC

-- ============================================================
-- 第 13 题 ｜ 消费金额 TOP 10 客户画像：来自哪个州、共几单、平均客单、用过什么支付方式
-- 考察：全链路综合大题（4 张表 + 派生表 + GROUP_CONCAT）
-- 涉及表：customers / orders / order_items / payments
-- 提示：先在派生表里按 customer_unique_id 算出每人总消费，
--      ORDER BY ... LIMIT 10 锁定 TOP10；
--      再把这群人的订单连支付方式（GROUP_CONCAT(DISTINCT payment_type) 列出）
--      MySQL 5.7 没有 CTE（WITH），嵌套派生表就是标准解法
-- ▶ 我的结论：
--
-- ============================================================
-- 在下面写你的 SQL：

SELECT a.customer_unique_id,a.总消费,MAX(c1.customer_state) AS 州,COUNT(DISTINCT o1.order_id) as 单数,a.总消费/COUNT(DISTINCT o1.order_id) as 平均客单,GROUP_CONCAT(DISTINCT p.payment_type) as 支付方式
FROM(SELECT c.customer_unique_id,SUM(oi.price) as 总消费
FROM customers c
JOIN orders o on c.customer_id =o.customer_id
JOIN order_items oi on o.order_id=oi.order_id
GROUP BY c.customer_unique_id
ORDER BY 总消费 DESC
LIMIT 10) a
JOIN customers c1 on  a.customer_unique_id=c1.customer_unique_id
JOIN orders o1 on c1.customer_id=o1.customer_id
JOIN payments p on o1.order_id=p.order_id
GROUP BY a.customer_unique_id
ORDER BY a.总消费 DESC