import hashlib
import json
import os
import time
import uuid
from datetime import datetime, timezone

from flask import Flask, Response, g, jsonify, request

from prometheus_client import Counter, Gauge, Histogram, REGISTRY
from prometheus_client.openmetrics.exposition import (
    CONTENT_TYPE_LATEST as OPENMETRICS_CONTENT_TYPE,
    generate_latest as generate_openmetrics,
)

from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.trace import Status, StatusCode

SERVICE_NAME = os.getenv("OTEL_SERVICE_NAME", "sre-demo")
OTLP_ENDPOINT = os.getenv(
    "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT",
    "http://otel-collector.otel.svc.cluster.local:4318/v1/traces",
)

resource = Resource.create({
    "service.name": SERVICE_NAME,
    "deployment.environment.name": os.getenv("DEPLOYMENT_ENVIRONMENT", "lab"),
    "k8s.namespace.name": os.getenv("K8S_NAMESPACE", "sre-lab"),
})

provider = TracerProvider(resource=resource)
provider.add_span_processor(
    BatchSpanProcessor(
        OTLPSpanExporter(endpoint=OTLP_ENDPOINT)
    )
)
trace.set_tracer_provider(provider)
tracer = trace.get_tracer("sre-demo")

app = Flask(__name__)

FlaskInstrumentor().instrument_app(
    app,
    tracer_provider=provider,
    excluded_urls="healthz,metrics",
)

REQUESTS = Counter(
    "sre_demo_http_requests_total",
    "Total HTTP requests",
    ["method", "route", "status"],
)

LATENCY = Histogram(
    "sre_demo_http_request_duration_seconds",
    "HTTP request duration in seconds",
    ["method", "route"],
    buckets=(0.05, 0.1, 0.25, 0.5, 1, 2, 3, 5, 7.5, 10, 15, 20, 30),
)

IN_PROGRESS = Gauge(
    "sre_demo_http_requests_in_progress",
    "HTTP requests currently in progress",
)

EXCLUDED_PATHS = {"/metrics", "/healthz"}


def normalized_route():
    return request.url_rule.rule if request.url_rule is not None else "unmatched"


def emit(payload):
    print(json.dumps(payload, separators=(",", ":")), flush=True)


def current_trace_fields():
    ctx = trace.get_current_span().get_span_context()
    if not ctx.is_valid:
        return {}
    return {
        "trace_id": format(ctx.trace_id, "032x"),
        "span_id": format(ctx.span_id, "016x"),
    }


@app.before_request
def before():
    g.request_id = request.headers.get("X-Request-ID") or str(uuid.uuid4())
    g.started_at = time.perf_counter()
    g.exception_type = None

    if request.path not in EXCLUDED_PATHS:
        IN_PROGRESS.inc()


@app.after_request
def after(response):
    if request.path not in EXCLUDED_PATHS:
        duration = max(time.perf_counter() - g.started_at, 0)
        route = normalized_route()

        trace_fields = current_trace_fields()
        trace_id = trace_fields.get("trace_id")

        REQUESTS.labels(
            request.method,
            route,
            str(response.status_code),
        ).inc()

        latency_metric = LATENCY.labels(
            request.method,
            route,
        )

        # Exemplar: links this exact histogram observation to its trace.
        if trace_id:
            latency_metric.observe(
                duration,
                exemplar={"trace_id": trace_id},
            )
        else:
            latency_metric.observe(duration)

        IN_PROGRESS.dec()

        level = (
            "ERROR" if response.status_code >= 500
            else "WARNING" if response.status_code >= 400
            else "INFO"
        )

        event = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": level,
            "event": "http_request",
            "service": SERVICE_NAME,
            "pod": os.getenv("HOSTNAME", "unknown"),
            "request_id": g.request_id,
            "method": request.method,
            "route": route,
            "status": response.status_code,
            "duration_ms": round(duration * 1000, 2),
        }
        event.update(trace_fields)

        if g.exception_type:
            event["exception_type"] = g.exception_type

        emit(event)

    response.headers["X-Request-ID"] = getattr(g, "request_id", "")
    return response


@app.errorhandler(Exception)
def handle_exception(exc):
    g.exception_type = type(exc).__name__

    span = trace.get_current_span()
    if span.is_recording():
        span.record_exception(exc)
        span.set_status(Status(StatusCode.ERROR, str(exc)))

    return jsonify(
        status="error",
        error="internal_server_error",
        request_id=getattr(g, "request_id", None),
    ), 500


@app.get("/")
def index():
    return jsonify(status="ok", service=SERVICE_NAME)


@app.get("/healthz")
def healthz():
    return jsonify(status="healthy")


@app.get("/error")
def error():
    return jsonify(status="error", message="simulated HTTP 500"), 500


@app.get("/exception")
def exception():
    raise RuntimeError("simulated application exception")


@app.get("/slow")
def slow():
    with tracer.start_as_current_span("simulated.wait"):
        time.sleep(1)
    return jsonify(status="ok", workload="slow")


@app.get("/cpu")
def cpu():
    with tracer.start_as_current_span("simulated.cpu_work"):
        data = b"sre-cpu-test"
        for _ in range(500000):
            data = hashlib.sha256(data).digest()
    return jsonify(status="ok", workload="cpu")


@app.get("/metrics")
def metrics():
    # Exemplars are exposed only in OpenMetrics format.
    return Response(
        generate_openmetrics(REGISTRY),
        content_type=OPENMETRICS_CONTENT_TYPE,
    )
