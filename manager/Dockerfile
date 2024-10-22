FROM ustclug/debian:12
RUN apt update && apt -y upgrade && \
    apt install -y xinetd python3-openssl docker.io python3-requests python3-requests-unixsocket python3-httpx && \
    rm -rf /var/lib/apt/lists/*
COPY main.py /
COPY cert.pem /
COPY db.py /
COPY redirect.html /
COPY socat /
RUN chmod +x /socat
COPY socat_static /
RUN chmod +x /socat_static
CMD ["python3", "main.py"]
