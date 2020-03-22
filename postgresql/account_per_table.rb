# frozen_string_literal: true

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
FORK_SIZE = (HOUSE_RECORDS_PER_DAY.to_f / (24 * 60 * 60) * HOUSES).ceil

begin
  con = PG.connect(dbname: PG_DB, user: PG_ROLE)

  puts 'Creating tables'
  HOUSES.times do |id|
    con.exec("DROP TABLE IF EXISTS same_value_#{id}")
    con.exec("CREATE TABLE same_value_#{id}(id bigserial PRIMARY KEY, sensor_id SMALLINT, value REAL, timestamp TIMESTAMP)")
  end
  con&.close

  total_records = HOUSES * HOUSE_RECORDS_PER_DAY
  puts "Generatinh #{total_records} records by #{FORK_SIZE} concurrent process"
  t_s = Time.now
  FORK_SIZE.times do
    fork do
      con_t = PG.connect(dbname: PG_DB, user: PG_ROLE)

      (total_records / FORK_SIZE).times do |_i|
        con_t.exec("INSERT INTO same_value_#{rand(HOUSES)}(sensor_id,value,timestamp) VALUES(#{rand(SENSOR_RECORDS)},22.6,'#{Time.now.strftime('%Y-%m-%d %H:%M:%S.%6N %z')}')")
      end
      con_t&.close
    rescue StandardError => e
      retry if e.to_s[' server closed the connection unexpectedly']
    end
  end

  # tell the pool to shutdown in an orderly fashion, allowing in progress work to complete
  # now wait for all work to complete, wait as long as it takes
  puts 'Waiting all process'
  Process.wait
  t_e = Time.now
  con = PG.connect(dbname: PG_DB, user: PG_ROLE)
  puts "It was used #{FORK_SIZE} concurrent processes."
  sum = Hash.new(0)
  HOUSES.times do |id|
    result = con.exec("SELECT pg_size_pretty( pg_total_relation_size('same_value_#{id}') )")
    u = result.getvalue(0, 0).split(' ').last
    sum[u] += result.getvalue(0, 0).split(' ').first.to_i
  end
  puts "#{total_records} (for #{HOUSES} houses) was recorded in #{t_e - t_s} s\n"
  puts "\nSize of tables: #{sum}"
rescue PG::Error => e
  puts e.message
ensure
  con&.close
end
