# -*- coding: utf-8 -*-
"""
Olist 电商数据一键导入 MySQL（本地 MySQL 5.7，方案B）
================================================
用法（在 sql-python-project 目录下打开终端）：
    python import_olist.py            # 正常导入：输 root 密码 -> 建库建表导数据 -> 核对行数
    python import_olist.py --verify   # 只连上看各表行数（不导入，导完想复查用这个）
    python import_olist.py --dryrun   # 不连数据库，只检查 CSV 能不能正常读（排错用）

说明：
- 密码用 getpass 输入，屏幕不显示，输入完直接回车
- 重复运行会先 DROP 再建，随时可以重来
- geolocation 表（百万行、项目用不到）没有导入
"""
import csv
import os
import sys
import getpass
import subprocess

DATA_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'data')
DB_NAME = 'olist'

# ---------------------------------------------------------------- 表结构定义
TABLES = [
    ('customers', 'olist_customers_dataset.csv', """
        CREATE TABLE customers (
            customer_id            CHAR(32)     NOT NULL,
            customer_unique_id     CHAR(32),
            customer_zip_code_prefix INT,
            customer_city          VARCHAR(60),
            customer_state         CHAR(2),
            PRIMARY KEY (customer_id),
            KEY idx_cuid (customer_unique_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    """),
    ('orders', 'olist_orders_dataset.csv', """
        CREATE TABLE orders (
            order_id                   CHAR(32)    NOT NULL,
            customer_id                CHAR(32),
            order_status               VARCHAR(20),
            order_purchase_timestamp   DATETIME,
            order_approved_at          DATETIME,
            order_delivered_carrier_date DATETIME,
            order_delivered_customer_date DATETIME,
            order_estimated_delivery_date DATETIME,
            PRIMARY KEY (order_id),
            KEY idx_ocid (customer_id),
            KEY idx_opt (order_purchase_timestamp)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    """),
    ('order_items', 'olist_order_items_dataset.csv', """
        CREATE TABLE order_items (
            order_id            CHAR(32)      NOT NULL,
            order_item_id       TINYINT,
            product_id          CHAR(32),
            seller_id            CHAR(32),
            shipping_limit_date DATETIME,
            price               DECIMAL(10,2),
            freight_value       DECIMAL(10,2),
            PRIMARY KEY (order_id, order_item_id),
            KEY idx_ipid (product_id),
            KEY idx_isid (seller_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    """),
    ('payments', 'olist_order_payments_dataset.csv', """
        CREATE TABLE payments (
            order_id            CHAR(32)     NOT NULL,
            payment_sequential  TINYINT,
            payment_type        VARCHAR(20),
            payment_installments INT,
            payment_value       DECIMAL(10,2),
            PRIMARY KEY (order_id, payment_sequential)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    """),
    ('reviews', 'olist_order_reviews_dataset.csv', """
        CREATE TABLE reviews (
            review_id               CHAR(32)    NOT NULL,
            order_id                CHAR(32),
            review_score            TINYINT,
            review_comment_title    VARCHAR(140),
            review_comment_message  TEXT,
            review_creation_date    DATETIME,
            review_answer_timestamp DATETIME,
            KEY idx_rid (review_id),
            KEY idx_roid (order_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    """),
    ('products', 'olist_products_dataset.csv', """
        CREATE TABLE products (
            product_id                 CHAR(32)    NOT NULL,
            product_category_name      VARCHAR(50),
            product_name_lenght        SMALLINT,
            product_description_lenght INT,
            product_photos_qty         TINYINT,
            product_weight_g           INT,
            product_length_cm          SMALLINT,
            product_height_cm          SMALLINT,
            product_width_cm           SMALLINT,
            PRIMARY KEY (product_id),
            KEY idx_pcat (product_category_name)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    """),
    ('sellers', 'olist_sellers_dataset.csv', """
        CREATE TABLE sellers (
            seller_id               CHAR(32)  NOT NULL,
            seller_zip_code_prefix  INT,
            seller_city             VARCHAR(60),
            seller_state            CHAR(2),
            PRIMARY KEY (seller_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    """),
    ('category_translation', 'product_category_name_translation.csv', """
        CREATE TABLE category_translation (
            product_category_name         VARCHAR(50) NOT NULL,
            product_category_name_english  VARCHAR(60),
            PRIMARY KEY (product_category_name)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    """),
]


def read_csv_rows(path):
    """读 CSV -> (列名列表, 行元组列表)。空字符串转 None，BOM 用 utf-8-sig 处理。"""
    with open(path, 'r', encoding='utf-8-sig', newline='') as f:
        reader = csv.reader(f)
        header = next(reader)
        rows = []
        for r in reader:
            if not r or all(c == '' for c in r):
                continue
            rows.append(tuple(None if c == '' else c for c in r))
    return header, rows


def ensure_pymysql():
    try:
        import pymysql  # noqa
        return
    except ImportError:
        print('[setup] 首次运行，正在安装 pymysql（约10秒）...')
        try:
            subprocess.check_call([sys.executable, '-m', 'pip', 'install',
                                    'pymysql', '--quiet'])
        except subprocess.CalledProcessError as e:
            print('[setup] 安装失败，请手动执行下面这条命令后再运行脚本：')
            print('    python -m pip install pymysql')
            raise SystemExit(1)
        # 安装完再确认一次
        try:
            import pymysql  # noqa
            print('[setup] 安装完成')
        except ImportError:
            print('[setup] 安装后仍找不到 pymysql，请重开终端再试')
            raise SystemExit(1)


def connect(pymysql, password):
    return pymysql.connect(
        host='127.0.0.1', port=3306, user='root', password=password,
        charset='utf8mb4', autocommit=False,
    )


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else ''

    # ---- dryrun：只验证 CSV 读取
    if mode == '--dryrun':
        print('[dryrun] 只读 CSV 不连数据库\n')
        for name, fname, _ in TABLES:
            header, rows = read_csv_rows(os.path.join(DATA_DIR, fname))
            print('  {:<22} {:>7} 行  首列样例: {}'.format(name, len(rows), rows[0][0]))
        print('\n[dryrun] CSV 全部可正常读取，可以正式导入了')
        return

    ensure_pymysql()
    import pymysql

    print('=' * 52)
    print('Olist 数据导入 MySQL（本地 5.7）')
    print('=' * 52)
    password = getpass.getpass('请输入 MySQL root 密码（输入时不显示）: ')

    try:
        conn = connect(pymysql, password)
    except pymysql.err.OperationalError as e:
        print('\n[失败] 连不上：{}\n  -> 密码错就重跑一遍；服务没跑就 Win+R 输 services.msc 找 MySQL57 点启动'.format(e))
        sys.exit(1)

    cur = conn.cursor()

    # ---- verify：只看行数
    if mode == '--verify':
        cur.execute('SHOW TABLES FROM olist')
        tables = [r[0] for r in cur.fetchall()]
        if not tables:
            print('[提示] olist 库还是空的，先跑 python import_olist.py 导入')
        else:
            print('\nolist 库现有表：')
            for t in tables:
                cur.execute('SELECT COUNT(*) FROM olist.{}'.format(t))
                print('  {:<22} {:>7} 行'.format(t, cur.fetchone()[0]))
        conn.close()
        return

    # ---- 正式导入
    print('\n[1/3] 建库建表 ...')
    cur.execute(
        'CREATE DATABASE IF NOT EXISTS {} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci'.format(DB_NAME))
    cur.execute('USE {}'.format(DB_NAME))
    for name, _, ddl in TABLES:
        cur.execute('DROP TABLE IF EXISTS {}'.format(name))
        cur.execute(ddl)
    conn.commit()

    print('[2/3] 导入数据（共 8 张表，约 1-3 分钟）...')
    for name, fname, _ in TABLES:
        header, rows = read_csv_rows(os.path.join(DATA_DIR, fname))
        cols = ', '.join(header)
        placeholders = ', '.join(['%s'] * len(header))
        sql = 'INSERT INTO {} ({}) VALUES ({})'.format(name, cols, placeholders)
        for i in range(0, len(rows), 2000):
            cur.executemany(sql, rows[i:i + 2000])
        conn.commit()
        print('  {:<22} {:>7} 行  OK'.format(name, len(rows)))

    print('[3/3] 核对行数 ...')
    all_ok = True
    for name, fname, _ in TABLES:
        cur.execute('SELECT COUNT(*) FROM {}'.format(name))
        db_cnt = cur.fetchone()[0]
        csv_cnt = len(read_csv_rows(os.path.join(DATA_DIR, fname))[1])
        ok = 'PASS' if db_cnt == csv_cnt else '!! MISMATCH'
        if db_cnt != csv_cnt:
            all_ok = False
        print('  {:<22} 库:{}  csv:{}  {}'.format(name, db_cnt, csv_cnt, ok))

    conn.close()
    if all_ok:
        print('\n全部导入成功！接下来：')
        print('  1. Workbench 连上后点 olist 库 -> Tables 就能看到 8 张表')
        print('  2. 新建 Query 窗口先跑一句: USE olist; SELECT COUNT(*) FROM orders;')
        print('  3. 开做第 1 题：各州客户数/订单量/GMV（题单见《SQL_Python项目_两周冲刺框架》）')
    else:
        print('\n有表行数对不上，把上面输出发给智多星看一眼')


if __name__ == '__main__':
    main()
