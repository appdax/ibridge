namespace :revisions do
  desc 'Available revisions'
  task(:all) { puts Drive.revisions }

  desc 'Last imported revision'
  task :last, [:rev] do |_, args|
    Drive.last_imported_revision = args[:rev] if args[:rev]
    puts Drive.last_imported_revision
  end

  desc 'Revisions newer then the last imported one'
  task(:next) { puts Drive.revisions_to_import }

  desc 'Step back last imported revision'
  task(:back, [:steps]) do |_, args|
    args.with_defaults steps: 1
    Drive.last_imported_revision = Drive.revisions[args[:steps].to_i]
    puts Drive.last_imported_revision
  end
end
