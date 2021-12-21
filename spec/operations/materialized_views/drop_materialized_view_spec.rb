# frozen_string_literal: true

describe ActiveRecord::Migration, "#drop_materialized_view" do
  before_all do
    run_migration <<~RUBY
      create_table "users", force: :cascade do |t|
        t.string "name"
        t.boolean "admin"
      end

      create_table "weird"
    RUBY
  end
  before { run_migration(snippet) }

  let(:snippet) do
    <<~RUBY
      create_materialized_view "admin_users" do |v|
        v.sql_definition <<~Q.chomp
          SELECT users.id, users.name
          FROM users
          WHERE users.admin
        Q
        v.column "name", storage: :external
        v.comment "Admin users only"
      end
    RUBY
  end
  let(:query) { "SELECT * FROM admin_users;" }

  context "with a full definition" do
    let(:migration) do
      <<~RUBY
        drop_materialized_view "admin_users" do |v|
          v.sql_definition <<~Q.chomp
            SELECT users.id, users.name
            FROM users
            WHERE users.admin
          Q
          v.column "name", storage: :external
          v.comment "Admin users only"
        end
      RUBY
    end

    its(:execution) { is_expected.to disable_sql_request(query) }
    its(:execution) { is_expected.to remove(snippet).from_schema }

    its(:inversion) { is_expected.to enable_sql_request(query) }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "with a version-based definition" do
    let(:migration) do
      <<~RUBY
        drop_materialized_view "admin_users", revert_to_version: 1 do |v|
          v.column "name", storage: :external
          v.comment "Admin users only"
        end
      RUBY
    end

    its(:execution) { is_expected.to disable_sql_request(query) }
    its(:execution) { is_expected.to remove(snippet).from_schema }

    its(:inversion) { is_expected.to enable_sql_request(query) }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "with a name only" do
    let(:migration) do
      <<~RUBY
        drop_materialized_view "admin_users"
      RUBY
    end

    its(:execution) { is_expected.to disable_sql_request(query) }
    its(:execution) { is_expected.to remove(snippet).from_schema }
    it { is_expected.to be_irreversible.because(/sql_definition can't be blank/i) }
  end

  context "when a view was absent" do
    context "without the `if_exists` option" do
      let(:migration) do
        <<~RUBY
          drop_materialized_view "unknown"
        RUBY
      end

      its(:execution) { is_expected.to raise_error(StandardError) }
    end

    context "with the `replace_existing: true` option" do
      let(:migration) do
        <<~RUBY
          drop_materialized_view "unknown", if_exists: true
        RUBY
      end

      its(:execution) { is_expected.not_to change_schema }
      it { is_expected.to be_irreversible.because_of(/if_exists: true/i) }
    end
  end

  context "when a view was used" do
    before do
      run_migration <<~RUBY
        create_function "do_nothing() admin_users",
                        body: "SELECT * FROM admin_users;"
      RUBY
    end

    context "without the `:force` option" do
      let(:migration) do
        <<~RUBY
          drop_materialized_view "admin_users"
        RUBY
      end

      its(:execution) { is_expected.to raise_error(StandardError) }
    end

    context "with the `force: :cascade` option" do
      let(:migration) do
        <<~RUBY
          drop_materialized_view "admin_users", force: :cascade
        RUBY
      end

      its(:execution) { is_expected.to disable_sql_request(query) }
      its(:execution) { is_expected.to remove(snippet).from_schema }
      it { is_expected.to be_irreversible.because_of(/force: :cascade/i) }
    end
  end

  context "without a name" do
    let(:migration) do
      <<~RUBY
        drop_materialized_view sql_definition: "SELECT * FROM users"
      RUBY
    end

    it { is_expected.to fail_validation.because(/name can't be blank/i) }
  end
end
