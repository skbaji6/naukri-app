# Use slim Python image
FROM python:3.11-slim

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget \
    gnupg \
    unzip \
    curl \
    cron \
    fonts-liberation \
    libatk-bridge2.0-0 \
    libgtk-3-0 \
    libxss1 \
    libasound2 \
    libnss3 \
    libx11-6 \
  && rm -rf /var/lib/apt/lists/*

# Add Google's signing key and repo (apt-key replacement)
RUN wget -qO- https://dl.google.com/linux/linux_signing_key.pub \
    | gpg --dearmor --yes -o /usr/share/keyrings/google-linux-signing-key.gpg \
  && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-linux-signing-key.gpg] http://dl.google.com/linux/chrome/deb/ stable main" \
     > /etc/apt/sources.list.d/google-chrome.list

# Install Chrome
RUN apt-get update && apt-get install -y google-chrome-stable \
  && rm -rf /var/lib/apt/lists/*

# Install matching ChromeDriver automatically
RUN set -eux; \
    CHROME_BIN="$(command -v google-chrome || true)"; \
    if [ -z "$CHROME_BIN" ]; then echo "Chrome not found"; exit 1; fi; \
    CHROME_VERSION="$($CHROME_BIN --version | grep -oP '\d+\.\d+\.\d+')" ; \
    CHROME_MAJOR="$(echo $CHROME_VERSION | cut -d. -f1)" ; \
    echo "Detected Chrome version: $CHROME_VERSION (major $CHROME_MAJOR)"; \
    DRIVER_VERSION="$(curl -s "https://googlechromelabs.github.io/chrome-for-testing/LATEST_RELEASE_$CHROME_MAJOR")"; \
    echo "Installing ChromeDriver version: $DRIVER_VERSION"; \
    wget -q -O /tmp/chromedriver.zip "https://edgedl.me.gvt1.com/edgedl/chrome/chrome-for-testing/$DRIVER_VERSION/linux64/chromedriver-linux64.zip"; \
    unzip /tmp/chromedriver.zip -d /tmp/; \
    mv /tmp/chromedriver-linux64/chromedriver /usr/local/bin/chromedriver; \
    chmod +x /usr/local/bin/chromedriver; \
    rm -rf /tmp/*

# Set working dir and copy application
WORKDIR /app
COPY . /app

# Install Python deps (ensure you have requirements.txt in the project root)
RUN pip install --no-cache-dir -r requirements.txt

# Recommended envs from the script
ENV WDM_LOCAL=1 WDM_LOG_LEVEL=0 PYTHONUNBUFFERED=1

# If you want to run headless by default, set HEADLESS=true and modify script to read env,
# otherwise the script's "headless" variable controls that.
#CMD ["python", "src/naukri.py"]
# ---------------------------
# 🕒 Add cron to run every 1 hour
# ---------------------------

# Create log file and cron job
RUN touch /var/log/naukri_hourly.log && \
    (crontab -l 2>/dev/null; echo "0 * * * * cd /app && /usr/local/bin/python3 src/naukri.py >> /var/log/naukri_hourly.log 2>&1") | crontab -

# ---------------------------
# Start cron + tail logs in foreground
# ---------------------------