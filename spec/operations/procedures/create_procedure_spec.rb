# frozen_string_literal: true

describe ActiveRecord::Migration, "#create_procedure", since_version: 11 do
  context "with a minimal definition" do
    let(:migration) do
      <<~RUBY
        create_procedure "set_foo(a integer)", body: "SET custom.foo = a"
      RUBY
    end
    let(:snippet) do
      <<~RUBY
        create_procedure "set_foo(a integer)" do |p|
          p.body "SET custom.foo = a"
        end
      RUBY
    end
    let(:query) { "CALL set_foo(42);" }

    its(:execution) { is_expected.to enable_sql_request(query) }
    its(:execution) { is_expected.to insert(snippet).into_schema }

    its(:inversion) { is_expected.to disable_sql_request(query) }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "with options" do
    let(:migration) do
      <<~RUBY
        create_procedure "set_foo(a integer)" do |p|
          p.language "plpgsql"
          p.body "BEGIN set custom.foo = a; END;"
          p.comment "Multiply 2 values"
        end
      RUBY
    end

    its(:execution) { is_expected.to insert(migration).into_schema }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "when a procedure existed" do
    before do
      run_migration <<~RUBY
        create_procedure "set_foo", body: "SET custom.foo = 42"
      RUBY
    end

    context "without replace_existing: true" do
      let(:migration) do
        <<~RUBY
          create_procedure "set_foo", body: "SET custom.foo = 666"
        RUBY
      end

      its(:execution) { is_expected.to raise_error(StandardError) }
    end

    context "with replace_existing: true" do
      let(:migration) do
        <<~RUBY
          create_procedure "set_foo",
                           body: "SET custom.foo = 666",
                           replace_existing: true
        RUBY
      end
      let(:old_snippet) do
        <<~RUBY
          create_procedure "set_foo()" do |p|
            p.body "SET custom.foo = 42"
          end
        RUBY
      end
      let(:new_snippet) do
        <<~RUBY
          create_procedure "set_foo()" do |p|
            p.body "SET custom.foo = 666"
          end
        RUBY
      end

      its(:execution) { is_expected.to remove(old_snippet).from_schema }
      its(:execution) { is_expected.to insert(new_snippet).into_schema }
      it { is_expected.to be_irreversible.because_of(/replace_existing: true/i) }
    end
  end

  context "when a procedure contains SQL injection" do
    # Running it would inject the SQL code going after $$
    let(:migration) do
      <<~RUBY
        create_procedure "set_foo(a integer)" do |p|
          p.body <<~Q.chomp
            SET custom.foo = a$$;DROP TABLE priceless;
          Q
        end
      RUBY
    end

    it { is_expected.to fail_validation.because_of(/SQL injection/i) }
  end

  context "when a procedure has named $-quotations" do
    # This code is safe because `$greeting$` doesn't closes `$$`
    let(:migration) do
      <<~RUBY
        create_procedure "greet()" do |p|
          p.body "SET custom.foo = $greeting$Hi$greeting$;"
        end
      RUBY
    end

    its(:execution) { is_expected.to insert(migration).into_schema }
  end

  context "without arguments" do
    let(:migration) do
      <<~RUBY
        create_procedure "set_foo", body: "SET custom.foo = 42"
      RUBY
    end
    let(:snippet) do
      <<~RUBY
        create_procedure "set_foo()" do |p|
          p.body "SET custom.foo = 42"
        end
      RUBY
    end

    its(:execution) { is_expected.to insert(snippet).into_schema }
  end

  context "without name" do
    let(:migration) do
      <<~RUBY
        create_procedure body: "SET custom.foo = 42;"
      RUBY
    end

    it { is_expected.to fail_validation.because(/name can't be blank/i) }
  end

  context "without body" do
    let(:migration) do
      <<~RUBY
        create_procedure "foo ()"
      RUBY
    end

    it { is_expected.to fail_validation.because(/body can't be blank/i) }
  end
end
