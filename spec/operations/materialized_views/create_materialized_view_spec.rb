# frozen_string_literal: true

describe ActiveRecord::Migration, "#create_materialized_view" do
  before_all do
    run_migration <<~RUBY
      create_table "users", force: :cascade do |t|
        t.string "name"
        t.boolean "admin"
      end
    RUBY
  end

  let(:query) { "SELECT * FROM admin_users;" }

  context "when a materialized view was absent" do
    let(:migration) do
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

    its(:execution) { is_expected.to enable_sql_request(query) }
    its(:execution) { is_expected.to insert(migration).into_schema }

    its(:inversion) { is_expected.to disable_sql_request(query) }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "with the `with_data: false` option" do
    let(:migration) do
      <<~RUBY
        create_materialized_view "admin_users" do |v|
          v.sql_definition <<~Q.chomp
            SELECT users.id, users.name
            FROM users
            WHERE users.admin
          Q
          v.with_data false
        end
      RUBY
    end

    its(:execution) { is_expected.to disable_sql_request(query) }
    its(:execution) { is_expected.to insert(migration).into_schema }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "when a materialized view was present" do
    before do
      run_migration <<~RUBY
        create_materialized_view "admin_users" do |v|
          v.sql_definition "SELECT * FROM users"
        end
      RUBY
    end

    context "without the `if_not_exists` option" do
      let(:migration) do
        <<~RUBY
          create_materialized_view "admin_users" do |v|
            v.sql_definition "SELECT * FROM users WHERE admin"
          end
        RUBY
      end

      its(:execution) { is_expected.to raise_error(StandardError) }
    end

    context "with the `if_not_exists: true` option" do
      let(:migration) do
        <<~RUBY
          create_materialized_view "admin_users", if_not_exists: true do |v|
            v.sql_definition "SELECT * FROM users WHERE admin"
          end
        RUBY
      end

      its(:execution) { is_expected.not_to change_schema }
      it { is_expected.to be_irreversible.because_of(/if_not_exists: true/i) }
    end
  end

  context "without sql definition" do
    context "with an existing version" do
      let(:migration) do
        <<~RUBY
          create_materialized_view "admin_users", version: 1
        RUBY
      end
      let(:snippet) do
        <<~RUBY
          create_materialized_view "admin_users" do |v|
            v.sql_definition <<~Q.chomp
              SELECT users.id, users.name
              FROM users
              WHERE users.admin
            Q
          end
        RUBY
      end

      its(:execution) { is_expected.to insert(snippet).into_schema }
      its(:inversion) { is_expected.not_to change_schema }
    end

    context "with an absent version" do
      let(:migration) do
        <<~RUBY
          create_materialized_view "admin_users", version: 2
        RUBY
      end

      its(:execution) { is_expected.to raise_error(StandardError) }
    end

    context "without version" do
      let(:migration) do
        <<~RUBY
          create_materialized_view "admin_users"
        RUBY
      end

      it { is_expected.to fail_validation.because(/sql definition can't be blank/i) }
    end
  end

  context "without a name" do
    let(:migration) do
      <<~RUBY
        create_materialized_view sql_definition: "SELECT * FROM users"
      RUBY
    end

    it { is_expected.to fail_validation.because(/name can't be blank/i) }
  end
end
