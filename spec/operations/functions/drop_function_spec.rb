# frozen_string_literal: true

describe ActiveRecord::Migration, "#drop_function" do
  before { run_migration(snippet) }

  let(:snippet) do
    <<~RUBY
      create_function "mult(a integer, b integer) integer" do |f|
        f.body "SELECT a * b"
      end
    RUBY
  end
  let(:query) { "SELECT mult(6, 7);" }

  context "with a function name only" do
    let(:migration) do
      <<~RUBY
        drop_function "mult"
      RUBY
    end

    its(:execution) { is_expected.to disable_sql_request(query) }
    its(:execution) { is_expected.to remove(snippet).from_schema }
    it { is_expected.to be_irreversible.because(/body can't be blank/i) }
  end

  context "with a function signature" do
    let(:migration) do
      <<~RUBY
        drop_function "mult (int, int)"
      RUBY
    end

    its(:execution) { is_expected.to disable_sql_request(query) }
    its(:execution) { is_expected.to remove(snippet).from_schema }
    it { is_expected.to be_irreversible.because(/body can't be blank/i) }
  end

  context "with a function body" do
    let(:migration) do
      <<~RUBY
        drop_function "mult (a int, b int) int", body: "SELECT a * b"
      RUBY
    end

    its(:execution) { is_expected.to disable_sql_request(query) }
    its(:execution) { is_expected.to remove(snippet).from_schema }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "with additional options" do
    let(:migration) do
      <<~RUBY
        drop_function "mult(a integer, b integer) integer" do |f|
          f.language "plpgsql"
          f.volatility :immutable
          f.leakproof true
          f.strict true
          f.parallel :safe
          f.cost 5.0
          f.body "BEGIN RETURN a * b; END;"
          f.comment "Multiply 2 integers"
        end
      RUBY
    end
    let(:new_snippet) do
      <<~RUBY
        create_function "mult(a integer, b integer) integer" do |f|
          f.language "plpgsql"
          f.volatility :immutable
          f.leakproof true
          f.strict true
          f.parallel :safe
          f.cost 5.0
          f.body "BEGIN RETURN a * b; END;"
          f.comment "Multiply 2 integers"
        end
      RUBY
    end

    its(:execution) { is_expected.to disable_sql_request(query) }
    its(:execution) { is_expected.to remove(snippet).from_schema }

    its(:inversion) { is_expected.to enable_sql_request(query) }
    its(:inversion) { is_expected.to insert(new_snippet).into_schema }
  end

  context "without a name" do
    let(:migration) do
      <<~RUBY
        drop_function
      RUBY
    end

    it { is_expected.to fail_validation.because(/name can't be blank/i) }
  end

  context "when several functions existed" do
    before do
      run_migration <<~RUBY
        create_function "mult(a int, b int, c int) int",
                        body: "SELECT a * b * c"
      RUBY
    end

    context "with a name only" do
      let(:migration) do
        <<~RUBY
          drop_function "mult"
        RUBY
      end

      its(:execution) { is_expected.to raise_exception(StandardError) }
    end

    context "with a signature" do
      let(:migration) do
        <<~RUBY
          drop_function "mult(integer, integer)"
        RUBY
      end

      its(:execution) { is_expected.to remove(snippet).from_schema }
    end
  end

  context "when the function was used" do
    before do
      run_migration <<~RUBY
        create_table "foo" do |t|
          t.integer "a"
          t.integer "b"
          t.index "mult(a, b)"
        end
      RUBY
    end

    context "without the :force option" do
      let(:migration) do
        <<~RUBY
          drop_function "mult"
        RUBY
      end

      its(:execution) { is_expected.to raise_exception(StandardError) }
    end

    context "with the force: :cascade option" do
      let(:migration) do
        <<~RUBY
          drop_function "mult", force: :cascade
        RUBY
      end

      its(:execution) { is_expected.to remove(snippet).from_schema }
      it { is_expected.to be_irreversible.because_of(/force: :cascade/i) }
    end
  end

  context "when the function was absent" do
    context "without the :if_exists option" do
      let(:migration) do
        <<~RUBY
          drop_function "unknown"
        RUBY
      end

      its(:execution) { is_expected.to raise_error(StandardError) }
    end

    context "with the if_exists: true option" do
      let(:migration) do
        <<~RUBY
          drop_function "unknown", if_exists: true
        RUBY
      end

      its(:execution) { is_expected.not_to change_schema }
      it { is_expected.to be_irreversible.because_of(/if_exists: true/i) }
    end
  end
end
