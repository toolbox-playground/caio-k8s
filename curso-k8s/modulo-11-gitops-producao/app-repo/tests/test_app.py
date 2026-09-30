import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "app"))
os.environ.setdefault("APP_VERSION", "test")

from fastapi.testclient import TestClient  # noqa: E402

from main import app  # noqa: E402

client = TestClient(app)


def test_health_endpoints():
    assert client.get("/healthz").status_code == 200
    assert client.get("/readyz").status_code == 200


def test_version_reports_build():
    body = client.get("/version").json()
    assert body["version"] == "test"


def test_secret_never_leaks_value(monkeypatch):
    monkeypatch.setenv("API_KEY", "super-secret-value")
    body = client.get("/secret").json()
    assert body["api_key_loaded"] is True
    assert "super-secret-value" not in str(body)
    assert len(body["fingerprint"]) == 8


def test_metrics_exposed():
    client.get("/work?ms=1")
    text = client.get("/metrics").text
    assert "webapp_http_requests_total" in text
    assert 'route="/work"' in text


def test_otel_path_imports_cleanly():
    """Regressão: com OTEL_EXPORTER_OTLP_ENDPOINT o app importa as libs de tracing.

    Rodar em subprocesso evita registrar métricas Prometheus duas vezes.
    """
    import subprocess

    app_dir = os.path.join(os.path.dirname(__file__), "..", "app")
    env = {**os.environ, "OTEL_EXPORTER_OTLP_ENDPOINT": "http://127.0.0.1:4317"}
    result = subprocess.run(
        [sys.executable, "-c", "import main"], cwd=app_dir, env=env, capture_output=True, text=True
    )
    assert result.returncode == 0, result.stderr
