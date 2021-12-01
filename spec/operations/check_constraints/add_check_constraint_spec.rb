# frozen_string_literal: true

describe ActiveRecord::Migration, "#add_check_constraint" do
  before_all do
    run_migration <<~RUBY
      create_table "users" do |t|
        t.string :name
      end
    RUBY
  end

  let(:valid_query)   { "INSERT INTO users (name) VALUES ('xx');" }
  # breaks the constraint 'length(name) > 1'
  let(:invalid_query) { "INSERT INTO users (name) VALUES ('x');" }

  context "when added separately" do
    let(:migration) do
      <<~RUBY.squish
        add_check_constraint "users", "length((name)::text) > 1"
      RUBY
    end

    its(:execution) { is_expected.to enable_sql_request(valid_query) }
    its(:execution) { is_expected.to disable_sql_request(invalid_query) }
    its(:execution) { is_expected.to insert(migration).into_schema }

    its(:inversion) { is_expected.to enable_sql_request(valid_query) }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "when added inside the table definition" do
    let(:migration) do
      <<~RUBY
        change_table "users" do |t|
          t.check_constraint "length(name) > 1"
        end
      RUBY
    end
    let(:snippet) do
      <<~RUBY.squish
        add_check_constraint "users", "length((name)::text) > 1"
      RUBY
    end

    its(:execution) { is_expected.to disable_sql_request(invalid_query) }
    its(:execution) { is_expected.to enable_sql_request(valid_query) }
    its(:execution) { is_expected.to insert(snippet).into_schema }

    its(:inversion) { is_expected.not_to change_schema }
  end

  context "with a comment" do
    let(:migration) do
      <<~RUBY.squish
        add_check_constraint "users", "length((name)::text) > 1",
                             comment: "Name is long enough"
      RUBY
    end

    its(:execution) { is_expected.to insert(migration).into_schema }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "with an explicit name" do
    let(:migration) do
      <<~RUBY.squish
        add_check_constraint "users", "length((name)::text) > 1",
                             name: "name_is_long_enough"
      RUBY
    end

    its(:execution) { is_expected.to insert(migration).into_schema }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "without an expression" do
    let(:migration) do
      <<~RUBY
        add_check_constraint "users"
      RUBY
    end

    it { is_expected.to fail_validation.because(/expression can't be blank/i) }
  end
end
