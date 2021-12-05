# frozen_string_literal: true

# Helpers for migration end-to-end specs
module MigrationsHelper
  extend self

  # Wrap the migration containing ruby code for a `change` method
  # into the corresponding migrator.
  #
  # Methods `execution` and `inversion` return blocks
  # running the migration up or up'n'down correspondingly.
  # As a result the instance of the class can be used as a subject
  # of the test:
  #
  #   subject { TestMigration.new(migration) }
  #   let(:migration) { "puts 'FOOBAR'" }
  #   its(:execution) { is_expected.not_to raise_error }
  #
  class TestMigration
    private def initialize(change, args = {})
      @change = change.to_s
      @verbose = args[:verbose]
    end

    def execution
      proc { run_migration(:up) }
    end

    def inversion
      proc { run_migration(:up, :down) }
    end
    alias reversion inversion

    private

    MIGRATION =
      if Rails::VERSION::MAJOR >= 5
        ::ActiveRecord::Migration[ActiveRecord::Migration.current_version]
      else
        ::ActiveRecord::Migration
      end

    def version
      @version ||= (Time.now.to_f * 1e6).to_i
    end

    def migration_klass
      @migration_klass ||= Class.new(MIGRATION).tap do |m|
        m.class_eval("def change;#{@change};end", __FILE__, __LINE__)
      end
    end

    def migration
      @migration ||= migration_klass.new("migration", version)
    end

    def run_migration(*directions)
      return run_and_report(*directions) if @verbose

      silence_stream($stdout) { run_and_report(*directions) }
    end

    def run_and_report(*directions)
      Array.wrap(directions).each do |direction|
        ActiveRecord::Migrator
          .new(direction, [migration], ActiveRecord::SchemaMigration, version)
          .run
      end
    end

    def silence_stream(stream)
      old_stream = stream.dup
      stream.reopen(IO::NULL)
      stream.sync = true
      yield
    ensure
      stream.reopen(old_stream)
      old_stream.close
    end
  end

  def run_migration(snippet)
    data = self.class.metadata.slice(:verbose)
    TestMigration.new(snippet, data).execution.call
  end

  # Default subject for migration tests
  # It expect the migration to be specified (in a `let` clause)
  # @return [TestMigration]
  def subject
    @subject ||= begin
      raise NoMethodError, <<~MSG.squish unless respond_to?(:migration)
        Use `let(:migration) { ... }` with a Ruby code for migration
      MSG

      data = self.class.metadata.slice(:verbose)
      TestMigration.new(migration, data)
    end
  end

  # Read the database schema
  # @return [String]
  def read_schema(skip_header: false)
    stream = StringIO.new
    ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, stream)
    stream = stream.string.lines.map(&:rstrip).join("\n")
    return stream unless skip_header

    stream.lines.reject { |line| line["ActiveRecord::Schema.define"] }.join
  end
end

# expect { ... }.not_to change_schema
RSpec::Matchers.define :change_schema do
  supports_block_expectations

  match_when_negated do |block|
    @expected = MigrationsHelper.read_schema(skip_header: true)
    block.call
    @actual = MigrationsHelper.read_schema(skip_header: true)
    expect(@actual).to eq(@expected)
  end

  failure_message_when_negated do
    differ = RSpec::Support::Differ.new(color: true)
    <<~MSG
      It is expected the schema to remain the same, but it has been changed:

      #{differ.diff_as_string(@actual, @expected).indent(2)}
    MSG
  end
end

# expect { ... }.to insert(snippet).into_schema
# expect { ... }.to insert(snippet).into_schema
RSpec::Matchers.define :insert do |snippet|
  supports_block_expectations

  description do
    "insert given snippet into the database schema"
  end

  attr_reader :strict

  chain(:into_schema) {} # does nothing; added for readability

  match do |block|
    @expected = snippet.lines.map(&:rstrip).join("\n") << "\n"
    @expected = @expected.indent(2) unless @expected[/\A  /]

    @final = false
    @actual = MigrationsHelper.read_schema
    expect(@actual).not_to include(@expected)

    block.call

    @final = true
    @actual = MigrationsHelper.read_schema
    expect(@actual).to include(@expected)
  end

  failure_message do
    header = <<~MSG
      It is expected the following snippet to be added to the schema:

      #{@expected}
    MSG

    return <<~MSG unless @final
      #{header.strip}

      But it was present from the very beginning:

      #{@actual}
    MSG

    differ = RSpec::Support::Differ.new(color: true)
    <<~MSG
      #{header.strip}

      But the final snippet is different:

      #{differ.diff_as_string(@actual, @expected).indent(2)}
    MSG
  end
end

# expect { ... }.to remove(snippet).from_schema
# expect { ... }.to remove(snippet).from_schema
RSpec::Matchers.define :remove do |snippet|
  supports_block_expectations

  description do
    "insert given snippet into the database schema"
  end

  attr_reader :strict

  chain(:from_schema) {} # does nothing; added for readability

  match do |block|
    @expected = snippet.lines.map(&:rstrip).join("\n") << "\n"
    @expected = @expected.indent(2) unless @expected[/\A  /]

    @final = false
    @actual = MigrationsHelper.read_schema
    expect(@actual).to include(@expected)

    block.call

    @final = true
    @actual = MigrationsHelper.read_schema
    expect(@actual).not_to include(@expected)
  end

  failure_message do
    header = <<~MSG
      It is expected the following snippet to be removed from the schema:

      #{@expected}
    MSG

    return <<~MSG if @final
      #{header}

      But it is still present in the schema:

      #{@actual}
    MSG

    differ = RSpec::Support::Differ.new(color: true)
    <<~MSG
      #{header.strip}

      But the initial schema was different:

      #{differ.diff_as_string(@actual, @expected).indent(2)}
    MSG
  end
end

# expect { ... }.to enable_sql_request(query)
#
# Because we use a `transactional` strategy of the database cleaner,
# the whole migration is wrapped into the transaction which won't
# be fixed, but rolled out at the end of each spec.
#
# In this case some queries provide false negatives
# because they expect a DDL transaction to be fixed
# before running a select. For this reason we enable
# to ignore particular errors, treating them as positive outcomes.
#
# expect { ... }.to enable_sql_request(query).ignoring(/values/i)
RSpec::Matchers.define :enable_sql_request do |query|
  supports_block_expectations

  description do
    "enable valid SQL request"
  end

  chain(:ignoring, :pattern)

  match do |block|
    block.call
    check = proc { ActiveRecord::Base.connection.execute(query) }

    if pattern
      expect(&check).to raise_error(pattern)
    else
      expect(&check).not_to raise_error
    end
  end
end

RSpec::Matchers.alias_matcher :reenable_sql_request, :enable_sql_request do
  "enable SQL request as valid again"
end

# expect { ... }.to disable_sql_request(query)
RSpec::Matchers.define :disable_sql_request do |query|
  supports_block_expectations

  description do
    "disable SQL request as invalid"
  end

  match do |block|
    block.call
    expect { ActiveRecord::Base.connection.execute(query) }.to raise_error(StandardError)
  end
end

# expect { ... }.to fail_validation.because_of(/name/i)
RSpec::Matchers.define :fail_validation do
  chain(:because_of) { |regexp| @pattern = regexp }
  chain(:because) { |regexp| @pattern = regexp }

  attr_reader :pattern

  match do |test_migration|
    @actual = nil
    expect { test_migration.execution.call }.to raise_error do |ex|
      @actual = ex
      expect(ex).to be_a(StandardError)
      expect(ex.cause).to be_a(ActiveModel::ValidationError)
      expect(ex.message).to match(pattern) if pattern
    end
  end

  failure_message do
    message = ["It is expected the migration to fail validation"]
    message << "for the following reason: #{pattern}" if pattern
    if @actual.nil?
      message << "but it proves valid"
    elsif @actual.cause.is_a?(ActiveModel::ValidationError)
      message << "but the actual reason is different:"
      message << @actual.cause.message
    else
      message << "but it has risen the following exception:"
      message << @actual.inspect
      message << @actual.backtrace.join("\n")
    end
    message.join("\n")
  end
end

# expect { ... }.to be_irreversible.because_of(/added values/i)
RSpec::Matchers.define :be_irreversible do
  description do
    "be irreversible migration"
  end

  chain(:because_of) { |regexp| @pattern = regexp }
  chain(:because) { |regexp| @pattern = regexp }

  attr_reader :pattern

  match do |test_migration|
    @actual = nil
    expect { test_migration.inversion.call }.to raise_error do |ex|
      @actual = ex
      expect(ex).to be_a(StandardError)
      expect(ex.cause).to be_a(ActiveRecord::IrreversibleMigration)
      next unless pattern

      expect(ex.message).to match(pattern)
    end
  end

  failure_message do
    message = ["It is expected the migration to be irreversible"]
    message << "for the following reason: #{pattern}" if pattern

    if @actual.nil?
      message << "but it proves reversible"
    elsif @actual.cause.is_a?(ActiveRecord::IrreversibleMigration)
      message << "but the actual reason is different:"
      message << @actual.message
    else
      message << "but it has risen the following exception:"
      message << @actual.inspect
    end
    message.join("\n")
  end
end

RSpec.configure do |config|
  migration = { described_class: ActiveRecord::Migration }
  config.include MigrationsHelper, **migration
  config.around(:each, **migration) do |example|
    DatabaseCleaner.start
    ActiveRecord::SchemaMigration.create_table
    example.run
    DatabaseCleaner.clean
  end
end
