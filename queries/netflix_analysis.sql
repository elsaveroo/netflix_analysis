-- ============================================================
--   NETFLIX CONTENT STRATEGY ANALYSIS
--   Dataset : netflix_titles.csv  (8,807 rows · 12 columns)
--   Tools   : MySQL 8.0+
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- SCHEMA SETUP
-- ─────────────────────────────────────────────────────────────

CREATE TABLE netflix (
    show_id      VARCHAR(10),
    type         VARCHAR(10),
    title        VARCHAR(300),
    director     VARCHAR(600),
    casts        VARCHAR(1100),
    country      VARCHAR(600),
    date_added   VARCHAR(60),
    release_year INT,
    rating       VARCHAR(15),
    duration     VARCHAR(20),
    listed_in    VARCHAR(300),
    description  VARCHAR(600)
);


-- ─────────────────────────────────────────────────────────────
-- EDA — EXPLORATORY DATA ANALYSIS
-- ─────────────────────────────────────────────────────────────

-- 0a. Total row count
SELECT COUNT(*) AS total_titles FROM netflix;

-- 0b. Null / missing values per column
SELECT column_name, missing_count
FROM (
    SELECT 'director'    AS column_name, SUM(CASE WHEN director   IS NULL OR director   = '' THEN 1 ELSE 0 END) AS missing_count FROM netflix UNION ALL
    SELECT 'country',                    SUM(CASE WHEN country    IS NULL OR country    = '' THEN 1 ELSE 0 END) FROM netflix UNION ALL
    SELECT 'date_added',                 SUM(CASE WHEN date_added IS NULL OR date_added = '' THEN 1 ELSE 0 END) FROM netflix UNION ALL
    SELECT 'rating',                     SUM(CASE WHEN rating     IS NULL OR rating     = '' THEN 1 ELSE 0 END) FROM netflix UNION ALL
    SELECT 'casts',                      SUM(CASE WHEN casts      IS NULL OR casts      = '' THEN 1 ELSE 0 END) FROM netflix
) AS null_summary
ORDER BY missing_count DESC;

-- 0c. Dataset overview snapshot
SELECT
    COUNT(*)                AS total_titles,
    COUNT(DISTINCT type)    AS distinct_types,
    COUNT(DISTINCT rating)  AS distinct_ratings,
    MIN(release_year)       AS earliest_year,
    MAX(release_year)       AS latest_year,
    SUM(CASE WHEN director IS NULL OR director = '' THEN 1 ELSE 0 END) AS missing_director
FROM netflix;


-- ─────────────────────────────────────────────────────────────
-- BUSINESS PROBLEM 1
-- How is the content split between Movies and TV Shows,
-- and what is each type's catalog share?
-- ─────────────────────────────────────────────────────────────

SELECT
    type,
    COUNT(*)                                                         AS total_titles,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM netflix), 2)     AS pct_share,
    RANK() OVER (ORDER BY COUNT(*) DESC)                             AS dominance_rank
FROM netflix
GROUP BY type;

/*
INSIGHT ──────────────────────────────────────────────────────
Movies account for ~69.6% (6,131) vs TV Shows at ~30.4% (2,676).
This 2.3:1 ratio reflects Netflix's heavy focus on film content.
*/


-- ─────────────────────────────────────────────────────────────
-- BUSINESS PROBLEM 2
-- Which rating category dominates each content type, and
-- how does the distribution compare?
-- ─────────────────────────────────────────────────────────────

WITH rating_counts AS (
    SELECT
        type,
        rating,
        COUNT(*) AS total
    FROM netflix
    WHERE rating IS NOT NULL AND rating <> ''
    GROUP BY type, rating
),
ranked AS (
    SELECT
        type,
        rating,
        total,
        ROUND(total * 100.0 / SUM(total) OVER (PARTITION BY type), 1) AS pct_within_type,
        RANK() OVER (PARTITION BY type ORDER BY total DESC)            AS rnk
    FROM rating_counts
)
SELECT
    type,
    rating              AS top_rating,
    total               AS title_count,
    pct_within_type,
    rnk                 AS rank_within_type
FROM ranked
WHERE rnk <= 3
ORDER BY type, rnk;

/*
INSIGHT
TV-MA is the #1 rating for BOTH content types:
- Movies   : TV-MA (33.6%) > TV-14 (23.3%) > R (13.0%)
- TV Shows : TV-MA (42.8%) > TV-14 (27.4%) > TV-PG (12.1%)
Netflix's catalog strongly targets adult audiences across all content types.
*/


-- ─────────────────────────────────────────────────────────────
-- BUSINESS PROBLEM 3
-- Which countries produce the most Netflix content?
-- (Handles multi-country co-productions like "US, India")
-- ─────────────────────────────────────────────────────────────

WITH RECURSIVE splitter AS (
    SELECT
        show_id,
        TRIM(SUBSTRING_INDEX(country, ',', 1))                      AS country_val,
        IF(LOCATE(',', country) > 0,
           SUBSTRING(country, LOCATE(',', country) + 1),
           NULL)                                                      AS remaining
    FROM netflix
    WHERE country IS NOT NULL AND country <> ''
    UNION ALL
    SELECT
        show_id,
        TRIM(SUBSTRING_INDEX(remaining, ',', 1)),
        IF(LOCATE(',', remaining) > 0,
           SUBSTRING(remaining, LOCATE(',', remaining) + 1),
           NULL)
    FROM splitter
    WHERE remaining IS NOT NULL
)
SELECT
    country_val                                                       AS country,
    COUNT(*)                                                          AS total_titles,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM netflix), 2)     AS catalog_pct,
    RANK() OVER (ORDER BY COUNT(*) DESC)                             AS world_rank
FROM splitter
WHERE country_val <> ''
GROUP BY country_val
ORDER BY total_titles DESC
LIMIT 15;

/*
INSIGHT
USA dominates with 3,690 titles (41.9% of the catalog).
India is #2 with 1,046 titles (11.88%) but the gap is massive
a 3.5x difference showing how US-centric Netflix content still is.
UK (806), Canada (445), and France (393) round out the top 5.
Asia is well represented with Japan (#6), South Korea (#8), and China (#11).
*/


-- ─────────────────────────────────────────────────────────────
-- BUSINESS PROBLEM 4
-- What is the year-over-year growth of Netflix releases,
-- and when did the content library peak?
-- ─────────────────────────────────────────────────────────────

WITH yearly AS (
    SELECT
        release_year,
        COUNT(*) AS releases
    FROM netflix
    WHERE release_year BETWEEN 2010 AND 2021
    GROUP BY release_year
)
SELECT
    release_year,
    releases,
    LAG(releases)  OVER (ORDER BY release_year)                      AS prev_year_releases,
    releases - LAG(releases) OVER (ORDER BY release_year)            AS yoy_change,
    ROUND(
        (releases - LAG(releases) OVER (ORDER BY release_year))
        * 100.0
        / NULLIF(LAG(releases) OVER (ORDER BY release_year), 0)
    , 1)                                                              AS yoy_growth_pct,
    SUM(releases) OVER (ORDER BY release_year)                       AS cumulative_total,
    CASE
        WHEN releases = MAX(releases) OVER () THEN 'PEAK YEAR'
        ELSE ''
    END                                                               AS note
FROM yearly
ORDER BY release_year;

/*
INSIGHT
Content peaked in 2018 at 1,147 titles with 11.1% YoY growth.
Post-2018 declined sharply, dropping 37.9% by 2021 (592 titles),
signaling a shift from bulk licensing to fewer high-budget originals.
The cumulative library grew from 194 to 7,472 titles over 11 years.
*/


-- ─────────────────────────────────────────────────────────────
-- BUSINESS PROBLEM 5
-- How long does content sit before being added to Netflix?
-- Which titles had the longest "shelf gap"?
-- ─────────────────────────────────────────────────────────────

WITH parsed AS (
    SELECT
        title,
        type,
        release_year,
        -- Extract the 4-digit year from the end of date_added string
        CAST(RIGHT(TRIM(date_added), 4) AS UNSIGNED)                 AS year_added
    FROM netflix
    WHERE date_added IS NOT NULL
      AND date_added <> ''
      AND LENGTH(TRIM(date_added)) >= 4
),
gap_calc AS (
    SELECT
        title,
        type,
        release_year,
        year_added,
        year_added - release_year                                     AS years_on_shelf
    FROM parsed
    WHERE year_added >= release_year
)
SELECT
    title,
    type,
    release_year,
    year_added,
    years_on_shelf,
    CASE
        WHEN years_on_shelf = 0             THEN 'Same Year'
        WHEN years_on_shelf BETWEEN 1 AND 2 THEN 'Quick Add (1-2 yr)'
        WHEN years_on_shelf BETWEEN 3 AND 5 THEN 'Delayed (3-5 yr)'
        ELSE                                     'Archive Content (5+ yr)'
    END                                                               AS shelf_category
FROM gap_calc
ORDER BY years_on_shelf DESC
LIMIT 20;

/*
INSIGHT
The oldest content added was "Pioneers: First Women Filmmakers" (1925),
added to Netflix in 2018 with a 93-year shelf gap. Notably, 14 of the
top 20 longest gaps are WWII-era documentaries (1942-1945) that Netflix
bulk-added in 2017, suggesting a deliberate historical documentary
acquisition strategy. The longest gap for a Movie is 75 years
(The Battle of Midway, 1942 added 2017).
*/


-- ─────────────────────────────────────────────────────────────
-- BUSINESS PROBLEM 6
-- Who are the most frequently appearing actors on Netflix,
-- and are they primarily in Movies or TV Shows?
-- ─────────────────────────────────────────────────────────────

WITH RECURSIVE actor_split AS (
    SELECT
        show_id,
        type,
        country,
        release_year,
        TRIM(SUBSTRING_INDEX(casts, ',', 1))                         AS actor,
        IF(LOCATE(',', casts) > 0,
           SUBSTRING(casts, LOCATE(',', casts) + 1),
           NULL)                                                       AS remaining
    FROM netflix
    WHERE casts IS NOT NULL AND casts <> ''
    UNION ALL
    SELECT
        show_id, type, country, release_year,
        TRIM(SUBSTRING_INDEX(remaining, ',', 1)),
        IF(LOCATE(',', remaining) > 0,
           SUBSTRING(remaining, LOCATE(',', remaining) + 1),
           NULL)
    FROM actor_split
    WHERE remaining IS NOT NULL
)
SELECT
    actor,
    COUNT(*)                                                           AS total_appearances,
    SUM(CASE WHEN type = 'Movie'   THEN 1 ELSE 0 END)                AS movies,
    SUM(CASE WHEN type = 'TV Show' THEN 1 ELSE 0 END)                AS tv_shows,
    COUNT(DISTINCT country)                                            AS countries_worked_in,
    MIN(release_year)                                                  AS debut_year,
    MAX(release_year)                                                  AS latest_year,
    MAX(release_year) - MIN(release_year)                             AS active_span_yrs,
    RANK() OVER (ORDER BY COUNT(*) DESC)                              AS appearance_rank
FROM actor_split
WHERE actor <> ''
GROUP BY actor
HAVING COUNT(*) >= 5
ORDER BY total_appearances DESC
LIMIT 15;

/*
INSIGHT
Anupam Kher leads with 43 appearances (42 movies, 1 TV show) and a
29-year active span (1990 to 2019). The top 15 is dominated by Indian
Bollywood actors, confirming India as Netflix's biggest non-US market.
Japanese voice actors also appear strongly with Takahiro Sakurai (32)
and Yuki Kaji (29) who are primarily TV Show focused. Amitabh Bachchan
has the longest active span at 44 years (1975 to 2019), while Vincent
Tong is the most internationally versatile, working across 11 countries.
*/


-- ─────────────────────────────────────────────────────────────
-- BUSINESS PROBLEM 7
-- How has India's share of global Netflix releases changed
-- year over year?
-- ─────────────────────────────────────────────────────────────

WITH india AS (
    SELECT
        release_year,
        COUNT(*)                                                       AS india_titles
    FROM netflix
    WHERE country LIKE '%India%'
      AND release_year BETWEEN 2012 AND 2021
    GROUP BY release_year
),
global_yearly AS (
    SELECT
        release_year,
        COUNT(*)                                                       AS global_titles
    FROM netflix
    WHERE release_year BETWEEN 2012 AND 2021
    GROUP BY release_year
)
SELECT
    i.release_year,
    i.india_titles,
    g.global_titles,
    ROUND(i.india_titles * 100.0 / g.global_titles, 2)               AS india_share_pct,
    LAG(ROUND(i.india_titles * 100.0 / g.global_titles, 2))
        OVER (ORDER BY i.release_year)                                AS prev_share_pct,
    ROUND(
        ROUND(i.india_titles * 100.0 / g.global_titles, 2)
        - LAG(ROUND(i.india_titles * 100.0 / g.global_titles, 2))
            OVER (ORDER BY i.release_year)
    , 2)                                                               AS share_change_pp,
    SUM(i.india_titles) OVER (ORDER BY i.release_year)               AS cumulative_india
FROM india i
JOIN global_yearly g USING (release_year)
ORDER BY i.release_year;

/*
INSIGHT
India's share actually peaked in 2013 at 20.14%, not 2017.
From 2013 onward the share declined steadily from 20.14% down to
5.91% in 2021, a drop of 14.23 percentage points over 8 years.
The 2017 spike to 10.76% was a brief recovery after hitting a low
of 8.87% in 2016. Cumulatively, India contributed 722 titles between
2012 and 2021, but its global share has been shrinking as Netflix
expanded aggressively into other markets worldwide.
*/


-- ─────────────────────────────────────────────────────────────
-- BUSINESS PROBLEM 8
-- Which genres dominate Netflix and how do they differ
-- between Movies and TV Shows?
-- ─────────────────────────────────────────────────────────────

WITH RECURSIVE genre_split AS (
    SELECT
        show_id,
        type,
        TRIM(SUBSTRING_INDEX(listed_in, ',', 1))                     AS genre,
        IF(LOCATE(',', listed_in) > 0,
           SUBSTRING(listed_in, LOCATE(',', listed_in) + 1),
           NULL)                                                       AS remaining
    FROM netflix
    WHERE listed_in IS NOT NULL
    UNION ALL
    SELECT
        show_id, type,
        TRIM(SUBSTRING_INDEX(remaining, ',', 1)),
        IF(LOCATE(',', remaining) > 0,
           SUBSTRING(remaining, LOCATE(',', remaining) + 1),
           NULL)
    FROM genre_split
    WHERE remaining IS NOT NULL
)
SELECT
    RANK() OVER (ORDER BY COUNT(*) DESC)                              AS genre_rank,
    genre,
    COUNT(*)                                                          AS total_titles,
    SUM(CASE WHEN type = 'Movie'   THEN 1 ELSE 0 END)               AS movies,
    SUM(CASE WHEN type = 'TV Show' THEN 1 ELSE 0 END)               AS tv_shows,
    ROUND(SUM(CASE WHEN type = 'Movie' THEN 1 ELSE 0 END)
          * 100.0 / COUNT(*), 1)                                      AS movie_pct,
    CASE
        WHEN ROUND(SUM(CASE WHEN type='Movie' THEN 1 ELSE 0 END)*100.0/COUNT(*),1) >= 80
            THEN 'Movie-Heavy'
        WHEN ROUND(SUM(CASE WHEN type='Movie' THEN 1 ELSE 0 END)*100.0/COUNT(*),1) <= 20
            THEN 'TV-Heavy'
        ELSE 'Balanced'
    END                                                               AS genre_skew
FROM genre_split
WHERE genre <> ''
GROUP BY genre
ORDER BY total_titles DESC
LIMIT 15;

/*
INSIGHT
International Movies (2,752) and Dramas (2,427) are the two dominant
genres, both 100% Movie-Heavy. The top 15 genres split cleanly into
two camps: Movie-Heavy genres dominate by volume with 10 out of 15
slots, while TV-Heavy genres (International TV Shows, TV Dramas,
TV Comedies, Crime TV Shows, Kids TV, Docuseries) are exclusively
TV Show content with 0 movie overlap. This clean separation suggests
Netflix uses distinct genre labels for movies and TV shows rather than
sharing genre tags across content types.
*/

-- ─────────────────────────────────────────────────────────────
-- BUSINESS PROBLEM 9
-- What is the ideal movie length on Netflix, and how does
-- duration distribution vary by rating?
-- ─────────────────────────────────────────────────────────────

WITH movie_durations AS (
    SELECT
        title,
        rating,
        CAST(SUBSTRING_INDEX(duration, ' ', 1) AS UNSIGNED)          AS minutes,
        CASE
            WHEN CAST(SUBSTRING_INDEX(duration,' ',1) AS UNSIGNED) < 60
                THEN 'A. Short  (<1 hr)'
            WHEN CAST(SUBSTRING_INDEX(duration,' ',1) AS UNSIGNED) < 90
                THEN 'B. Standard (1–1.5 hr)'
            WHEN CAST(SUBSTRING_INDEX(duration,' ',1) AS UNSIGNED) < 120
                THEN 'C. Feature (1.5–2 hr)'
            WHEN CAST(SUBSTRING_INDEX(duration,' ',1) AS UNSIGNED) < 150
                THEN 'D. Long (2–2.5 hr)'
            ELSE 'E. Epic (2.5+ hr)'
        END                                                            AS duration_bucket
    FROM netflix
    WHERE type = 'Movie'
      AND duration LIKE '% min'
      AND rating IS NOT NULL AND rating <> ''
)
SELECT
    duration_bucket,
    COUNT(*)                                                           AS movie_count,
    ROUND(AVG(minutes))                                               AS avg_minutes,
    MIN(minutes)                                                       AS min_minutes,
    MAX(minutes)                                                       AS max_minutes,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM movie_durations), 1)
                                                                       AS pct_of_movies,
    SUM(CASE WHEN rating IN ('TV-MA','R','NC-17') THEN 1 ELSE 0 END) AS mature_count,
    SUM(CASE WHEN rating IN ('G','PG','TV-G','TV-Y') THEN 1 ELSE 0 END) AS family_count
FROM movie_durations
GROUP BY duration_bucket
ORDER BY duration_bucket;

/*
INSIGHT
Feature length (1.5 to 2 hr) is the sweet spot with 3,091 movies (50.5%).
Mature rated content (1,597 titles) dominates this bucket. Short films
under 1 hour are the smallest at 7.5% (457 titles). The longest runtime
is 312 minutes belonging to Black Mirror Bandersnatch.
*/


-- ─────────────────────────────────────────────────────────────
-- BUSINESS PROBLEM 10
-- Is there a "season cliff" on Netflix — where do most
-- TV Shows get cancelled?
-- ─────────────────────────────────────────────────────────────

WITH season_data AS (
    SELECT
        title,
        rating,
        release_year,
        CAST(SUBSTRING_INDEX(duration, ' ', 1) AS UNSIGNED)          AS seasons
    FROM netflix
    WHERE type    = 'TV Show'
      AND duration LIKE '% Season%'
),
season_dist AS (
    SELECT
        seasons,
        COUNT(*)                                                       AS show_count,
        ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM season_data), 1) AS pct
    FROM season_data
    GROUP BY seasons
)
SELECT
    seasons,
    show_count,
    pct,
    SUM(show_count) OVER (ORDER BY seasons ASC)                      AS cumulative_shows,
    SUM(show_count) OVER (ORDER BY seasons DESC)                     AS shows_reaching_n_seasons,
    ROUND(
        SUM(show_count) OVER (ORDER BY seasons DESC) * 100.0
        / SUM(show_count) OVER ()
    , 1)                                                               AS survival_rate_pct
FROM season_dist
ORDER BY seasons;

/*
INSIGHT
67% of TV Shows (1,793) end after Season 1, the season cliff.
Survival drops from 100% to 33% between S1 and S2.
Only 6.1% survive to Season 5, and just 1 title reached Season 17.
*/


-- ─────────────────────────────────────────────────────────────
-- BUSINESS PROBLEM 11
-- Which directors have the broadest international reach,
-- and who is the most productive per year?
-- ─────────────────────────────────────────────────────────────

WITH RECURSIVE dir_split AS (
    SELECT
        show_id,
        type,
        country,
        release_year,
        TRIM(SUBSTRING_INDEX(director, ',', 1))                      AS director,
        IF(LOCATE(',', director) > 0,
           SUBSTRING(director, LOCATE(',', director) + 1),
           NULL)                                                       AS remaining
    FROM netflix
    WHERE director IS NOT NULL AND director <> ''
    UNION ALL
    SELECT
        show_id, type, country, release_year,
        TRIM(SUBSTRING_INDEX(remaining, ',', 1)),
        IF(LOCATE(',', remaining) > 0,
           SUBSTRING(remaining, LOCATE(',', remaining) + 1),
           NULL)
    FROM dir_split
    WHERE remaining IS NOT NULL
)
SELECT
    DENSE_RANK() OVER (ORDER BY COUNT(*) DESC)                       AS productivity_rank,
    director,
    COUNT(*)                                                          AS total_titles,
    SUM(CASE WHEN type = 'Movie'   THEN 1 ELSE 0 END)               AS movies,
    SUM(CASE WHEN type = 'TV Show' THEN 1 ELSE 0 END)               AS tv_shows,
    COUNT(DISTINCT country)                                           AS countries,
    MAX(release_year) - MIN(release_year)                            AS career_span_yrs,
    ROUND(COUNT(*) / NULLIF(MAX(release_year) - MIN(release_year), 0), 2)
                                                                      AS titles_per_year
FROM dir_split
WHERE director <> ''
GROUP BY director
HAVING COUNT(*) >= 3
ORDER BY total_titles DESC
LIMIT 15;

/*
INSIGHT
Rajiv Chilaka leads with 22 titles focused on children's content in India.
Jan Suter (21) and Raul Campos (19) have the highest titles per year above
9.0, suggesting rapid franchise production. Legends like Scorsese (0.23
titles per year) and Spielberg (0.27) show quality over volume careers.
*/


-- ─────────────────────────────────────────────────────────────
-- BUSINESS PROBLEM 12
-- Can we classify content tone from descriptions, and what
-- does the tone distribution tell us about Netflix strategy?
-- ─────────────────────────────────────────────────────────────

WITH tone_classified AS (
    SELECT
        show_id,
        title,
        type,
        release_year,
        rating,
        CASE
            WHEN description LIKE '%kill%'
              OR description LIKE '%murder%'
              OR description LIKE '%crime%'
              OR description LIKE '%war%'
              OR description LIKE '%dead%'    THEN 'Dark / Thriller'
            WHEN description LIKE '%love%'
              OR description LIKE '%romance%'
              OR description LIKE '%heart%'   THEN 'Romance / Drama'
            WHEN description LIKE '%comedy%'
              OR description LIKE '%funny%'
              OR description LIKE '%laugh%'   THEN 'Comedy'
            WHEN description LIKE '%inspire%'
              OR description LIKE '%overcome%'
              OR description LIKE '%dream%'   THEN 'Inspirational'
            WHEN description LIKE '%family%'
              OR description LIKE '%children%'
              OR description LIKE '%kid%'     THEN 'Family / Kids'
            ELSE 'Neutral / Other'
        END                                                            AS primary_tone
    FROM netflix
)
SELECT
    primary_tone,
    COUNT(*)                                                           AS title_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM netflix), 2)      AS share_pct,
    SUM(CASE WHEN type = 'Movie'   THEN 1 ELSE 0 END)                AS movies,
    SUM(CASE WHEN type = 'TV Show' THEN 1 ELSE 0 END)                AS tv_shows,
    ROUND(AVG(release_year), 0)                                       AS avg_release_year,
    MAX(release_year)                                                  AS most_recent
FROM tone_classified
GROUP BY primary_tone
ORDER BY title_count DESC;

/*
INSIGHT
Neutral / Other dominates at 62.05% (5,465 titles) as most descriptions
are plot focused. Dark / Thriller leads tagged content at 15.09% (1,329
titles). Dark content averages release year 2013 vs 2015 for other tones,
showing it has been a Netflix strategy for longer.
*/


-- ─────────────────────────────────────────────────────────────
-- EXECUTIVE SUMMARY
-- ─────────────────────────────────────────────────────────────

SELECT
    COUNT(*)                                                           AS total_titles,
    SUM(CASE WHEN type = 'Movie'   THEN 1 ELSE 0 END)                AS total_movies,
    SUM(CASE WHEN type = 'TV Show' THEN 1 ELSE 0 END)                AS total_tv_shows,
    ROUND(AVG(release_year), 1)                                       AS avg_release_year,
    SUM(CASE WHEN release_year >= 2018 THEN 1 ELSE 0 END)            AS titles_since_2018,
    SUM(CASE WHEN director IS NULL OR director = '' THEN 1 ELSE 0 END) AS missing_director,
    SUM(CASE WHEN casts    IS NULL OR casts    = '' THEN 1 ELSE 0 END) AS missing_cast,
    SUM(CASE WHEN country  IS NULL OR country  = '' THEN 1 ELSE 0 END) AS missing_country,
    (SELECT type   FROM netflix GROUP BY type   ORDER BY COUNT(*) DESC LIMIT 1) AS dominant_type,
    (SELECT rating FROM netflix WHERE rating <> '' GROUP BY rating ORDER BY COUNT(*) DESC LIMIT 1) AS top_rating
FROM netflix;

-- ============================================================
-- END OF ANALYSIS
-- ============================================================