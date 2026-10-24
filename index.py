"""Vercel entrypoint: exposes the FastAPI `app`. The static UI is copied to /public by deploy.bat and served by Vercel's CDN."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "backend"))

from app.main import app  # noqa: E402,F401
