# frozen_string_literal: true

describe ActiveRecord::Migration, "#drop_foreign_key" do
  before_all do
    run_migration <<~RUBY
      create_table :roles do |t|
        t.string :name, index: { unique: true }
      end

      create_table :users do |t|
        t.string :role
      end
    RUBY
  end

  context "when fk was given an explicit name" do
    before { run_migration(snippet) }

    let(:snippet) do
      <<~RUBY.squish
        add_foreign_key "users", "roles",
                        column: "role",
                        primary_key: "name",
                        name: "my_fk"
      RUBY
    end
    let(:invalid_query) do
      <<~Q
        INSERT INTO users (role) VALUES ('admin');
      Q
    end
    let(:valid_query) do
      <<~Q
        INSERT INTO roles (name) VALUES ('admin');
        INSERT INTO users (role) VALUES ('admin');
      Q
    end

    context "when identified by a name only" do
      let(:migration) do
        <<~RUBY
          drop_foreign_key "users", name: "my_fk"
        RUBY
      end

      its(:execution) { is_expected.to enable_sql_request(valid_query) }
      its(:execution) { is_expected.to reenable_sql_request(invalid_query) }
      its(:execution) { is_expected.to remove(snippet).from_schema }

      it { is_expected.to be_irreversible.because(/reference can't be blank/) }
    end

    context "with all attributes of the constraint" do
      let(:migration) do
        <<~RUBY
          drop_foreign_key "users", "roles",
                           column: "role",
                           primary_key: "name",
                           name: "my_fk"
        RUBY
      end

      its(:execution) { is_expected.to enable_sql_request(valid_query) }
      its(:execution) { is_expected.to reenable_sql_request(invalid_query) }
      its(:execution) { is_expected.to remove(snippet).from_schema }

      its(:inversion) { is_expected.to disable_sql_request(invalid_query) }
      its(:inversion) { is_expected.not_to change_schema }
    end

    context "without a name" do
      let(:migration) do
        <<~RUBY
          drop_foreign_key "users"
        RUBY
      end

      it { is_expected.to fail_validation.because(/name can't be blank/i) }
    end

    context "without a table" do
      let(:migration) do
        <<~RUBY
          drop_foreign_key name: "my_fk"
        RUBY
      end

      it { is_expected.to fail_validation.because(/table can't be blank/i) }
    end
  end

  context "when fk got a generated name outside of a table" do
    before { run_migration(snippet) }

    let(:snippet) do
      <<~RUBY.squish
        add_foreign_key "users", "roles",
                        column: "role",
                        primary_key: "name"
      RUBY
    end

    context "with all attributes of the constraint" do
      let(:migration) do
        <<~RUBY
          drop_foreign_key "users", "roles",
                           column: "role",
                           primary_key: "name"
        RUBY
      end

      its(:execution) { is_expected.to remove(snippet).from_schema }
      its(:inversion) { is_expected.not_to change_schema }
    end
  end

  context "when fk got a generated name inside a table" do
    before do
      run_migration <<~RUBY
        change_table :users do |t|
          t.foreign_key :roles, column: :role, primary_key: :name
        end
      RUBY
    end

    let(:migration) do
      <<~RUBY
        drop_foreign_key "users", "roles",
                         column: "role",
                         primary_key: "name"
      RUBY
    end
    let(:snippet) do
      <<~RUBY.squish
        add_foreign_key "users", "roles",
                        column: "role",
                        primary_key: "name"
      RUBY
    end

    its(:execution) { is_expected.to remove(snippet).from_schema }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "when a key not existed" do
    context "without the `it_exists: true` option" do
      let(:migration) do
        <<~RUBY.squish
          drop_foreign_key :users, :roles, name: "unknown"
        RUBY
      end

      its(:execution) { is_expected.to raise_error(StandardError) }
    end

    context "with the `it_exists: true` option" do
      let(:migration) do
        <<~RUBY
          drop_foreign_key :users, :roles, name: :unknown, if_exists: true
        RUBY
      end

      its(:execution) { is_expected.not_to change_schema }
      it { is_expected.to be_irreversible.because_of(/if_exists: true/i) }
    end
  end
end
