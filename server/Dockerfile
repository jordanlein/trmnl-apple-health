FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    TRMNL_HEALTH_DATA_DIR=/data

WORKDIR /app

COPY server/requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt

COPY server /app/server

VOLUME ["/data"]
EXPOSE 8421

CMD ["uvicorn", "server.app.main:app", "--host", "0.0.0.0", "--port", "8421"]
