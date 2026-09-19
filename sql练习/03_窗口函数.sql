-- ================================================================
-- Olist 电商 SQL 刷题 · 第 3 组：窗口函数（共 7 题）
--
-- ⚠️ 重要：窗口函数是 MySQL 8.0 才有的功能，你本机 5.7 跑不了这组题！
--
-- 启用方法（一次性，30 秒）：
--   桌面找《启动MySQL80_右键以管理员运行.cmd》→ 右键以管理员身份运行
--   它会把机器上已装的 MySQL 8.0 起在 3307 端口（不动你的 5.7）
--   然后喊我一声，我把 olist 数据导进 8.0，VSCode 里加个 3307 的连接就能刷了
--
-- 为什么值得折腾：笔试面试里窗口函数是「区分会不会SQL」的分水岭，
-- RANK / ROW_NUMBER / LAG / NTILE 全是原题高频。
-- ================================================================

-- ▼▼▼ 每次打开这个文件，先选中下面这一行单独执行（切到 olist 库）▼▼▼
USE olist;

-- ============================================================
-- 第 14 题 ｜ 每月 GMV 环比增长率（本月 vs 上月）
-- 考察：LAG() —— 窗口函数第一课
-- 提示：LAG(GMV) OVER (ORDER BY 月份) 自动取「上一行」的值
--      环比 = (本月 - 上月) / 上月 × 100，注意除零不用管（第一行是 NULL）
-- ▶ 我的结论：2016-09 起量期 GMV 仅 354.75，环比数值失真；进入 2017 年后从 13.7 万涨到 58 万+，其中 4 月(-4.5%)、6 月(-14.2%) 出现两次回落。
--
-- ============================================================
-- 在下面写你的 SQL：
SELECT 月份,
       GMV,
       LAG(GMV) OVER (ORDER BY 月份) AS 上月GMV,
       ROUND(100 * (GMV - LAG(GMV) OVER (ORDER BY 月份))
             / LAG(GMV) OVER (ORDER BY 月份), 2) AS 环比增长率百分比
FROM (
  SELECT DATE_FORMAT(o.order_purchase_timestamp,') AS 月份,
         ROUND(SUM(oi.price + oi.freight_value), 2) AS GMV
  FROM orders o
  JOIN order_items oi ON o.order_id = oi.order_id
  GROUP BY 月份
) t
ORDER BY 月份;%Y-%m'



-- ============================================================
-- 第 15 题 ｜ 各品类销量排名 TOP 10（体会 RANK 和 DENSE_RANK 的区别）
-- 考察：RANK() OVER
-- 提示：先派生表算各品类销量，再开窗排名；
--      有并列销量时 RANK 会跳号（1,1,3），DENSE_RANK 不跳（1,1,2）——
--      两种都跑一遍，跟自己讲清楚差别，面试爱问
-- ▶ 我的结论：bed_bath_table 以 11115 件居首；RANK 遇并列会跳号(1,1,3)，DENSE_RANK 不跳(1,1,2)。
--
-- ============================================================
-- 在下面写你的 SQL：
SELECT 品类, 销量,
       RANK()       OVER (ORDER BY 销量 DESC) AS 排名_RANK,
       DENSE_RANK() OVER (ORDER BY 销量 DESC) AS 排名_DENSE
FROM (
  SELECT ct.product_category_name_english AS 品类, COUNT(*) AS 销量
  FROM order_items oi
  JOIN products p ON oi.product_id = p.product_id
  JOIN category_translation ct ON p.product_category_name = ct.product_category_name
  GROUP BY 品类
) t
ORDER BY 排名_RANK
LIMIT 10;



-- ============================================================
-- 第 16 题 ｜ 每个品类里销量前 3 的商品（分组 TopN，笔试原题常客）
-- 考察：ROW_NUMBER() OVER (PARTITION BY ... ORDER BY ...)
-- 提示：PARTITION BY 品类 = 「每个品类内部单独编号」
--      编完号 rn <= 3 就是组内前三；思考一下换成 RANK 行不行？
-- ▶ 我的结论：用 ROW_NUMBER 每个品类固定取 3 个；换成 RANK 会把并列第三的一并带出来，行数变多。
--
-- ============================================================
-- 在下面写你的 SQL：
SELECT 品类, 商品, 商品销量, rn
FROM (
  SELECT c.product_category_name_english AS 品类,
         p.product_id AS 商品,
         COUNT(*) AS 商品销量,
         ROW_NUMBER() OVER (PARTITION BY c.product_category_name_english
                            ORDER BY COUNT(*) DESC) AS rn
  FROM order_items oi
  JOIN products p ON oi.product_id = p.product_id
  JOIN category_translation c ON p.product_category_name = c.product_category_name
  GROUP BY 品类, oi.product_id
) t
WHERE rn <= 3
ORDER BY 品类, 商品销量 DESC;



-- ============================================================
-- 第 17 题 ｜ 帕累托分析：销量累计贡献到 80% 的是前几个品类（二八法则）
-- 考察：SUM() OVER 累计求和
-- 提示：SUM(销量) OVER (ORDER BY 销量 DESC) = 从大到小的累计销量
--      SUM(销量) OVER () = 不排序的总和（分母）
--      累计占比 ≤ 80% 的品类留下来，数数有几个 —— 就是「几个品类干了80%的量」
-- ▶ 我的结论：前 15 个品类累计占比正好 80.0%（第 15 个是 electronics），二八法则成立。
--
-- ============================================================
-- 在下面写你的 SQL：
SELECT 品类, 销量, 累计销量,
       ROUND(100 * 累计销量 / 总销量, 1) AS 累计占比百分比
FROM (
  SELECT 品类, 销量,
         SUM(销量) OVER (ORDER BY 销量 DESC) AS 累计销量,
         SUM(销量) OVER () AS 总销量
  FROM (
    SELECT ct.product_category_name_english AS 品类, COUNT(*) AS 销量
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    JOIN category_translation ct ON p.product_category_name = ct.product_category_name
    GROUP BY 品类
  ) s
) w
WHERE 累计销量 / 总销量 <= 0.8
ORDER BY 销量 DESC;



-- ============================================================
-- 第 18 题 ｜ 卖家销售额百分位：每个卖家超越了全平台百分之多少的卖家
-- 考察：PERCENT_RANK() OVER
-- 提示：PERCENT_RANK 返回 0~1，0 是第一名，越接近 1 排名越靠后
--      展示销售额 TOP 20 的卖家及其百分位即可
-- ▶ 我的结论：头部卖家销售额 249,640.70，百分位 0 —— 超越全平台 100% 的卖家；长尾卖家百分位趋近 1。
--
-- ============================================================
-- 在下面写你的 SQL：
SELECT seller_id AS 卖家,
       ROUND(销售额, 2) AS 销售额,
       ROUND(100 * PERCENT_RANK() OVER (ORDER BY 销售额 DESC), 1) AS 超越百分比
FROM (
  SELECT seller_id, SUM(price + freight_value) AS 销售额
  FROM order_items
  GROUP BY seller_id
) t
ORDER BY 销售额 DESC
LIMIT 20;



-- ============================================================
-- 第 19 题 ｜ 每月 GMV 的 3 个月移动平均（抹平波动看趋势）
-- 考察：ROWS BETWEEN ... AND ... 窗口边界
-- 提示：AVG(GMV) OVER (ORDER BY 月份 ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)
--      = 本月和前两个月一起平均；思考：把 2 改成 3 是几月平均？
-- ▶ 我的结论：3 个月移动平均把单月尖刺抹平了；首月只有一个数据点，均线等于自身(355)。
--
-- ============================================================
-- 在下面写你的 SQL：
SELECT 月份, GMV,
       ROUND(AVG(GMV) OVER (ORDER BY 月份
             ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 0) AS 三月移动平均
FROM (
  SELECT DATE_FORMAT(o.order_purchase_timestamp,'%Y-%m') AS 月份,
         ROUND(SUM(oi.price + oi.freight_value), 2) AS GMV
  FROM orders o
  JOIN order_items oi ON o.order_id = oi.order_id
  GROUP BY 月份
) t
ORDER BY 月份;



-- ============================================================
-- 第 20 题 ｜ 把所有订单按金额分成低/中/高三档（客单价分桶）
-- 考察：NTILE(3) 均匀分桶
-- 提示：NTILE(3) OVER (ORDER BY 订单金额) 把订单按金额顺序均分三份
--      档位 1=低客单 2=中客单 3=高客单；对比一下 CASE 手动阈值分桶的差别
--      （NTILE 按人数均分，CASE 按金额区间分 —— 口径不同，面试能聊）
-- ▶ 我的结论：NTILE(3) 把订单均分成低/中/高三档，最高档订单金额 13,664.08。
--
-- ============================================================
-- 在下面写你的 SQL：
SELECT order_id, 订单金额,
       NTILE(3) OVER (ORDER BY 订单金额) AS 档位编号,
       CASE NTILE(3) OVER (ORDER BY 订单金额)
            WHEN 1 THEN '低客单'
            WHEN 2 THEN '中客单'
            WHEN 3 THEN '高客单'
       END AS 档位
FROM (
  SELECT order_id, SUM(price + freight_value) AS 订单金额
  FROM order_items
  GROUP BY order_id
) a
ORDER BY 订单金额 DESC;


