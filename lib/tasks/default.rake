
begin
  require 'rspec/core/rake_task'
  require 'dotenv/tasks'

  RSpec::Core::RakeTask.new(:spec) do |t|
    t.rspec_opts = '--format documentation --color --require spec_helper'
  end

  task default: [:dotenv, :spec]
rescue LoadError # rubocop:disable Lint/HandleExceptions
end
