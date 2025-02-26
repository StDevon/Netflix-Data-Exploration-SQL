# setup.ps1 - Automates SQLite setup on Windows

(Get-Content data/netflix_titles.csv | Select-Object -Skip 1) | Set-Content data/netflix_titles_noheader.csv

# Define database file path
$DatabaseFile = "C:\Work\SQL projects\Netflix Movies and TV shows\netflix.db"

# Remove old database if it exists
if (Test-Path $DatabaseFile) {
    Remove-Item $DatabaseFile -Force
    Write-Output "Old database removed."
}

# Create new database and load SQL scripts
Get-Content scripts/create_db.sql | sqlite3 $DatabaseFile
# Get-Content scripts/import_data.sql | sqlite3 $DatabaseFile

Write-Output "Database setup complete! Run queries using: sqlite3 netflix.db"
