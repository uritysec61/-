from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/status')
def status():
    return jsonify({"status": "Success"}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8081)