FROM python:latest

EXPOSE 8000

RUN apt update
RUN apt -y install git
RUN sleep 3
RUN apt -y install python3-pip
RUN sleep 3
RUN git clone https://github.com/KingmanT/Flask_Application-Containerized_Deployment.git
RUN sleep 2

WORKDIR Flask_Application-Containerized_Deployment

RUN pip install -r requirements.txt
RUN pip install gunicorn

ENTRYPOINT [ "python3", "-m", "gunicorn", "-w", "4", "application:app", "-b", "0.0.0.0" ]