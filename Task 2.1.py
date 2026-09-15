from flask import Flask, jsonify
import random

app = Flask(__name__)

STUDENTS = ["Aarav", "Ishita", "Rohan", "Meera", "Kabir", "Ananya", "Vihaan", "Diya"]

SCORES = [{"name": name, "score": random.randint(40, 100)} for name in STUDENTS]


@app.route("/scores")
def scores():
    return jsonify(SCORES)


if __name__ == "__main__":
    app.run(port=5050)
