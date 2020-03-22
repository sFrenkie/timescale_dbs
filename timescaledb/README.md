# Prerequisities

PostgreSQL with enabled timescaledb as preloaded library. Edito psql conf e.g.
```
echo "shared_preload_libraries = 'timescaledb'" >> /home/franta/postgresql/11/data/postgresql.conf
```

then `createdb timescaledb` and connect to this `psql timescaledb` to run `CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;`

# all_in_one_table.rb

Script `all_in_one_table.rb` creates a table `CREATE TABLE same_value(id bigserial PRIMARY KEY,account bigserial, value REAL)` and run test by configuration in file. Test writes selected amount of records to DB and write the size of the table.

Examples how to run without edit file
```bash
ruby postgresql/all_in_one_table.rb h=1 s=8 p=600
# h=AMOUNT_OF_HOUSES(default 1000)
# s=AMOUNT_OF_SENSORS_PER_HOUSE(default 8)
# p=PUSH_INTERVAL(default 300)
```

## Output
```bash
$ ruby timescaledb/all_in_one_table.rb h=1000 s=8 p=300
Creating table
Generating 2304000 records by 27 concurrent process
Waiting all process

 table_size | index_size | toast_size | total_size 
------------+------------+------------+------------
 133 MB     | 84 MB      |            | 216 MB

2304000 (for 1000 houses) was recorded in 437.977842254 s
 ```

 # account_per_table.rb

Script `account_per_table.rb` creates tables `CREATE TABLE same_value_#{id}(id bigserial PRIMARY KEY, value REAL)` and run test by configuration in file. Test writes selected amount of records to DB and write the size of the tables.

## Output
```bash
$ ruby postgresql/account_per_table.rb 

Creating tables
Generatinh 2304000 records by 27 concurrent process
Waiting all process
It was used 27 concurrent processes.
2304000 (for 1000 houses) was recorded in 486.212442756 s

Size of tables: {"kB"=>1112632}
 ```