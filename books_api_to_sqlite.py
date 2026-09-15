import requests
import sqlite3

API_URL = "https://openlibrary.org/search.json"
DB_PATH = "books.db"


def fetch_books(query="python programming", limit=20):
    params = {"q": query, "limit": limit}
    response = requests.get(API_URL, params=params, timeout=10)
    response.raise_for_status()
    docs = response.json().get("docs", [])
    books = []
    for doc in docs:
        title = doc.get("title", "Unknown")
        authors = doc.get("author_name", ["Unknown"])
        author = ", ".join(authors)
        year = doc.get("first_publish_year")
        books.append((title, author, year))
    return books


def create_table(conn):
    conn.execute("""
        CREATE TABLE IF NOT EXISTS books (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            author TEXT,
            publication_year INTEGER,
            UNIQUE(title, author, publication_year)
        )
    """)
    conn.commit()


def insert_books(conn, books):
    conn.executemany(
        "INSERT OR IGNORE INTO books (title, author, publication_year) VALUES (?, ?, ?)",
        books
    )
    conn.commit()


def display_books(conn):
    rows = conn.execute("SELECT id, title, author, publication_year FROM books ORDER BY id").fetchall()
    print(f"{'ID':<4}{'Title':<50}{'Author':<30}{'Year':<6}")
    print("-" * 90)
    for row in rows:
        id_, title, author, year = row
        print(f"{id_:<4}{title[:48]:<50}{(author or '')[:28]:<30}{year or '':<6}")


def main():
    conn = sqlite3.connect(DB_PATH)
    create_table(conn)
    books = fetch_books()
    insert_books(conn, books)
    display_books(conn)
    conn.close()


if __name__ == "__main__":
    main()