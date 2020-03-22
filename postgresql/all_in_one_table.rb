# frozen_string_literal: true

require 'time'
require 'pg'

PG_ROLE = 'franta'
PG_PASSWORD = ''
PG_DB = 'test'

cmd_args = Hash[ARGV.map { |a| a.split('=') }]

SENSOR_RECORDS = 24 * 60 * 60 / cmd_args.fetch('p', 300).to_i
SENSORS = cmd_args.fetch('s', 8).to_i
HOUSES = cmd_args.fetch('h', 1000).to_i
HOUSE_RECORDS_PER_DAY = SENSORS * SENSOR_RECORDS
HOUSE_RECORDS_PER_WEEK = HOUSE_RECORDS_PER_DAY * 7
HOUSE_RECORDS_PER_MONTH = HOUSE_RECORDS_PER_DAY * 30
HOUSE_RECORDS_PER_YEAR = HOUSE_RECORDS_PER_DAY * 395
FORK_SIZE = (HOUSE_RECORDS_PER_DAY.to_f / (24 * 60 * 60) * HOUSES).ceil * 2

begin
  puts 'Creating table'
  con = PG.connect(dbname: PG_DB, user: PG_ROLE)
  res = con.exec('DROP TABLE IF EXISTS same_value')
  con.exec('CREATE TABLE same_value(id bigserial PRIMARY KEY,account bigserial,sensor_id SMALLINT, value REAL, timestamp TIMESTAMP)')
  con&.close
  total_records = HOUSES * HOUSE_RECORDS_PER_DAY
  puts "Generating #{total_records} records by #{FORK_SIZE} concurrent process"
  t_s = Time.now
  FORK_SIZE.times do
    fork do
      con_t = PG.connect(dbname: PG_DB, user: PG_ROLE)

      (total_records / FORK_SIZE.to_f).ceil.times do |_i|
        con_t.exec("INSERT INTO same_value(account,sensor_id,value,timestamp) VALUES(#{rand(SENSOR_RECORDS)}, #{rand(HOUSES)},22.6,'#{Time.now.strftime('%Y-%m-%d %H:%M:%S.%6N %z')}')")
      end
      con_t&.close
    rescue StandardError => e
      retry if e.to_s[' server closed the connection unexpectedly']
      puts e
    end
  end

  # tell the pool to shutdown in an orderly fashion, allowing in progress work to complete
  # now wait for all work to complete, wait as long as it takes
  puts 'Waiting all process'
  Process.wait
  t_e = Time.now
  con = PG.connect(dbname: PG_DB, user: PG_ROLE)
  result = con.exec("SELECT pg_size_pretty(pg_table_size('same_value')), pg_size_pretty(pg_indexes_size('same_value')), pg_size_pretty(pg_total_relation_size('same_value'))")
  puts "\TableSize: #{result.getvalue(0, 0)}"
  puts "IndexSize: #{result.getvalue(0, 1)}"
  puts "TotalSize: #{result.getvalue(0, 2)}"
  puts "#{total_records} (for #{HOUSES} houses) was recorded in #{t_e - t_s} s\n"
rescue PG::Error => e
  puts e.message
ensure
  con&.close
end
