# frozen_string_literal: true

describe ActiveRecord::Migration, "#drop_check_constraint" do
  before_all do
    run_migration <<~RUBY
      create_table "users" do |t|
        t.string :name
      end
    RUBY
  end

  # satisfy the constraint 'length(name) > 1'
  let(:valid_query) { "INSERT INTO users (name) VALUES ('xx');" }
  # breaks the constraint 'length(name) > 1'
  let(:invalid_query) { "INSERT INTO users (name) VALUES ('x');" }

  context "when the constraint was named explicitly" do
    before { run_migration(snippet) }

    let(:snippet) do
      <<~RUBY.squish
        add_check_constraint "users", "length((name)::text) > 1",
                             name: "name_is_long_enough"
      RUBY
    end

    context "with an expression" do
      let(:migration) do
        <<~RUBY.squish
          drop_check_constraint "users", "length((name)::text) > 1",
                                name: "name_is_long_enough"
        RUBY
      end

      its(:execution) { is_expected.to enable_sql_request(invalid_query) }
      its(:execution) { is_expected.to remove(snippet).from_schema }

      its(:inversion) { is_expected.to disable_sql_request(invalid_query) }
      its(:inversion) { is_expected.to enable_sql_request(valid_query) }
      its(:inversion) { is_expected.not_to change_schema }
    end

    context "without an expression" do
      let(:migration) do
        <<~RUBY
          drop_check_constraint "users", name: "name_is_long_enough"
        RUBY
      end

      its(:execution) { is_expected.to enable_sql_request(invalid_query) }
      its(:execution) { is_expected.to remove(snippet).from_schema }

      it { is_expected.to be_irreversible.because(/expression can't be blank/i) }
    end

    context "without table name" do
      let(:migration) do
        <<~RUBY
          drop_check_constraint
        RUBY
      end

      it { is_expected.to fail_validation.because(/table can't be blank/i) }
    end
  end

  context "when the constraint was anonymous" do
    before { run_migration(snippet) }

    let(:snippet) do
      <<~RUBY.squish
        add_check_constraint "users", "length((name)::text) > 1"
      RUBY
    end
    let(:migration) do
      <<~RUBY
        drop_check_constraint "users", "length((name)::text) > 1"
      RUBY
    end

    its(:execution) { is_expected.to enable_sql_request(invalid_query) }
    its(:execution) { is_expected.to remove(snippet).from_schema }

    its(:inversion) { is_expected.to disable_sql_request(invalid_query) }
    its(:inversion) { is_expected.to enable_sql_request(valid_query) }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "when a constraint not existed" do
    context "without the `it_exists: true` option" do
      let(:migration) do
        <<~RUBY
          drop_check_constraint :users, name: "id_positive"
        RUBY
      end

      its(:execution) { is_expected.to raise_error(StandardError) }
    end

    context "with the `it_exists: true` option" do
      let(:migration) do
        <<~RUBY
          drop_check_constraint :users, "id_positive", if_exists: true
        RUBY
      end

      its(:execution) { is_expected.not_to raise_error }
      it { is_expected.to be_irreversible.because_of(/if_exists: true/i) }
    end
  end
end
