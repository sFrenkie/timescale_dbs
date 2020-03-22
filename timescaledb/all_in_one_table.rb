# frozen_string_literal: true

require 'pg'

PG_ROLE = 'franta'
PG_PASSWORD = ''
PG_DB = 'timescaledb'

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

  con.exec('CREATE TABLE same_value(id bigserial,account bigserial,sensor_id SMALLINT, value REAL, timestamp TIMESTAMPTZ NOT NULL)')
  con.exec("SELECT create_hypertable('same_value', 'timestamp')")
  con&.close
  total_records = HOUSES * HOUSE_RECORDS_PER_DAY
  puts "Generating #{total_records} records by #{FORK_SIZE} concurrent process"
  next_year = Time.new(2020, 1, 1)
  t_s = Time.now
  FORK_SIZE.times do
    fork do
      con_t = PG.connect(dbname: PG_DB, user: PG_ROLE)
      time = Time.new(2019, 1, 1)

      (total_records / FORK_SIZE).times do |_i|
        time += 300
        time = Time.new(2019, 1, 1) if time > next_year
        con_t.exec("INSERT INTO same_value(account,sensor_id,value,timestamp) VALUES(#{rand(SENSOR_RECORDS)}, #{rand(HOUSES)},22.6,'#{time.strftime('%Y-%m-%d %H:%M:%S.%6N %z')}')")
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
  puts "\nBEFORE COMPRESSION\n"
  result = con.exec("SELECT table_size, index_size, total_size FROM hypertable_relation_size_pretty( 'same_value' )")
  puts "TableSize: #{result.getvalue(0, 0)}"
  puts "IndexSize: #{result.getvalue(0, 1)}"
  puts "TotalSize: #{result.getvalue(0, 2)}"

  con.exec("
    ALTER TABLE same_value SET (
      timescaledb.compress,
      timescaledb.compress_segmentby = 'account'
    )")
  # con.exec("SELECT add_compress_chunks_policy('same_value', INTERVAL '7 days');")
  con.exec("SELECT compress_chunk(i) from show_chunks('same_value') i")
  puts "\nAFTER COMPRESSION\n"
  puts "\nSIZE in PG\n"
  result = con.exec("SELECT pg_size_pretty(pg_table_size('same_value')), pg_size_pretty(pg_indexes_size('same_value')), pg_size_pretty(pg_total_relation_size('same_value'))")
  puts "\TableSize: #{result.getvalue(0, 0)}"
  puts "IndexSize: #{result.getvalue(0, 1)}"
  puts "TotalSize: #{result.getvalue(0, 2)}"
  puts "\nSIZE in TIMESCALE\n"
  result = con.exec("SELECT table_size, index_size, total_size FROM hypertable_relation_size_pretty( 'same_value' )")
  puts "TableSize: #{result.getvalue(0, 0)}"
  puts "IndexSize: #{result.getvalue(0, 1)}"
  puts "TotalSize: #{result.getvalue(0, 2)}"
  puts 'Chunk relation size'
  result = con.exec("SELECT table_bytes, index_bytes, total_bytes FROM chunk_relation_size( 'same_value' )")
  sum = Hash.new(0)
  result.each do |chunk| 
    chunk.keys.each {|k| sum[k] += chunk[k].to_i}
  end
  puts "TableSize: #{sum['table_bytes']} bytes"
  puts "IndexSize: #{sum['index_bytes']} bytes"
  puts "TotalSize: #{sum['total_bytes']} bytes"
  puts "#{total_records} (for #{HOUSES} houses) was recorded in #{t_e - t_s} s\n"
rescue PG::Error => e
  puts e.message
ensure
  con&.close
end
