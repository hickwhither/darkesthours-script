from flask import Flask, send_from_directory, jsonify, request, send_file, Response

app = Flask(__name__)

@app.route('/src/<path:filepath>')
def src_file(filepath):
    return send_from_directory('src', filepath)

@app.route('/')
def index():
    with open("./src/main.lua", "r") as f:
        c = f.read().strip()
    c = c.replace("https://raw.githubusercontent.com/hickwhither/my-new-pc/refs/heads/master/src/", 'http://127.0.0.1:5000/src/')
    return c

app.run('0.0.0.0', 5000)