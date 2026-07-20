namespace :db do
  desc "Load Solid Queue/Cache/Cable schemas if their tables are missing"
  task prepare_solid_schemas: :environment do
    # config/database.yml points primary/cache/queue/cable at the same DATABASE_URL
    # (single free-tier Postgres, no Redis). Because the physical database already
    # exists once `primary` is prepared, `db:prepare` treats cache/queue/cable as
    # "existing" databases and looks for pending migrations to run them — but those
    # roles have no db/*_migrate directories, only schema snapshots, so it finds
    # nothing pending and silently skips loading solid_queue_recurring_tasks and
    # friends. Load each schema explicitly, but only when its tables are actually
    # missing, so this stays a no-op (and doesn't drop data) on every other boot.
    { queue: "solid_queue_jobs", cache: "solid_cache_entries", cable: "solid_cable_messages" }.each do |role, table|
      config = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: role.to_s)
      next unless config

      ActiveRecord::Base.establish_connection(config)
      if ActiveRecord::Base.connection.table_exists?(table)
        puts "[prepare_solid_schemas] #{role}: #{table} already present, skipping"
      else
        puts "[prepare_solid_schemas] #{role}: #{table} missing, loading db/#{role}_schema.rb"
        ActiveRecord::Tasks::DatabaseTasks.load_schema(config, ActiveRecord.schema_format)
      end
    end
  ensure
    ActiveRecord::Base.establish_connection(:primary)
  end
end
