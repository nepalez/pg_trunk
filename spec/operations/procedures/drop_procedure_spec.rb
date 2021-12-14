# frozen_string_literal: true

describe ActiveRecord::Migration, "#drop_procedure", since_version: 11 do
  context "when a procedure was present" do
    before { run_migration(snippet) }

    let(:snippet) do
      <<~RUBY
        create_procedure "set_foo(a integer)" do |p|
          p.body "SET custom.foo = a"
        end
      RUBY
    end
    let(:query) { "CALL set_foo(42);" }

    context "with a procedure name only" do
      let(:migration) do
        <<~RUBY
          drop_procedure "set_foo"
        RUBY
      end

      its(:execution) { is_expected.to disable_sql_request(query) }
      its(:execution) { is_expected.to remove(snippet).from_schema }

      it { is_expected.to be_irreversible.because(/body can't be blank/i) }
    end

    context "with a procedure signature" do
      let(:migration) do
        <<~RUBY
          drop_procedure "set_foo(int)"
        RUBY
      end

      its(:execution) { is_expected.to disable_sql_request(query) }
      its(:execution) { is_expected.to remove(snippet).from_schema }

      it { is_expected.to be_irreversible.because(/body can't be blank/i) }
    end

    context "with a procedure body" do
      let(:migration) do
        <<~RUBY
          drop_procedure "set_foo(a int)", body: "SET custom.foo = a"
        RUBY
      end

      its(:execution) { is_expected.to disable_sql_request(query) }
      its(:execution) { is_expected.to remove(snippet).from_schema }

      its(:inversion) { is_expected.not_to change_schema }
    end

    context "with additional options" do
      let(:migration) do
        <<~RUBY
          drop_procedure "set_foo(a integer)" do |p|
            p.language "plpgsql"
            p.body "BEGIN SET custom.foo = a; END;"
            p.comment "Multiply 2 integers"
          end
        RUBY
      end
      let(:old_snippet) do
        <<~RUBY.indent(2)
          create_procedure "set_foo(a integer)" do |p|
            p.body "SET custom.foo = a"
          end
        RUBY
      end
      let(:new_snippet) do
        <<~RUBY.indent(2)
          create_procedure "set_foo(a integer)" do |p|
            p.language "plpgsql"
            p.body "BEGIN SET custom.foo = a; END;"
            p.comment "Multiply 2 integers"
          end
        RUBY
      end

      its(:execution) { is_expected.to disable_sql_request(query) }
      its(:execution) { is_expected.to remove(snippet).from_schema }

      its(:inversion) { is_expected.to enable_sql_request(query) }
      its(:inversion) { is_expected.to remove(old_snippet).from_schema }
      its(:inversion) { is_expected.to insert(new_snippet).into_schema }
    end

    context "without a name" do
      let(:migration) do
        <<~RUBY
          drop_procedure
        RUBY
      end

      it { is_expected.to fail_validation.because(/name can't be blank/i) }
    end
  end

  context "when several procedures existed" do
    before do
      run_migration <<~RUBY
        create_procedure "set_foo(a text)", body: "SET custom.foo = a"
        create_procedure "set_foo(a integer)", body: "SET custom.foo = a"
      RUBY
    end

    context "with a name only" do
      let(:migration) do
        <<~RUBY
          drop_procedure "set_foo"
        RUBY
      end

      its(:execution) { is_expected.to raise_exception(StandardError) }
    end

    context "with a signature" do
      let(:migration) do
        <<~RUBY
          drop_procedure "set_foo(text)"
        RUBY
      end
      let(:snippet) do
        <<~RUBY
          create_procedure "set_foo(a text)" do |p|
            p.body "SET custom.foo = a"
          end
        RUBY
      end

      its(:execution) { is_expected.to remove(snippet).from_schema }
    end
  end

  context "when a procedure was absent" do
    context "without the :if_exists option" do
      let(:migration) do
        <<~RUBY
          drop_procedure "set_foo"
        RUBY
      end

      its(:execution) { is_expected.to raise_error(StandardError) }
    end

    context "with the if_exists: true option" do
      let(:migration) do
        <<~RUBY
          drop_procedure "set_foo", if_exists: true
        RUBY
      end

      its(:execution) { is_expected.not_to raise_error }
      it { is_expected.to be_irreversible.because_of(/if_exists: true/i) }
    end
  end
end
