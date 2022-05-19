FROM jenkins/jenkins:lts-jdk11
USER root
ARG CERT_PATH=tls.crt
COPY ${CERT_PATH} /usr/local/share/ca-certificates/
RUN update-ca-certificates
RUN apt-get update && apt-get install curl
USER jenkins
COPY --chown=jenkins:jenkins plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli -f /usr/share/jenkins/ref/plugins.txt
