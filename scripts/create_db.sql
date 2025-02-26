DROP TABLE IF EXISTS netflix;

CREATE TABLE netflix (
    show_id TEXT PRIMARY KEY,
    type TEXT,
    title TEXT,
    director TEXT,
    movie_cast TEXT,
    country TEXT,
    date_added TEXT,
    release_year INTEGER,
    rating TEXT,
    duration TEXT,
    listed_in TEXT,
    description TEXT
);

.mode csv
.headers on
.import data/netflix_titles_noheader.csv netflix