FROM python:alpine 

WORKDIR /workload
COPY app.py .
RUN pip3 install flask
RUN apk add curl 
EXPOSE 8081

CMD ["python3", "app.py"]