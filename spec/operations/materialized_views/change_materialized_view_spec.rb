# frozen_string_literal: true

describe ActiveRecord::Migration, "#change_materialized_view" do
  before_all do
    run_migration <<~RUBY
      create_table "users" do |t|
        t.string "name"
        t.boolean "admin"
      end
    RUBY
  end

  before do
    run_migration <<~RUBY
      create_materialized_view "admins" do |v|
        v.sql_definition <<~Q.chomp
          SELECT users.id, users.name
          FROM users
          WHERE users.admin
        Q
        v.comment "Initial comment"
      end

      add_index :admins, :name, name: "view_index"
    RUBY
  end

  context "with renaming a column" do
    let(:migration) do
      <<~RUBY
        change_materialized_view "admins" do |v|
          v.rename_column "name", to: "full_name"
        end
      RUBY
    end
    let(:snippet) do
      <<~RUBY
        create_materialized_view "admins" do |v|
          v.sql_definition <<~Q.chomp
            SELECT users.id, users.name AS full_name
            FROM users
            WHERE users.admin
          Q
          v.comment "Initial comment"
        end
      RUBY
    end
    let(:query) { "SELECT full_name FROM admins;" }

    its(:execution) { is_expected.to enable_sql_request(query) }
    its(:execution) { is_expected.to insert(snippet).into_schema }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "with changing column storage" do
    let(:migration) do
      <<~RUBY
        change_materialized_view "admins" do |v|
          v.column "name", storage: "external", from_storage: "extended"
        end
      RUBY
    end
    let(:snippet) do
      <<~RUBY
        create_materialized_view "admins" do |v|
          v.sql_definition <<~Q.chomp
            SELECT users.id, users.name
            FROM users
            WHERE users.admin
          Q
          v.column "name", storage: :external
          v.comment "Initial comment"
        end
      RUBY
    end

    its(:execution) { is_expected.to insert(snippet).into_schema }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "with clustering a view by index" do
    let(:migration) do
      <<~RUBY
        change_materialized_view "admins", cluster_on: "view_index"
      RUBY
    end

    its(:execution) { is_expected.not_to raise_error }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "with changing column's statistics" do
    let(:migration) do
      <<~RUBY
        change_materialized_view "admins" do |v|
          v.column "name", statistics: 10, n_distinct: 1
        end
      RUBY
    end

    its(:execution) { is_expected.not_to change_schema }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "with a new comment" do
    let(:migration) do
      <<~RUBY
        change_materialized_view "admins" do |v|
          v.comment "Admin users only", from: "Initial comment"
        end
      RUBY
    end
    let(:snippet) do
      <<~RUBY
        create_materialized_view "admins" do |v|
          v.sql_definition <<~Q.chomp
            SELECT users.id, users.name
            FROM users
            WHERE users.admin
          Q
          v.comment "Admin users only"
        end
      RUBY
    end

    its(:execution) { is_expected.to insert(snippet).into_schema }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "with an empty comment" do
    let(:migration) do
      <<~RUBY
        change_materialized_view "admins" do |v|
          v.comment "", from: "Initial comment"
        end
      RUBY
    end
    let(:snippet) do
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

    its(:execution) { is_expected.to insert(snippet).into_schema }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "when a view was absent" do
    context "without the `if_exists` option" do
      let(:migration) do
        <<~RUBY
          change_materialized_view "weird" do |v|
            v.column "name", storage: :extended
          end
        RUBY
      end

      its(:execution) { is_expected.to raise_error(StandardError) }
    end

    context "with the `if_exists: true` option" do
      let(:migration) do
        <<~RUBY
          change_materialized_view "weird", if_exists: true do |v|
            v.column "name", storage: :extended
          end
        RUBY
      end

      its(:execution) { is_expected.not_to change_schema }
      it { is_expected.to be_irreversible.because_of(/if_exists: true/i) }
    end
  end

  context "with no changes" do
    let(:migration) do
      <<~RUBY
        change_materialized_view "admins"
      RUBY
    end

    it { is_expected.to fail_validation.because(/changes can't be blank/i) }
  end
end
