require 'fileutils'

module DBBackup
  module CommandDSL

    module InstanceMethods
      def db_name
        self.class.db_name
      end

      def commands
        self.class.commands
      end

      def ignored_databases
        self.class.ignored_databases
      end
    end

    module ClassMethods
      def name(db_name)
        @db_name ||= db_name
      end

      def ignore_databases(array)
        @ignored_databases = Array(@ignored_databases) + Array(array)
      end

      def command(name, block)
        commands[name.to_sym] = block
      end

      def db_name
        @db_name
      end

      def commands
        @commands ||= {}
      end

      def ignored_databases
        @ignored_databases
      end

      def inherited(subclass)
        subclass.send :instance_variable_set, :@db_name, db_name
        subclass.send :instance_variable_set, :@ignored_databases, ignored_databases
        subclass.send :instance_variable_set, :@commands, commands.dup
      end
    end

    def self.included(base)
      base.extend ClassMethods
      base.send :include, InstanceMethods
    end

  end
end

class DBBackup::Base
  include DBBackup::CommandDSL
  attr_reader :options

  command :dump_db, -> { raise NotImplementedError }
  command :dump_cluster, -> { raise NotImplementedError }
  command :archive, -> (opts) {
    containing_dir = File.dirname(opts[:base_dir])
    archive_name = File.basename(opts[:base_dir])
    %{cd #{containing_dir} && tar -czf #{archive_name}.tar.gz #{archive_name}} }

  def initialize(options={})
    @options = options
    @options[:timestamp] ||= get_timestamp
  end

  def backup
    puts "Backing up #{db_name} to #{base_dir}..."
    FileUtils.mkdir_p(base_dir)
    databases.each { |db| backup_db(db) }
    backup_cluster
    move_to_archive
  end

  def backup_db(db)
    print "Dumping `#{db}`... "
    command(
      :dump_db,
      db: db,
      file: File.join(base_dir, "#{db}.sql")
    )
    puts "DONE"
  end

  def backup_cluster
    print "Dumping cluster... "
    command(
      :dump_cluster,
      file: File.join(base_dir, "00-full-cluster.sql")
    )
    puts "DONE"
  end

  def databases
    raise NotImplementedError
  end

  def move_to_archive
    print "Archiving... "
    command(
      :archive,
      base_dir: base_dir
    )
    FileUtils.rm_rf base_dir
    puts "DONE"
  end

  private

  def command(name, opts={})
    `#{commands[name.to_sym].(options.merge(opts))}`
  end

  def base_dir
    File.join(
      options[:destination],
      base_dir_name
    )
  end

  def base_dir_name
    [
      db_name.downcase,
      options[:timestamp],
    ].join("-")
  end

  def get_timestamp
    Time.now.strftime("%Y%m%d%H%M%S")
  end

end

