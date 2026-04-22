# SPDX-FileCopyrightText: GoCortexIO
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Intentionally vulnerable Dockerfile for comprehensive policy coverage
# Tri-server architecture: Python/Gunicorn (port 8888) + Java/Tomcat (port 9999) + React/Next.js (port 7777)
# Using Python 3.11 for PyGremlinBox compatibility + bookworm for OpenJDK 17
FROM python:3.11-bookworm

# Docker policy violations for comprehensive testing

# Running as root user (security risk)
USER root

# Installing packages without version pinning including OpenJDK 17 for Spring4Shell
# Create man directories required by OpenJDK packages on slim images
RUN apt-get update && \
    mkdir -p /usr/share/man/man1 && \
    apt-get install -y \
    curl \
    wget \
    git \
    vim \
    sudo \
    ssh \
    telnet \
    netcat-openbsd \
    iputils-ping \
    openjdk-17-jdk \
    maven \
    ant \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 20 LTS for SpaceATM Terminal (React/Next.js)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# Setting weak file permissions
RUN chmod 777 /tmp
RUN chmod 755 /etc/passwd

# Installing Apache Tomcat 8.5.0 (highly vulnerable legacy version)
# CVE-2020-1938 (Ghostcat), CVE-2020-9484 (RCE), CVE-2021-25122, CVE-2023-42795, CVE-2023-45648
RUN cd /opt && \
    wget https://archive.apache.org/dist/tomcat/tomcat-8/v8.5.0/bin/apache-tomcat-8.5.0.tar.gz && \
    tar xzvf apache-tomcat-8.5.0.tar.gz && \
    mv apache-tomcat-8.5.0 tomcat && \
    rm apache-tomcat-8.5.0.tar.gz && \
    chmod +x /opt/tomcat/bin/*.sh

# Configure Tomcat with intentionally weak settings
COPY config/tomcat-users.xml /opt/tomcat/conf/tomcat-users.xml
COPY config/context.xml /opt/tomcat/conf/context.xml
COPY config/manager-context.xml /opt/tomcat/webapps/manager/META-INF/context.xml
COPY config/manager-context.xml /opt/tomcat/webapps/host-manager/META-INF/context.xml
RUN chmod 644 /opt/tomcat/conf/tomcat-users.xml && \
    chmod 644 /opt/tomcat/conf/context.xml && \
    chmod 644 /opt/tomcat/webapps/manager/META-INF/context.xml && \
    chmod 644 /opt/tomcat/webapps/host-manager/META-INF/context.xml

# Exposing application ports (8888 for Flask/Gunicorn, 8080 for Tomcat - mapped to 9999 externally)
EXPOSE 8888 8080 7777

# Adding secrets directly in Dockerfile (bad practice)
ENV SECRET_KEY="hardcoded-secret-12345"
ENV DATABASE_PASSWORD="admin123"
ENV API_TOKEN="sk-1234567890abcdef"
ENV SESSION_SECRET="hardcoded-docker-secret-key"
ENV AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
ENV AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
ENV OPENAI_API_KEY="sk-1234567890abcdefghijklmnopqrstuvwxyz"
ENV DATABASE_URL="sqlite:////app/instance/database.db"

# Running commands that could be cached with secrets
RUN echo "admin:password123" > /tmp/credentials.txt
RUN chmod 644 /tmp/credentials.txt

# Setting working directory
WORKDIR /app

# Copying application code first
COPY . .

# Build SpaceATM Terminal (React/Next.js on port 7777)
WORKDIR /app/react-app
RUN npm install && \
    node scripts/patch-react-server-dom.js && \
    node scripts/patch-csrf-origin-check.js && \
    npm run build

# Installing Python packages with vulnerable/older versions for security testing
RUN pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir \
    flask==2.0.1 \
    flask-sqlalchemy==2.5.1 \
    requests==2.25.1 \
    pyjwt==1.7.1 \
    cryptography==39.0.0 \
    pyyaml==6.0 \
    gunicorn==20.1.0 \
    werkzeug==2.0.1 \
    ldap3==2.8.1 \
    pymongo==3.12.0 \
    urllib3==1.26.5 \
    flask-login==0.5.0 \
    email-validator==1.1.3 \
    jinja2==3.0.1 \
    pillow==8.1.0 \
    sqlalchemy==1.4.23 \
    faker==18.13.0

RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/* && \
    git clone --branch v1.4.6 --depth 1 https://github.com/gocortexio/gremlinbox.git /tmp/gremlinbox && \
    for d in /tmp/gremlinbox/PyGremlinBox-*; do \
      pip install --no-cache-dir "$d"; \
    done && \
    rm -rf /tmp/gremlinbox

# Copying sensitive files after installation
COPY vulnerable_data/ /app/secrets/

# Create instance directory for database with proper permissions
RUN mkdir -p /app/instance && \
    chmod 777 /app/instance && \
    touch /app/instance/database.db && \
    chmod 666 /app/instance/database.db

# Environment variables for Tomcat
ENV CATALINA_HOME=/opt/tomcat
ENV PATH=$PATH:$CATALINA_HOME/bin

# Build Java exploit application WAR file and set JAVA_HOME dynamically
COPY exploit-app /app/exploit-app
WORKDIR /app/exploit-app
RUN export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java)))) && \
    echo "$JAVA_HOME" > /tmp/java_home_path.txt && \
    echo "export JAVA_HOME=$JAVA_HOME" >> /etc/profile && \
    echo "JAVA_HOME=$JAVA_HOME" >> /etc/environment && \
    mvn clean package -DskipTests && \
    cp target/exploit-app.war $CATALINA_HOME/webapps/

# Build evil.jar payload for /dynamic endpoint testing
WORKDIR /app/vulnerable_data/payloads
RUN export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java)))) && \
    mvn clean package -DskipTests && \
    cp target/evil.jar /app/vulnerable_data/payloads/evil.jar && \
    chmod 644 /app/vulnerable_data/payloads/evil.jar

# Return to app directory
WORKDIR /app

# Create supervisor configuration for dual-server startup
RUN mkdir -p /var/log/supervisor
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Running both applications as root (Flask/Gunicorn on 8888, Tomcat on 8080)
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

# Health check with potential information disclosure (checks both servers)
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:8888/ && curl -f http://localhost:8080/ && curl -f http://localhost:7777/ || exit 1