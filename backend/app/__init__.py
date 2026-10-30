"""Wingman API — FastAPI backend for the 48h hackathon.

Run from the `backend/` directory:
    python -m uvicorn app.main:app --host 0.0.0.0 --port 8443 \
        --ssl-keyfile certs/server.key --ssl-certfile certs/server.crt

or simply:  .\\run.ps1   (TLS, port 8443)   /   .\\run_insecure.ps1 (HTTP, 8080)
"""

__version__ = "0.1.0"
