# Ottawa Address Search

Testing out `pg_featureserv` and `pg_tileserv` using City of Ottawa Open Data - Municipal Addresses.

`export DATABASE_URL="host=localhost user=postgres password=password"`

## Setup

### Install Go

`sudo add-apt-repository ppa:longsleep/golang-backports`

`sudo apt update`

`sudo apt install golang-go`

### Prepare the database

`sudo -i`

`su - postgres`

`createdb addr`

`psql -U postgres -d addr -c 'CREATE EXTENSION postgis;'`

`psql -U posgres -c 'CREATE SCHEMA IF NOT EXISTS postgisftw;'`

### Download data

`wget https://opendata.arcgis.com/datasets/36df55a87f394987875b7f79648c9603_0.zip`

`unzip Municipal_Address_Points-shp.zip`

### Load data into PostgreSQL

`ogr2ogr -f "PostgreSQL" PG:"host='localhost' user='postgres' dbname='addr' password='password'" /data/Municipal_Address_Points.shp -lco GEOMETRY_NAME=geom -lco FID=gid -lco PRECISION=no -nln ottpts -overwrite`

### Address queries

```sql
ALTER TABLE postgisftw.ottpts ADD COLUMN ts tsvector;

UPDATE postgisftw.ottpts SET ts = 
    to_tsvector('addressing_en', fulladdr);

VACUUM (ANALYZE, FULL) postgisftw.ottpts;

CREATE INDEX ottpts_ts_x ON postgisftw.ottpts USING GIN (ts);
CREATE INDEX ottpts_geom_x ON postgisftw.ottpts USING GIST (geom);
```

``` sql
CREATE OR REPLACE FUNCTION to_tsquery_partial(text)
RETURNS tsquery 
AS $$
BEGIN
  RETURN to_tsquery('simple',
             array_to_string(
               regexp_split_to_array(
                 trim($1),E'\\s+'),' & ') 
             || CASE WHEN $1 ~ ' $' THEN '' ELSE ':*' END
           );
END;
$$ 
LANGUAGE 'plpgsql'
PARALLEL SAFE
IMMUTABLE
STRICT;
```

```sql
DROP FUNCTION IF EXISTS postgisftw.address_query;

CREATE OR REPLACE FUNCTION postgisftw.address_query(
    partialstr text DEFAULT '')
RETURNS TABLE(gid integer, value text, rank real, geom geometry)
AS $$
BEGIN
    RETURN QUERY
        SELECT
          p.gid AS id,
          initcap(fulladdr) AS value,
          ts_rank_cd(p.ts, query) AS rank,
          p.geom
        FROM postgisftw.ottpts p,
             to_tsquery_partial(partialstr) AS query
        WHERE ts @@ query
        ORDER BY rank DESC
        LIMIT 15;
END;
$$
LANGUAGE 'plpgsql'
PARALLEL SAFE
STABLE
STRICT;
```
## Acknowledgements
* [Geocoding and Text Search in PostGIS presented by Paul Ramsey at STL PostGIS Day 2019](https://www.youtube.com/watch?v=7RumQ9oXA9Q)