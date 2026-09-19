# 方案 B：MySQL 连上跑 · 操作指南

> 你的机器我已经检查过了：**MySQL 5.7.44 已装好、服务（MySQL57）正在运行、Workbench 8.0 也有、9 张 CSV 数据齐**。
> 所以不用装任何东西，只差"连上 + 导数据"这一步，照下面做就行。
> 整理日期：2026-09-03

---

## 一、一键导入（推荐，2-3 分钟搞定）

第 1 步：打开一个终端
- **VSCode**：打开 `C:\Users\22136\WorkBuddy\Claw\sql-python-project` 文件夹 → 菜单 Terminal → New Terminal
- 或者 **Win+R** 输 `cmd` 回车，再执行：
  ```
  cd /d C:\Users\22136\WorkBuddy\Claw\sql-python-project
  ```

第 2 步：运行
```
python import_olist.py
```

第 3 步：提示输密码时，**输入你的 MySQL root 密码**（屏幕不显示是正常的，输完直接回车）

第 4 步：等它跑完，看到最后 8 行全是 **PASS** 就成了。脚本自动干了这些事：
- 建库 `olist`（utf8mb4 字符集，葡萄牙语品类名不会乱码）
- 建 8 张表（含主键、索引、正确的日期类型）
- 导入全部数据并逐表核对行数

> 重复跑没问题：每次先删旧表再建，随时可以重来。
> 首次运行会自动装一个小驱动（pymysql，约 10 秒），需要联网。
> geolocation 那张百万行的表没导——项目用不到，省时间。

---

## 二、连上 Workbench 看表（导完做这步）

1. 开始菜单打开 **MySQL Workbench 8.0 CE**
2. 首页点 **+**（MySQL Connections 右边的方框）：
   - Connection Name：`local57`（随便起）
   - Hostname：`127.0.0.1`　Port：`3306`　Username：`root`
   - 点 **Test Connection** → 输 root 密码 → OK → Save password 可以勾上
3. 双击连接进去 → 左侧点开 **olist → Tables**，8 张表都在
4. 顶部点 **SQL 加号图标**（新建查询窗口），输入：
   ```sql
   USE olist;
   SELECT COUNT(*) FROM orders;
   ```
   点闪电图标执行（Ctrl+Enter），出 99441 就是全通了

---

## 三、然后直接开做第 1 题

```sql
USE olist;

-- 第1题：每个州的客户数、订单量、GMV，按 GMV 降序
SELECT c.customer_state,
       COUNT(DISTINCT c.customer_id)                    AS 客户数,
       COUNT(DISTINCT o.order_id)                       AS 订单量,
       ROUND(SUM(oi.price + oi.freight_value), 2)       AS GMV
FROM customers c
JOIN orders      o  ON o.customer_id = c.customer_id
JOIN order_items oi ON oi.order_id   = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY GMV DESC;
```

写完存到 `sql_answers.sql`，接着按题单往下刷。注意 MySQL 5.7 里日期函数用 `DATE_FORMAT(purchase_timestamp,'%Y-%m')` 取月份（框架里 SQLite 的 strftime 不通用，这个换一下就行）。

---

## 四、出问题对照表

| 报错 | 原因 | 解决 |
|------|------|------|
| `Access denied for user 'root'` | 密码错 | 重跑一遍，密码重新输 |
| `Can't connect to MySQL server` | 服务没跑 | Win+R 输 `services.msc` → 找 **MySQL57** → 右键启动 |
| `No module named pymysql` 装失败 | 网络问题 | 换手机热点再跑一次 |
| 想确认导没导成功 | — | 跑 `python import_olist.py --verify` |
| CSV 怀疑有问题 | — | 跑 `python import_olist.py --dryrun` |
| 忘了密码 | 密码无法找回 | 跟我说，我给你走重置流程 |

---

## 五、进度对照（框架第三节的完成标志）

- [ ] 第 1 阶段：数据入库（本指南 + `import_olist.py`）
- [ ] 第 2 阶段：SQL 20 题（第 3-7 天）
- [ ] 第 3 阶段：Python 清洗 + 出图（第 8-11 天）
- [ ] 第 4 阶段：报告 + 简历条目 + 面试自述（第 12-14 天）
