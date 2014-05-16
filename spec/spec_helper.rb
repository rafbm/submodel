require 'active_record'
require 'carmen'

Dir[File.expand_path('../../spec/support/**/*.rb', __FILE__)].map(&method(:require))

RSpec.configure do |config|
  config.include DatabaseMacros

  config.before :suite do
    DatabaseMacros.create_databases
  end

  config.filter_run :focus
  config.run_all_when_everything_filtered = true

  if config.files_to_run.one?
    # RSpec filters the backtrace by default so as not to be so noisy.
    # This causes the full backtrace to be printed when running a single
    # spec file (e.g. to troubleshoot a particular spec failure).
    config.full_backtrace = false

    # Use the documentation formatter for detailed output,
    # unless a formatter has already been configured
    # (e.g. via a command-line flag).
    config.formatter = 'doc' if config.formatters.none?
  end

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = :random

  # Seed global randomization in this process using the `--seed` CLI option.
  # Setting this allows you to use `--seed` to deterministically reproduce
  # test failures related to randomization by passing the same `--seed` value
  # as the one that triggered the failure.
  Kernel.srand config.seed

  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
  end

  config.mock_with :rspec do |mocks|
    mocks.syntax = :expect
    mocks.verify_partial_doubles = true
  end
end
