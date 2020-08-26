#!/bin/sh

export DATABASE_URL=postgresql://postgres:password@localhost/addr

/etc/init.d/postgresql start

cd /usr/local/go/github.com/CrunchyData/pg_featureserv

export PATH=$PATH:/usr/local/go/bin && go build

nohup ./pg_featureserv > fs.log &

cd /usr/local/go/github.com/CrunchyData/pg_tileserv

export PATH=$PATH:/usr/local/go/bin && go build

nohup ./pg_tileserv > ts.log &