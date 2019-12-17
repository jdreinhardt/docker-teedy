# Comments...

ARG DOCKER_ARCHITECTURE

FROM ${DOCKER_ARCHITECTURE}/ubuntu:18.04 AS builder

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && apt-get install -y -q \
    apt-transport-https \
    ca-certificates \
    software-properties-common \
    git \
    wget \
    xz-utils \
    curl \
    gnupg \
    tzdata \
    maven \
    openjdk-11-jdk \
    less \
    procps \
    npm \
    grunt

# Configure settings
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8

# get files simics/ubuntu
RUN ln -fs /usr/share/zoneinfo/UTC /etc/localtime && \
    dpkg-reconfigure -f noninteractive tzdata

ARG CPU_ARCHITECTURE

ENV JAVA_HOME /usr/lib/jvm/java-11-openjdk-${CPU_ARCHITECTURE}/
ENV JAVA_OPTS -Duser.timezone=UTC -Dfile.encoding=UTF-8 -Xmx1024m

# Download and configure Jetty
ENV JETTY_VERSION 9.4.12.v20180830
RUN wget -nv -O /tmp/jetty.tar.gz \
    "https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-distribution/${JETTY_VERSION}/jetty-distribution-${JETTY_VERSION}.tar.gz" \
    && tar xzf /tmp/jetty.tar.gz -C /opt \
    && mv /opt/jetty* /opt/jetty \
    && useradd jetty -U -s /bin/false \
    && chown -R jetty:jetty /opt/jetty \
    && chmod +x /opt/jetty/bin/jetty.sh

# Init configuration and get files from sismics/ubuntu-java
RUN git clone https://github.com/sismics/docker-ubuntu-jetty.git && \
    cp -r docker-ubuntu-jetty/opt /opt && \
    rm -r docker-ubuntu-jetty

ENV JETTY_HOME /opt/jetty
ENV JAVA_OPTIONS -Xmx512m

# Remove the embedded javax.mail jar from Jetty and get files from sismics/docs then build
RUN rm -f /opt/jetty/lib/mail/javax.mail.glassfish-*.jar && \
    git clone https://github.com/sismics/docs.git /tmp/docs && \
    cp /tmp/docs/docs.xml /opt/jetty/webapps/docs.xml
WORKDIR /tmp/docs
RUN mvn -Pprod -DskipTests clean install && \
    cp docs-web/target/docs-web-*.war /opt/jetty/webapps/docs.war

# ffmpeg static builds to trim size
# https://www.johnvansickle.com/ffmpeg/
# Licensed under GPL v3
WORKDIR /tmp
ENV FFMPEG_VERSION 4.2.1
RUN wget https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-${CPU_ARCHITECTURE}-static.tar.xz
RUN tar -xJf ffmpeg-release-${CPU_ARCHITECTURE}-static.tar.xz
RUN cp "/tmp/ffmpeg-${FFMPEG_VERSION}-${CPU_ARCHITECTURE}-static/ffmpeg" /usr/local/bin

# Assemble the pieces for the final image
FROM ${DOCKER_ARCHITECTURE}/ubuntu:18.04

# Bring the Jetty folder over from the app builder
# and the static build of ffmpeg
COPY --from=builder /opt/jetty* /opt/jetty/
COPY --from=builder /usr/local/bin/ffmpeg /usr/local/bin/

# Install dependencies
RUN apt-get update && apt-get install -y -q \
    openjdk-8-jre-headless \
    unzip \
    mediainfo \
    tesseract-ocr \
    tesseract-ocr-fra \
    tesseract-ocr-ita \
    tesseract-ocr-kor \
    tesseract-ocr-rus \
    tesseract-ocr-ukr \
    tesseract-ocr-spa \
    tesseract-ocr-ara \
    tesseract-ocr-hin \
    tesseract-ocr-deu \
    tesseract-ocr-pol \
    tesseract-ocr-jpn \
    tesseract-ocr-por \
    tesseract-ocr-tha \
    tesseract-ocr-jpn \
    tesseract-ocr-chi-sim \
    tesseract-ocr-chi-tra \
    tesseract-ocr-nld \
    tesseract-ocr-tur \
    tesseract-ocr-heb && \
    apt-get clean && \
    apt-get autoremove -y -q && \
    rm -rf /var/lib/apt/lists/* && \
    useradd jetty -U -s /bin/false && \
    chown -R jetty:jetty /opt/jetty

ARG CPU_ARCHITECTURE

ENV MAX_HEAP_SIZE 512m
ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-${CPU_ARCHITECTURE}/
ENV JAVA_OPTIONS -Xmx${MAX_HEAP_SIZE}

WORKDIR /opt/jetty
VOLUME /data
EXPOSE 8080
CMD ["bin/jetty.sh", "run"]