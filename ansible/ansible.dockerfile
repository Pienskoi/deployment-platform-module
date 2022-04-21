FROM python:3
RUN pip install ansible
RUN pip install requests google-auth
COPY requirements.yml requirements.yml
RUN ansible-galaxy install -r requirements.yml
