# frozen_string_literal: true

describe ActiveRecord::Migration, "#rename_materialized_view" do
  before_all do
    run_migration <<~RUBY
      create_table :users do |t|
        t.string :name
        t.boolean :admin
      end
    RUBY
  end
  before { run_migration(old_snippet) }

  let(:old_snippet) do
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
  let(:old_query) { "SELECT * FROM admins;" }

  context "with a new name" do
    let(:migration) do
      <<~RUBY
        rename_materialized_view :admins, to: :admin_users
      RUBY
    end
    let(:new_snippet) do
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
    let(:new_query) { "SELECT * FROM admin_users;" }

    its(:execution) { is_expected.to enable_sql_request(new_query) }
    its(:execution) { is_expected.to disable_sql_request(old_query) }
    its(:execution) { is_expected.to insert(new_snippet).into_schema }
    its(:execution) { is_expected.to remove(old_snippet).from_schema }

    its(:inversion) { is_expected.to disable_sql_request(new_query) }
    its(:inversion) { is_expected.to enable_sql_request(old_query) }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "with the same name" do
    let(:migration) do
      <<~RUBY
        rename_materialized_view :admins, to: "public.admins"
      RUBY
    end

    it { is_expected.to fail_validation.because(/new name must be different/i) }
  end

  context "when a materialized view was absent" do
    context "without the `if_exists` option" do
      let(:migration) do
        <<~RUBY
          rename_materialized_view :weird, to: :admin_users
        RUBY
      end

      its(:execution) { is_expected.to raise_error(StandardError) }
    end

    context "with the `if_exists: true` option" do
      let(:migration) do
        <<~RUBY
          rename_materialized_view :weird, to: :admin_users, if_exists: true
        RUBY
      end

      its(:execution) { is_expected.not_to change_schema }
      it { is_expected.to be_irreversible.because_of(/if_exists: true/i) }
    end
  end
end
