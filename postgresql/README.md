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
$ ruby postgresql/all_in_one_table.rb 

Creating table
Generating 2304000 records by 27 concurrent process
Waiting all process

Size of table: 164 MB
2304000 (for 1000 houses) was recorded in 438.569730221 s
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