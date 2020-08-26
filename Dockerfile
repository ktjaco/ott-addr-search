FROM postgis/postgis:12-master

COPY . /app

RUN apt-get update

RUN apt-get install -y wget \
    unzip \
    git

WORKDIR /usr/local

RUN wget https://dl.google.com/go/go1.14.6.linux-amd64.tar.gz

RUN tar -xvf go1.14.6.linux-amd64.tar.gz

RUN export GOROOT=/usr/local/go

RUN export GOPATH=$HOME/go

RUN export PATH=$GOPATH/bin:$GOROOT/bin:$PATH

RUN . ~/.profile

RUN export DATABASE_URL=postgresql://postgres:password@localhost/addr

RUN pg_createcluster 12 main

USER postgres

RUN /etc/init.d/postgresql start && createdb addr && \
    psql -U postgres -d addr -c 'CREATE EXTENSION postgis;' \
    psql -U postgres -c 'CREATE SCHEMA IF NOT EXISTS postgisftw;'

USER root

RUN mkdir /data

WORKDIR /data

RUN wget -O Municipal_Address_Points.zip https://opendata.arcgis.com/datasets/36df55a87f394987875b7f79648c9603_0.zip

RUN unzip Municipal_Address_Points.zip

RUN ogr2ogr -f "PostgreSQL" PG:"host='localhost' user='postgres' dbname='addr' password='password'" \ 
    /data/Municipal_Address_Points.shp -lco GEOMETRY_NAME=geom -lco FID=gid -lco PRECISION=no -nln ottpts -overwrite

RUN mkdir -p /usr/local/go/github.com/CrunchyData/

WORKDIR /usr/local/go/github.com/CrunchyData/

RUN git clone https://github.com/CrunchyData/pg_featureserv

RUN git clone https://github.com/CrunchyData/pg_tileserv

RUN chmod u+x /app/run.sh

ENTRYPOINT [ "/app/run.sh" ]