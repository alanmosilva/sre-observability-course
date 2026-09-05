import os
import time
from flask import Flask, Response, jsonify, request
from prometheus_client import Counter, Gauge, Histogram, generate_latest, CONTENT_TYPE_LATEST

app = Flask(__name__)

REQUESTS = Counter(
    "sre_demo_http_requests_total",
    "Total HTTP requests handled by the application",
    ["method", "route", "status"],
)

LATENCY = Histogram(
    "sre_demo_http_request_duration_seconds",
    "HTTP request duration in seconds",
    ["method", "route"],
    buckets=(0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0),
)

IN_PROGRESS = Gauge(
    "sre_demo_http_requests_in_progress",
    "HTTP requests currently being processed",
)

@app.before_request
def before_request():
    if request.path != "/metrics":
        request._sre_started = time.perf_counter()
        IN_PROGRESS.inc()

@app.after_request
def after_request(response):
    if request.path != "/metrics":
        route = request.url_rule.rule if request.url_rule else "unmatched"
        duration = time.perf_counter() - request._sre_started
        REQUESTS.labels(
            method=request.method,
            route=route,
            status=str(response.status_code),
        ).inc()
        LATENCY.labels(
            method=request.method,
            route=route,
        ).observe(duration)
        IN_PROGRESS.dec()
    return response

@app.get("/")
def index():
    return jsonify(service="sre-demo", status="ok", version="v1")

@app.get("/error")
def error():
    return jsonify(error="simulated failure"), 500

@app.get("/slow")
def slow():
    time.sleep(float(os.getenv("SLOW_SECONDS", "1")))
    return jsonify(service="sre-demo", slow=True)

@app.get("/metrics")
def metrics():
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
