from flask import (
    Flask,
    request,
    render_template,
    make_response,
)

app = Flask("example")

f = open("/flag")
gflag = f.read()
f.close()


@app.route("/", methods=["GET"])
def index():
    response = make_response(render_template("index.html"))
    return response


@app.route("/test", methods=["POST"])
def testpost():
    namev = request.form["name"]
    return "Hi %s: Your flag is %s" % (namev, gflag)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080, debug=True, threaded=True)
