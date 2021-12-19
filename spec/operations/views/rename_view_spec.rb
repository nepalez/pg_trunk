# frozen_string_literal: true

describe ActiveRecord::Migration, "#rename_view" do
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
      create_view "admins" do |v|
        v.sql_definition <<~Q.chomp
          SELECT users.id, users.name
          FROM users
          WHERE users.admin
        Q
      end
    RUBY
  end
  let(:new_snippet) do
    <<~RUBY
      create_view "admin_users" do |v|
        v.sql_definition <<~Q.chomp
          SELECT users.id, users.name
          FROM users
          WHERE users.admin
        Q
      end
    RUBY
  end
  let(:query) { "SELECT * FROM admin_users;" }

  context "with a new name" do
    let(:migration) do
      <<~RUBY
        rename_view :admins, to: :admin_users
      RUBY
    end

    its(:execution) { is_expected.to remove(old_snippet).from_schema }
    its(:execution) { is_expected.to insert(new_snippet).into_schema }
    its(:execution) { is_expected.to enable_sql_request(query) }

    its(:inversion) { is_expected.to disable_sql_request(query) }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "with the same name" do
    let(:migration) do
      <<~RUBY
        rename_view :admin_users, to: "public.admin_users"
      RUBY
    end

    it { is_expected.to fail_validation.because(/new name must be different/i) }
  end

  context "when a view was absent" do
    context "without the `if_exists` option" do
      let(:migration) do
        <<~RUBY
          rename_view :administrators, to: :admins
        RUBY
      end

      its(:execution) { is_expected.to raise_error(StandardError) }
    end

    context "with the `if_exists: true` option" do
      let(:migration) do
        <<~RUBY
          rename_view :administrators, to: :admins, if_exists: true
        RUBY
      end

      its(:execution) { is_expected.not_to raise_error }
      it { is_expected.to be_irreversible.because_of(/if_exists: true/i) }
    end
  end
end
