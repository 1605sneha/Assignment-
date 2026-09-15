import requests
import matplotlib.pyplot as plt

API_URL = "http://127.0.0.1:5050/scores"


def fetch_scores():
    response = requests.get(API_URL, timeout=10)
    response.raise_for_status()
    return response.json()


def compute_average(scores):
    values = [s["score"] for s in scores]
    return sum(values) / len(values) if values else 0


def plot_scores(scores, average, output_path="scores_bar_chart.png"):
    names = [s["name"] for s in scores]
    values = [s["score"] for s in scores]
    plt.figure(figsize=(10, 6))
    plt.bar(names, values, color="steelblue")
    plt.axhline(average, color="red", linestyle="--", label=f"Average: {average:.2f}")
    plt.xlabel("Student")
    plt.ylabel("Score")
    plt.title("Student Test Scores")
    plt.legend()
    plt.tight_layout()
    plt.savefig(output_path)


def main():
    scores = fetch_scores()
    average = compute_average(scores)
    plot_scores(scores, average)
    print(f"Average score: {average:.2f}")
    print("Bar chart saved to scores_bar_chart.png")


if __name__ == "__main__":
    main()
