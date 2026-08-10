# Chocolate Sales Performance Dashboard

End-to-end BI project: raw multi-file sales data → MySQL star schema → interactive Power BI dashboard.

![Dashboard Overview](screenshots/dashboard_overview.png)

## Overview

Built a Power BI dashboard tracking revenue, shipment volume, and store/product performance for a chocolate sales business, from five raw source files (sales, products, stores, customers, calendar). The pipeline includes SQL-based data cleaning and integrity validation, a star schema data model, and 13+ DAX measures powering the report.

**Headline numbers:** ₹25.49M revenue · 3M boxes shipped · 1M orders · 100 stores across 5 countries

## What's in this repo

```
chocolate-sales-dashboard/
├── sql/
│   └── chocolate_sales_project.sql   # Full SQL pipeline
├── powerbi/
│   └── Chocolate_Sales.pbix          # Power BI report file
├── screenshots/
│   └── dashboard_overview.png        # Full dashboard screenshot
└── README.md
```

## Tech stack

- **MySQL 8** — schema design, data cleaning, integrity checks, analytical queries
- **Power BI Desktop** — star schema data model, DAX measures, custom report theme

## Data model

Star schema: one fact table, four dimensions, single-direction relationships.

```
                dim_products
                     |
dim_customers ---- fact_sales ---- dim_stores
                     |
                dim_calendar
```

## SQL pipeline highlights

- Standardized text dates (`STR_TO_DATE`) across three source tables into proper `DATE` types
- Ran null, orphan-key, and duplicate-order integrity checks on the full fact table
- Identified a data-quality issue: **9,764 orders (~1% of records)** referenced two invalid product codes not present in the products table — documented and excluded from product-level views rather than silently dropped
- Built `fact_sales` and `dim_calendar` as clean views serving as the direct Power BI data source
- 8 analytical queries covering monthly trends, country revenue split, top-store ranking, product volume ranking, category profit margin, and loyalty-member revenue contribution

Full script: [`sql/chocolate_sales_project.sql`](sql/chocolate_sales_project.sql)

## Dashboard features

- **KPI rail** — Amount, Boxes, Shipments, with a date-range slicer
- **Monthly revenue trend** — line/area chart
- **Monthly boxes shipped** and **shipment count trend** — dual area charts
- **Revenue by country** — donut chart across 5 countries
- **Top stores table** — revenue, boxes, and shipments per store, with data bars and background color scaling
- **Boxes per product** — ranked horizontal bar chart across the full product catalog

## Key DAX measures

```dax
Total Revenue = SUM(fact_sales[revenue])
Total Boxes = SUM(fact_sales[quantity])
Total Shipments = DISTINCTCOUNT(fact_sales[order_id])
Profit Margin % = DIVIDE([Total Profit], [Total Revenue], 0)
MoM Revenue Growth % =
VAR CurrMonth = [Total Revenue]
VAR PrevMonth = CALCULATE([Total Revenue], DATEADD('dim_calendar'[date], -1, MONTH))
RETURN DIVIDE(CurrMonth - PrevMonth, PrevMonth)
```

## Business insights

- Revenue concentration across 5 countries, led by Canada (~20%) and UK (~19%)
- Store-level performance spread across 100 stores, surfaced in the Top Stores ranking
- Product-level shipping volume ranked across the full catalog to flag top and bottom performers
- Documented data-quality gap (invalid product codes) as a real finding from the validation pass, not hidden from the final output

## Setup

1. Run [`sql/chocolate_sales_project.sql`](sql/chocolate_sales_project.sql) against MySQL 8+ (update the `LOAD DATA LOCAL INFILE` paths to your local CSV locations first; requires `local_infile` enabled on both client and server).
2. Open `powerbi/Chocolate_Sales.pbix` in Power BI Desktop and point the MySQL connector at your local `chocolate_sales` database.

---
**Author:** Aquib Tahil · [LinkedIn](https://linkedin.com/in/aquibtahil/) · [GitHub](https://github.com/aquib-tahil46)
