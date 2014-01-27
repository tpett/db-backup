require_relative 'base'

class DBBackup::PostgreSQL < DBBackup::Base

  name "PSQL"

  ignore_databases %w(template0 template1)

  command :prefix, -> (opts) {
    %{sudo -u #{opts[:user]}} }
  command :list_dbs, -> (opts) {
    %{#{commands[:prefix].(opts)} psql postgres --tuples-only --command="\\\\list"} }
  command :dump_db, -> (opts) {
    %{#{commands[:prefix].(opts)} pg_dump #{opts[:db]} > #{opts[:file]}} }
  command :dump_cluster, -> (opts) {
    %{#{commands[:prefix].(opts)} pg_dumpall > #{opts[:file]}} }

  def databases
    @databases ||= fetch_databases
  end

  private

  def fetch_databases
    lines = command(:list_dbs).split("\n")
    lines.collect do |line|
      line.split("|").first.strip
    end.reject(&:empty?) - ignored_databases
  end

end

if __FILE__ == $0
  DBBackup::PostgreSQL.new(
    user: ENV['PSQL_USER'],
    destination: ENV['BACKUP_PATH']
  ).backup
end
