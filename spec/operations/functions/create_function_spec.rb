# frozen_string_literal: true

describe ActiveRecord::Migration, "#create_function" do
  context "with a minimal definition" do
    let(:migration) do
      <<~RUBY
        create_function "mult(a integer, b integer) integer", body: "SELECT a * b"
      RUBY
    end
    let(:snippet) do
      <<~RUBY
        create_function "mult(a integer, b integer) integer" do |f|
          f.body "SELECT a * b"
        end
      RUBY
    end
    let(:query) { "SELECT mult(1, 3);" }

    its(:execution) { is_expected.to enable_sql_request(query) }
    its(:execution) { is_expected.to insert(snippet).into_schema }

    its(:inversion) { is_expected.to disable_sql_request(query) }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "with options" do
    let(:migration) do
      <<~RUBY
        create_function "mult(a integer, b integer) integer" do |f|
          f.language "plpgsql"
          f.volatility :immutable
          f.leakproof true
          f.strict true
          f.parallel :safe
          f.cost 1.0
          f.body "BEGIN return a * b; END;"
          f.comment "Multiply 2 values"
        end
      RUBY
    end

    its(:execution) { is_expected.to insert(migration).into_schema }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "when a function existed" do
    before do
      run_migration <<~RUBY
        create_function "mult(a int, b int) int", body: "SELECT 0"
      RUBY
    end

    context "without replace_existing: true" do
      let(:migration) do
        <<~RUBY
          create_function "mult(a integer, b integer) integer",
                          body: "SELECT a * b"
        RUBY
      end

      its(:execution) { is_expected.to raise_error(StandardError) }
    end

    context "with replace_existing: true" do
      let(:migration) do
        <<~RUBY
          create_function "mult(a integer, b integer) integer",
                          body: "SELECT a * b",
                          replace_existing: true
        RUBY
      end
      let(:new_snippet) do
        <<~RUBY
          create_function "mult(a integer, b integer) integer" do |f|
            f.body "SELECT a * b"
          end
        RUBY
      end
      let(:old_snippet) do
        <<~RUBY
          create_function "mult(a integer, b integer) integer" do |f|
            f.body "SELECT 0"
          end
        RUBY
      end

      its(:execution) { is_expected.to remove(old_snippet).from_schema }
      its(:execution) { is_expected.to insert(new_snippet).into_schema }
      it { is_expected.to be_irreversible.because_of(/replace_existing: true/i) }
    end
  end

  context "when a function contains SQL injection" do
    # Running it would inject the SQL code going after $$
    let(:migration) do
      <<~RUBY
        create_function "mult(a integer, b integer) integer" do |f|
          f.body <<~Q
            SELECT a * b$$;DROP TABLE priceless;--
          Q
        end
      RUBY
    end

    it { is_expected.to fail_validation.because_of(/SQL injection/i) }
  end

  context "when a function has named $-quotations" do
    # This code is safe because `$greeting$` doesn't closes `$$`
    let(:migration) do
      <<~RUBY
        create_function "greet(name text) text" do |f|
          f.body "SELECT $greeting$Hi $greeting$ || name"
        end
      RUBY
    end

    its(:execution) { is_expected.to insert(migration).into_schema }
  end

  context "without returned value" do
    let(:migration) do
      <<~RUBY.squish
        create_function "mult(a integer, b integer, OUT c integer)",
                        body: "SELECT a * b"
      RUBY
    end
    let(:snippet) do
      <<~RUBY
        create_function "mult(a integer, b integer, OUT c integer) integer" do |f|
          f.body "SELECT a * b"
        end
      RUBY
    end
    let(:query) { "SELECT mult(1, 3);" }

    its(:execution) { is_expected.to enable_sql_request(query) }
    its(:execution) { is_expected.to insert(snippet).into_schema }

    its(:inversion) { is_expected.to disable_sql_request(query) }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "without arguments" do
    let(:migration) do
      <<~RUBY
        create_function "set_foo", body: "SET foo = 42"
      RUBY
    end
    let(:snippet) do
      <<~RUBY
        create_function "set_foo() void" do |f|
          f.body "SET foo = 42"
        end
      RUBY
    end

    its(:execution) { is_expected.to insert(snippet).into_schema }
  end

  context "without name" do
    let(:migration) do
      <<~RUBY
        create_function body: "INSERT INTO foo(bar) VALUES (1);"
      RUBY
    end

    it { is_expected.to fail_validation.because(/name can't be blank/i) }
  end

  context "with unknown volatility" do
    let(:migration) do
      <<~RUBY
        create_function "mult(a int, b int) int",
                        body: "SELECT a * b",
                        volatility: :whatever
      RUBY
    end

    it { is_expected.to fail_validation.because(/not included in the list/i) }
  end

  context "without body" do
    let(:migration) do
      <<~RUBY
        create_function "foo () void"
      RUBY
    end

    it { is_expected.to fail_validation.because(/body can't be blank/i) }
  end
end
