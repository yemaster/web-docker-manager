FROM ustclug/debian:12
RUN apt update && apt -y upgrade && \
    apt install -y xinetd python3-openssl docker.io python3-requests python3-requests-unixsocket python3-httpx && \
    rm -rf /var/lib/apt/lists/*
COPY main.py /
COPY cert.pem /
COPY db.py /
COPY redirect.html /
COPY gocat /
RUN chmod +x /gocat
CMD ["python3", "main.py"]
