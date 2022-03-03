FROM python:3.9-slim

# Add the ZScaler Root CA
WORKDIR /usr/local/share/ca-certificates
COPY zscaler.pem zscaler.crt
RUN update-ca-certificates && \
    pip config set global.cert ./cacert_kiewit.crt && \
    # Download the current Mozilla CA certificates
    python3 -c "from urllib.request import urlretrieve; urlretrieve('http://curl.se/ca/cacert.pem', 'cacert.pem')" && \
    # Combine the Mozilla certificates with the ZScaler certificate
    cat zscaler.crt >> cacert.pem && \
    # Clean up
    rm zscaler.crt && \
    mv cacert.pem cacert_kiewit.crt && \    
    # Update the OS and pip with the combine certificate
    update-ca-certificates && \
    pip config set global.cert ./cacert_kiewit.crt && \
    # Update pip.
    python -m pip install --upgrade pip

# Update and install packages.
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install --no-install-recommends -y freetds-bin git unixodbc unixodbc-dev poppler-utils tdsodbc && \
    apt-get install --reinstall -y build-essential && \
    # Clean up after installs.
    apt-get purge --auto-remove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install ODBC driver.
RUN apt-get update && \
    apt-get install --no-install-recommends -y curl && \
    curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
    curl https://packages.microsoft.com/config/debian/10/prod.list > /etc/apt/sources.list.d/mssql-release.list && \
    apt-get update && \
    ACCEPT_EULA=Y apt-get install -y mssql-tools && \
    ACCEPT_EULA=Y apt-get install -y msodbcsql17 && \
    # Add paths to drivers to config files.
    echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bash_profile && \
    echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc && \
    /bin/bash -c "source ~/.bashrc" && \
    # Clean up after installs.
    apt-get purge --auto-remove -y curl && \
    apt-get purge --auto-remove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create non-privileged user to run app.
RUN useradd --create-home appuser
USER appuser

# Set working directory.
WORKDIR /home/appuser

#Add the zscaler cert to pip
RUN pip config set global.cert /usr/local/share/ca-certificates/cacert_kiewit.crt

# Copy and install requirement file from repo.
COPY --chown=appuser requirements.txt requirements.txt
RUN pip install --no-cache-dir -r requirements.txt && \
    rm requirements.txt

# Copy repository to image.
COPY --chown=appuser . /home/appuser/

# Set Python path environment variable.
ENV PYTHONPATH "/home/appuser"

# Expose port.
EXPOSE 5000

# Run Flask app.
CMD python -m flask run --port 5000 --host 0.0.0.0
