# Keep the Python minor pinned while using a current Alpine base.
FROM python:3.11-alpine3.24

# Update package lists and upgrade all packages to patch vulnerabilities
RUN apk update && apk upgrade --no-cache

# Upgrade pip to latest version for security fixes
RUN pip install --upgrade pip

WORKDIR /app

# Copy requirements first for better Docker layer caching
COPY requirements.txt ./

# Install Python dependencies (no build tools needed for these packages)
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application code
COPY . .

# Install the application
RUN pip install --no-cache-dir -e .

# Set environment variables
ENV DOCKER=1
ENV OUTPUT_FORMAT="json"
ENV FETCH_INTERVAL="86400"
ENV FORCE_FETCH="false"

# Create data directory
RUN mkdir -p /data && chmod 755 /data

# Define a persistent volume for data storage
VOLUME ["/data"]

# Ensure clean line endings and permissions
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh && \
    sed -i 's/\r$//' /usr/local/bin/docker-entrypoint.sh


# Use the startup script as entrypoint
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
