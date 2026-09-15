import csv
import sqlite3

CSV_PATH = "users.csv"
DB_PATH = "users.db"


def create_table(conn):
    conn.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            email TEXT UNIQUE NOT NULL
        )
    """)
    conn.commit()


def load_csv(path):
    with open(path, newline="") as f:
        reader = csv.DictReader(f)
        return [(row["name"], row["email"]) for row in reader]


def insert_users(conn, users):
    conn.executemany(
        "INSERT OR IGNORE INTO users (name, email) VALUES (?, ?)",
        users
    )
    conn.commit()


def display_users(conn):
    rows = conn.execute("SELECT id, name, email FROM users ORDER BY id").fetchall()
    print(f"{'ID':<4}{'Name':<25}{'Email':<35}")
    print("-" * 64)
    for row in rows:
        id_, name, email = row
        print(f"{id_:<4}{name:<25}{email:<35}")


def main():
    conn = sqlite3.connect(DB_PATH)
    create_table(conn)
    users = load_csv(CSV_PATH)
    insert_users(conn, users)
    display_users(conn)
    conn.close()


if __name__ == "__main__":
    main()
