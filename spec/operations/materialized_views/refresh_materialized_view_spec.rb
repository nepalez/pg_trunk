# frozen_string_literal: true

describe ActiveRecord::Migration, "#refresh_materialized_view" do
  before_all do
    run_migration <<~RUBY
      create_table :users do |t|
        t.string :name
        t.boolean :admin
      end
    RUBY
  end
  before { run_migration(old_snippet) }

  let(:query) { "SELECT * FROM admins;" }
  let(:old_snippet) do
    <<~RUBY
      create_materialized_view "admins" do |v|
        v.sql_definition <<~Q.chomp
          SELECT users.id, users.name
          FROM users
          WHERE users.admin
        Q
        v.with_data false
      end
    RUBY
  end
  let(:new_snippet) do
    <<~RUBY
      create_materialized_view "admins" do |v|
        v.sql_definition <<~Q.chomp
          SELECT users.id, users.name
          FROM users
          WHERE users.admin
        Q
      end
    RUBY
  end

  context "without options" do
    let(:migration) do
      <<~RUBY
        refresh_materialized_view :admins
      RUBY
    end

    its(:execution) { is_expected.to enable_sql_request(query) }
    its(:execution) { is_expected.to insert(new_snippet).into_schema }
    its(:execution) { is_expected.to remove(old_snippet).from_schema }

    # Inversion (up, then down) keeps the schema in the migrated (valid) state
    its(:execution) { is_expected.to enable_sql_request(query) }
    its(:inversion) { is_expected.to insert(new_snippet).into_schema }
    its(:inversion) { is_expected.to remove(old_snippet).from_schema }
  end

  context "with the `with_data: false` option" do
    let(:migration) do
      <<~RUBY
        refresh_materialized_view :admins, with_data: false
      RUBY
    end

    its(:execution) { is_expected.to disable_sql_request(query) }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "with both `with_data` and `algorithm` option" do
    let(:migration) do
      <<~RUBY
        refresh_materialized_view :admins do |v|
          v.with_data false
          v.algorithm :concurrently
        end
      RUBY
    end

    it { is_expected.to fail_validation.because(/algorithm must be blank/i) }
  end
end
