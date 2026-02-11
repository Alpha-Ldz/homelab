FROM python:3.11-slim

WORKDIR /app

# Install dependencies
RUN pip install --no-cache-dir fastapi uvicorn httpx pydantic

# Copy application
COPY app.py /app/

# Expose port
EXPOSE 8080

# Run application
CMD ["python", "app.py"]
