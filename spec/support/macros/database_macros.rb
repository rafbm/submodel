module DatabaseMacros
  def self.create_databases
    [
      { adapter: 'postgresql', username: `whoami`.chomp, database: 'postgres' },
      { adapter: 'mysql2', username: 'root', database: 'mysql' },
    ].each do |config|
      ActiveRecord::Base.establish_connection(config)
      ActiveRecord::Base.connection.drop_database 'submodel_spec' rescue nil
      ActiveRecord::Base.connection.create_database 'submodel_spec'
    end

    ActiveRecord::Base.logger = ActiveRecord::Migration.verbose = false
  end

  # Taken from https://github.com/mirego/partisan/blob/master/spec/support/macros/database_macros.rb
  def run_migration(&block)
    klass = Class.new(ActiveRecord::Migration)
    klass.send(:define_method, :up) { instance_exec &block }
    klass.new.up
  end

  def raw_select(table, column, id: nil)
    ActiveRecord::Base.connection.select_one("SELECT #{column} FROM #{table} WHERE id = #{id}")[column.to_s]
  end
end
