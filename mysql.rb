require_relative 'base'

class DBBackup::MySQL < DBBackup::Base

  name "MySQL"

  ignore_databases %w(information_schema performance_schema)

  command :creds, -> (opts) {
    %{-u #{opts[:user]}} }
  command :list_dbs, -> (opts) {
    %{mysql #{commands[:creds].(opts)} --skip-column-names -e "show databases"} }
  command :dump_db, -> (opts) {
    %{mysqldump #{commands[:creds].(opts)} #{opts[:db]} > #{opts[:file]}} }
  command :dump_cluster, -> (opts) {
    commands[:dump_db].(opts.merge(db: "--all-databases")) }

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
  DBBackup::MySQL.new(
    user: ENV['MYSQL_USER'],
    destination: ENV["BACKUP_PATH"]
  ).backup
end
