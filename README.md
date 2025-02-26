# Netflix-Data-Exploration-SQL
SQL analysis of the Netflix dataset

# Running instructions

Create the database using:
```
.\setup.ps1
```

Run analysis on Windows:
```
Get-Content analysis.sql | sqlite3 netflix.db
```
