FROM jenkins/inbound-agent:4.11.2-4

USER root
RUN apt-get update && apt-get install python3 python3-pip -y
USER jenkins
ENV PATH="/home/jenkins/.local/bin:${PATH}"
RUN python3 -m pip install --upgrade pip && \
    python3 -m pip install --user ansible requests google-auth
COPY requirements.yml requirements.yml
RUN ansible-galaxy install -r requirements.yml

ENTRYPOINT ["/usr/local/bin/jenkins-agent"]
