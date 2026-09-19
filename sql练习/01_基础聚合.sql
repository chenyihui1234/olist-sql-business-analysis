-- ================================================================
-- Olist 电商 SQL 刷题 · 第 1 组：基础聚合（共 5 题）
-- 环境：本地 MySQL 5.7 ｜ 库：olist ｜ 表前记得 USE olist;
-- 用法：每题在注释下方写你自己的 SQL，光标点进语句里按 Ctrl+Enter 单独运行
-- 习惯：跑完在「我的结论」写一行你看到的结果 —— 攒起来就是报告素材
-- 卡壳超 30 分钟 → 打开《00_答案_卡住再看.sql》看思路，别死磕
-- ================================================================

-- ============================================================
-- 第 1 题 ｜ 每个州的客户数、订单量、GMV，按 GMV 降序
-- 考察：三表 JOIN + GROUP BY + 排序
-- 涉及表：customers / orders / order_items
-- 提示：GMV = SUM(price + freight_value)
--      客户数必须用 customer_unique_id（customer_id 是一单一个，直接 COUNT 会虚高）
--      订单量用 COUNT(DISTINCT order_id)，防 JOIN 重复计数
-- ▶ 我的结论：
--
-- ============================================================
-- 在下面写你的 SQL：

SELECT c.customer_state 州,
COUNT(DISTINCT c.customer_unique_id) 客户数,
COUNT(DISTINCT o.order_id) 订单量,
ROUND(SUM(oi.price + oi.freight_value)) GMV
FROM customers AS c
JOIN orders o on c.customer_id = o.customer_id
JOIN order_items oi on o.order_id =oi.order_id 
GROUP BY c.customer_state
ORDER BY GMV DESC

-- ============================================================
-- 第 2 题 ｜ 各订单状态（delivered/canceled 等）的订单数与占比
-- 考察：单表 GROUP BY + 占比计算（总数做分母）
-- 涉及表：orders
-- 提示：占比 = 本状态订单数 / 全部订单数 × 100
--      分母可以用标量子查询 (SELECT COUNT(*) FROM orders)
-- ▶ 我的结论：
--
-- ============================================================
-- 在下面写你的 SQL：
SELECT order_status 状态, 
COUNT(*) 订单数,
ROUND(COUNT(*)*100/(SELECT COUNT(*) FROM orders))
FROM orders
GROUP BY 状态
ORDER BY 订单数

-- ============================================================
-- 第 3 题 ｜ 算每笔订单的商品金额和运费，找出「运费比商品还贵」的订单
-- 考察：先聚合再过滤（GROUP BY + HAVING）
-- 涉及表：order_items
-- 提示：一个订单多件商品，先按 order_id 聚合出每单的商品总额和运费总额
--      HAVING 里比较两个 SUM，按运费降序看最夸张的
-- ▶ 我的结论：
--
-- ============================================================
-- 在下面写你的 SQL：
SELECT order_id,sum(price) 商品金额,SUM(freight_value) 运费
FROM order_items
GROUP BY order_id
HAVING SUM(price) < SUM(freight_value)
ORDER BY 运费 desc


-- ============================================================
-- 第 4 题 ｜ 2017 全年每月的 GMV 与订单量趋势
-- 考察：日期函数 + 多表 JOIN + 按时间序列排序
-- 涉及表：orders / order_items
-- 提示：月份用 DATE_FORMAT(order_purchase_timestamp,'%Y-%m')（MySQL 写法）
--      过滤 2017 年：YEAR(order_purchase_timestamp) = 2017
--      记得按月份排序（看趋势），不是按金额
-- ▶ 我的结论：
--
-- ============================================================
-- 在下面写你的 SQL：
SELECT DATE_FORMAT(o.order_purchase_timestamp,'%Y-%m') 月份,
COUNT(DISTINCT o.order_id) 订单量,
SUM(oi.price + oi.freight_value) GMV
FROM orders o
JOIN order_items oi on o.order_id=oi.order_id
WHERE YEAR(o.order_purchase_timestamp) = 2017
GROUP BY 月份
ORDER BY 月份


-- ============================================================
-- 第 5 题 ｜ 各支付方式的笔数、总金额、金额占比、笔均金额
-- 考察：单表聚合 + 占比 + 均值
-- 涉及表：payments
-- 提示：支付方式字段 payment_type（credit_card / boleto / voucher 等）
--      金额占比的分母是全表总支付金额；笔均 = 总金额 / 笔数
-- ▶ 我的结论：
--
-- ============================================================
-- 在下面写你的 SQL：
SELECT payment_type 支付方式,
COUNT(*) 笔数,
SUM(payment_value) 总金额,
SUM(payment_value)*100/(SELECT SUM(payment_value) FROM payments) 金额占比,
SUM(payment_value)/COUNT(*) as 笔均金额
FROM payments
GROUP BY payment_type
