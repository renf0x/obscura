FROM python:3.12-slim-bookworm

# ffmpeg cuts clips, rclone copies them off-site, curl fetches the model and serves the healthcheck.
RUN apt-get update \
 && apt-get install -y --no-install-recommends ffmpeg curl ca-certificates unzip tzdata \
 && rm -rf /var/lib/apt/lists/*

# rclone from the official release (Debian's package is years behind), checksum-verified.
ARG RCLONE_VERSION=v1.75.1
RUN set -eux; arch="$(dpkg --print-architecture)"; \
    base="https://github.com/rclone/rclone/releases/download/${RCLONE_VERSION}"; \
    zip="rclone-${RCLONE_VERSION}-linux-${arch}.zip"; \
    curl -fsSLo "/tmp/${zip}" "${base}/${zip}"; \
    curl -fsSLo /tmp/SHA256SUMS "${base}/SHA256SUMS"; \
    (cd /tmp && grep " ${zip}\$" SHA256SUMS | sha256sum -c -); \
    unzip -j "/tmp/${zip}" "*/rclone" -d /usr/local/bin; chmod 755 /usr/local/bin/rclone; \
    rm "/tmp/${zip}" /tmp/SHA256SUMS

# YOLOX-nano person detector (Apache-2.0), pinned by hash.
ARG MODEL_URL=https://github.com/Megvii-BaseDetection/YOLOX/releases/download/0.1.1rc0/yolox_nano.onnx
ARG MODEL_SHA256=c789161ed43c8269fcd4e67c67eeeb4e80c622da2eb296a20bc6007bd18a0b7d
RUN mkdir -p /opt/obscura \
 && curl -fsSLo /opt/obscura/yolox_nano.onnx "$MODEL_URL" \
 && echo "$MODEL_SHA256  /opt/obscura/yolox_nano.onnx" | sha256sum -c -

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY obscura ./obscura

RUN useradd --uid 1000 --create-home obscura && mkdir -p /data && chown obscura /data
USER obscura
ENV OBSCURA_DATA=/data PYTHONUNBUFFERED=1
VOLUME /data
EXPOSE 7878
HEALTHCHECK --interval=30s --timeout=5s CMD curl -fsS "http://127.0.0.1:${OBSCURA_PORT:-7878}/api/health" || exit 1
CMD ["python", "-m", "obscura"]
