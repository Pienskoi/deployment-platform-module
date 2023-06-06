FROM jenkins/jenkins:lts-jdk11
LABEL org.opencontainers.image.source=https://github.com/pienskoi/terraform-google-deployment-platform
USER root
RUN apt-get update && apt-get install curl
USER jenkins
COPY --chown=jenkins:jenkins plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli -f /usr/share/jenkins/ref/plugins.txt
