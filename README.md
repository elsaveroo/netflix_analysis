# 🎬 Netflix Content Strategy Analysis

SQL-based Exploratory Data Analysis (EDA) and Business Intelligence project using the Netflix Titles dataset. This project answers **12 business questions** covering content strategy, genre distribution, release trends, and global patterns across Netflix's catalog.

---

## 📁 Project Structure

```
netflix-analysis/
├── data/
│   └── netflix_titles.csv       # Main dataset (8,807 rows, 12 columns)
│   
├── queries/
│   └── netflix_analysis.sql     # All SQL queries (EDA + 12 Business Problems)
│   
└── README.md
```

---

## 📊 Dataset

| Attribute | Details |
|---|---|
| **Source** | [Kaggle – Netflix Movies and TV Shows](https://www.kaggle.com/datasets/shivamb/netflix-shows) |
| **Rows** | 8,807 titles |
| **Columns** | 12 |
| **Year Range** | 1925 – 2021 |
| **Tool** | MySQL 8.0+ |

### Column Reference

| Column | Description |
|---|---|
| `show_id` | Unique content ID |
| `type` | Movie or TV Show |
| `title` | Content title |
| `director` | Director name(s) |
| `casts` | Cast list (multi-value) |
| `country` | Country of production (multi-value) |
| `date_added` | Date added to Netflix |
| `release_year` | Original release year |
| `rating` | Age rating (TV-MA, PG, R, etc.) |
| `duration` | Runtime in minutes (movies) or number of seasons (TV shows) |
| `listed_in` | Genre/category tags (multi-value) |
| `description` | Short synopsis |

---

## 🔍 Business Questions

| # | Question | SQL Techniques |
|---|---|---|
| 1 | How is the catalog split between Movies and TV Shows? | `GROUP BY`, `RANK()` |
| 2 | Which rating dominates each content type? | `CTE`, `RANK() OVER PARTITION BY` |
| 3 | Which countries produce the most Netflix content? | `RECURSIVE CTE` (multi-value split) |
| 4 | What does year-over-year content growth look like? | `LAG()`, `SUM() OVER` |
| 5 | How long does content sit before being added to Netflix? | Date extraction, gap analysis |
| 6 | Who are the most frequently appearing actors on Netflix? | `RECURSIVE CTE`, `HAVING`, `RANK()` |
| 7 | How has India's share of global Netflix releases changed (YoY)? | `JOIN`, `LAG()`, window functions |
| 8 | Which genres dominate Netflix, and how do they differ by type? | `RECURSIVE CTE`, `CASE WHEN` |
| 9 | What is the ideal movie runtime on Netflix? | String parsing, bucketing, `CASE` |
| 10 | At which season do most TV Shows get cancelled? | `SUM() OVER` (survival analysis) |
| 11 | Which directors are the most prolific and internationally diverse? | `RECURSIVE CTE`, `DENSE_RANK()` |
| 12 | What does content tone distribution tell us about Netflix's strategy? | `LIKE` pattern matching, classification |

---

## 💡 Key Insights

- 🎥 **Movies dominate** the Netflix catalog at ~70% vs. 30% TV Shows.
- 🔞 **TV-MA is the top rating** across both content types — Netflix clearly targets adult audiences.
- 🇺🇸 **The United States leads** with 3,690 titles (41.9%), followed by India (11.88%) as the second-largest market.
- 📈 **Content releases peaked in 2018** (1,147 titles), then dropped sharply — signaling a shift toward fewer, higher-budget originals.
- 📺 **67% of TV Shows end after Season 1** — there is a steep "season cliff" on Netflix.
- 🕰️ **The oldest content** added to Netflix dates back to 1925, with a 93-year gap before being added to the platform.
- 🌏 **Bollywood actors dominate** the most-appearing list, led by Anupam Kher with 43 titles.

---

## 🚀 Getting Started

1. **Clone this repository:**
   ```bash
   git clone https://github.com/elsaveroo/netflix-analysis.git
   cd netflix-analysis
   ```

2. **Set up a MySQL 8.0+ database:**
   ```sql
   CREATE DATABASE netflix_db;
   USE netflix_db;
   ```

3. **Import the dataset:**
   ```sql
   LOAD DATA INFILE '/path/to/data/netflix_titles.csv'
   INTO TABLE netflix
   FIELDS TERMINATED BY ','
   ENCLOSED BY '"'
   LINES TERMINATED BY '\n'
   IGNORE 1 ROWS;
   ```
   > Alternatively, use MySQL Workbench → Table Data Import Wizard.

4. **Run the queries:**
   ```bash
   mysql -u root -p netflix_db < queries/netflix_analysis.sql
   ```

---

## 🛠️ Tech Stack

![MySQL](https://img.shields.io/badge/MySQL-8.0-4479A1?style=flat&logo=mysql&logoColor=white)
![SQL](https://img.shields.io/badge/SQL-Advanced-orange?style=flat)

**SQL concepts used:**
- Recursive CTEs (for splitting multi-value columns)
- Window Functions: `RANK()`, `DENSE_RANK()`, `LAG()`, `SUM() OVER()`
- Subqueries & CTE chaining
- String parsing with `SUBSTRING_INDEX` and `LIKE` pattern matching
- Aggregation & bucketing with `CASE WHEN`
