-- Check table structure
PRAGMA table_info(netflix);

-- -------------------------------------------------------------------------
-- DATA QUALITY CHECKS
-- -------------------------------------------------------------------------

-- Check for NULL values in all columns
-- This query counts NULL values for each column to identify data quality issues
SELECT 
    COUNT(*) FILTER (WHERE show_id IS NULL) AS showid_nulls,
    COUNT(*) FILTER (WHERE type IS NULL) AS type_nulls,
    COUNT(*) FILTER (WHERE title IS NULL) AS title_nulls,
    COUNT(*) FILTER (WHERE director IS NULL) AS director_nulls,
    COUNT(*) FILTER (WHERE movie_cast IS NULL) AS cast_nulls,
    COUNT(*) FILTER (WHERE country IS NULL) AS country_nulls,
    COUNT(*) FILTER (WHERE date_added IS NULL) AS date_added_nulls,
    COUNT(*) FILTER (WHERE release_year IS NULL) AS release_year_nulls,
    COUNT(*) FILTER (WHERE rating IS NULL) AS rating_nulls,
    COUNT(*) FILTER (WHERE duration IS NULL) AS duration_nulls,
    COUNT(*) FILTER (WHERE listed_in IS NULL) AS listed_in_nulls,
    COUNT(*) FILTER (WHERE description IS NULL) AS description_nulls
FROM netflix;

-- Check for duplicate show_id values
-- A well-structured dataset should have unique identifiers
SELECT 
    show_id, 
    COUNT(*) AS duplicate_count
FROM netflix
GROUP BY show_id
HAVING COUNT(*) > 1;

-- -------------------------------------------------------------------------
-- BASIC EXPLORATION
-- -------------------------------------------------------------------------

-- Calculate total number of titles in the dataset
SELECT COUNT(*) AS total_shows FROM netflix;

-- Preview specific columns
SELECT type, title FROM netflix LIMIT 2;

-- Find the oldest release years in the dataset
SELECT DISTINCT release_year 
FROM netflix 
ORDER BY release_year ASC 
LIMIT 2;

-- Find Polish movies
SELECT title 
FROM netflix 
WHERE country LIKE '%Poland%' AND type = 'Movie' 
LIMIT 5;

-- -------------------------------------------------------------------------
-- GENRE ANALYSIS
-- -------------------------------------------------------------------------

-- Count titles by type (Movie/TV Show) that belong to comedy or drama genres
SELECT 
    type, 
    COUNT(*) AS count
FROM netflix 
WHERE 
    listed_in LIKE '%Comedies, Dramas%'
    OR listed_in LIKE '%Dramas, Comedies%'
    OR listed_in LIKE '%Dramas%' 
    OR listed_in LIKE '%Comedies%'
GROUP BY type;

-- -------------------------------------------------------------------------
-- TEMPORAL ANALYSIS
-- -------------------------------------------------------------------------

-- Count titles by release year (showing the most recent years)
SELECT 
    release_year, 
    COUNT(*) AS title_counter
FROM netflix
GROUP BY release_year
ORDER BY release_year DESC
LIMIT 3;

-- Calculate statistics about release years by content type
SELECT 
    type,
    AVG(release_year) AS avg_year, 
    MIN(release_year) AS earliest_year,
    MAX(release_year) AS latest_year
FROM netflix
GROUP BY type;

-- Analyze release patterns by month and content type
SELECT 
    type,
    SUBSTR(date_added, 1, INSTR(date_added, ' ') - 1) AS month,
    COUNT(*) AS count
FROM netflix
WHERE 
    date_added IS NOT NULL
    AND SUBSTR(date_added, 1, INSTR(date_added, ' ') - 1) IN (
        'January', 'February', 'March', 'April', 'May', 'June', 
        'July', 'August', 'September', 'October', 'November', 'December'
    )
GROUP BY month, type
ORDER BY type, CASE
    WHEN month = 'January' THEN 1
    WHEN month = 'February' THEN 2
    WHEN month = 'March' THEN 3
    WHEN month = 'April' THEN 4
    WHEN month = 'May' THEN 5
    WHEN month = 'June' THEN 6
    WHEN month = 'July' THEN 7
    WHEN month = 'August' THEN 8
    WHEN month = 'September' THEN 9
    WHEN month = 'October' THEN 10
    WHEN month = 'November' THEN 11
    WHEN month = 'December' THEN 12
END;

-- Analyze content additions by year and type
SELECT 
    type, 
    SUBSTR(date_added, INSTR(date_added, ', ') + 2, LENGTH(date_added)) AS year, 
    COUNT(*) AS count
FROM netflix
WHERE date_added IS NOT NULL
GROUP BY year, type
ORDER BY year DESC
LIMIT 10;

-- -------------------------------------------------------------------------
-- RELATIONSHIP ANALYSIS USING SELF-JOINS
-- -------------------------------------------------------------------------

-- Find pairs of titles that share the same director
SELECT 
    a.title AS title1, 
    b.title AS title2, 
    a.director
FROM netflix a
JOIN netflix b ON a.director = b.director AND a.show_id < b.show_id
WHERE a.director IS NOT NULL AND a.director != ''
ORDER BY a.director, a.title
LIMIT 1;

-- Find directors who worked on both movies and TV shows
SELECT 
    a.title AS title1, 
    a.type AS type1, 
    b.title AS title2, 
    b.type AS type2, 
    a.director
FROM netflix a 
JOIN netflix b ON a.director = b.director AND a.show_id < b.show_id AND a.type != b.type
WHERE a.director IS NOT NULL AND a.director != ''
ORDER BY a.director, a.title
LIMIT 1;

-- Count how many directors worked on both movies and TV shows
SELECT COUNT(*)
FROM netflix a 
JOIN netflix b ON a.director = b.director AND a.show_id < b.show_id AND a.type != b.type
WHERE a.director IS NOT NULL AND a.director != '';

-- -------------------------------------------------------------------------
-- ADVANCED DATA TRANSFORMATION USING JSON FUNCTIONS
-- -------------------------------------------------------------------------

-- Count the total number of genre relationships
-- (This splits the comma-separated genre list into individual entries)
SELECT COUNT(*)
FROM netflix n
JOIN (
    SELECT 
        show_id, 
        TRIM(value) AS genre
    FROM netflix,
    json_each('["' || REPLACE(listed_in, ', ', '", "') || '"]')
) g ON n.show_id = g.show_id
LIMIT 5;

-- Count the total number of country relationships
-- (This splits the comma-separated country list into individual entries)
SELECT COUNT(*)
FROM netflix n
JOIN (
    SELECT 
        show_id, 
        TRIM(value) AS country
    FROM netflix,
    json_each('["' || REPLACE(country, ', ', '", "') || '"]')
) g ON n.show_id = g.show_id
LIMIT 5;

-- -------------------------------------------------------------------------
-- DATA NORMALIZATION AND RELATIONSHIP MODELING
-- -------------------------------------------------------------------------

-- Create a temporary table of countries with title counts
CREATE TABLE proto_countries AS
SELECT 
    TRIM(value) AS country_name, 
    COUNT(*) AS title_counter
FROM netflix, 
     json_each('["' || REPLACE(country, ', ', '", "') || '"]')
WHERE country IS NOT NULL AND country != ''
GROUP BY TRIM(value);

-- Create a formal countries table with auto-incrementing primary key
CREATE TABLE countries (
    country_id INTEGER PRIMARY KEY AUTOINCREMENT, 
    country_name TEXT, 
    title_counter INT
);

-- Populate the countries table from the temporary table
INSERT INTO countries (country_name, title_counter)
SELECT country_name, title_counter FROM proto_countries;

-- Clean up the temporary table
DROP TABLE proto_countries;

-- Create a junction table to model the many-to-many relationship
-- between titles and countries
CREATE TABLE title_countries AS
SELECT 
    nt.show_id,
    c.country_id
FROM netflix nt,
     json_each('["' || REPLACE(nt.country, ', ', '", "') || '"]') AS country_values
JOIN countries c ON TRIM(country_values.value) = c.country_name
WHERE nt.country IS NOT NULL AND nt.country != '';

-- -------------------------------------------------------------------------
-- ANALYTICAL QUERIES USING THE NORMALIZED DATA MODEL
-- -------------------------------------------------------------------------

-- Find the most common content ratings by country
-- Only includes countries with at least 10 titles
SELECT
    c.country_name,
    n.rating,
    COUNT(*) AS rating_count,
    ROUND(COUNT(*) * 100.0 / c.title_counter, 2) AS percent_rating_count
FROM netflix n 
JOIN title_countries tc ON n.show_id = tc.show_id
JOIN countries c ON tc.country_id = c.country_id
WHERE n.rating IS NOT NULL AND n.rating != ''
GROUP BY c.country_name, n.rating
HAVING c.title_counter >= 10
ORDER BY percent_rating_count DESC
LIMIT 10;

-- Find countries that specialize in certain genres
-- Shows genre specialization for countries with at least 20 titles
-- Excludes the generic "International Movies" category
SELECT 
    c.country_name,
    TRIM(genre_values.value) AS genre,
    COUNT(*) AS genre_count,
    ROUND(COUNT(*) * 100.0 / c.title_counter, 2) AS genre_percentage
FROM netflix nt
JOIN title_countries tc ON nt.show_id = tc.show_id
JOIN countries c ON tc.country_id = c.country_id,
     json_each('["' || REPLACE(nt.listed_in, ', ', '", "') || '"]') AS genre_values
WHERE 
    c.title_counter >= 20  -- Only include countries with many titles
    AND TRIM(genre_values.value) != 'International Movies'
GROUP BY c.country_name, TRIM(genre_values.value)
HAVING genre_percentage >= 30  -- Only show genres that make up a significant portion
ORDER BY genre_percentage DESC
LIMIT 5;

-- Compare average, minimum and maximum release years by country
-- Shows which countries have newer content in the catalog
SELECT 
    c.country_name,
    c.title_counter,
    ROUND(AVG(n.release_year), 2) AS average_release_year,
    MIN(n.release_year) AS min_release_year,
    MAX(n.release_year) AS max_release_year
FROM netflix n
JOIN title_countries tc ON n.show_id = tc.show_id
JOIN countries c ON tc.country_id = c.country_id
WHERE c.title_counter > 5  -- Only include countries with enough titles for meaningful averages
GROUP BY country_name 
ORDER BY average_release_year DESC
LIMIT 5;