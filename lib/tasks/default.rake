
begin
  require 'rspec/core/rake_task'
  require 'dotenv/tasks'

  RSpec::Core::RakeTask.new(:spec) do |t|
    t.rspec_opts = '--format documentation --color --require spec_helper'
  end

  task default: ['build:test'] do
    system 'docker run -it appdax/sbridge:test'
  end
rescue LoadError # rubocop:disable Lint/HandleExceptions
end
