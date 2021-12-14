# frozen_string_literal: true

describe ActiveRecord::Migration, "#rename_procedure", since_version: 11 do
  before do
    run_migration <<~RUBY
      create_schema "meta"
      create_procedure "set_foo(a int)", body: "SET custom.foo = a"
    RUBY
  end

  let(:old_query) { "CALL set_foo(42);" }
  let(:old_snippet) do
    <<~RUBY
      create_procedure "set_foo(a integer)" do |p|
        p.body "SET custom.foo = a"
      end
    RUBY
  end

  context "with new name and schema" do
    let(:migration) do
      <<~RUBY
        rename_procedure "set_foo", to: "meta.set_foo_value"
      RUBY
    end
    let(:new_snippet) do
      <<~RUBY
        create_procedure "meta.set_foo_value(a integer)" do |p|
          p.body "SET custom.foo = a"
        end
      RUBY
    end
    let(:new_query) { "CALL meta.set_foo_value(42);" }

    its(:execution) { is_expected.to enable_sql_request(new_query) }
    its(:execution) { is_expected.to disable_sql_request(old_query) }
    its(:execution) { is_expected.to insert(new_snippet).into_schema }
    its(:execution) { is_expected.to remove(old_snippet).from_schema }

    its(:inversion) { is_expected.to disable_sql_request(new_query) }
    its(:inversion) { is_expected.to enable_sql_request(old_query) }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "with the same name and schema" do
    let(:migration) do
      <<~RUBY
        rename_procedure "set_foo", to: "public.set_foo"
      RUBY
    end

    it { is_expected.to fail_validation.because(/new name must be different/i) }
  end

  context "when several procedures exist" do
    before do
      run_migration <<~RUBY
        create_procedure "set_foo(a text)", body: "SET custom.foo = a"
      RUBY
    end

    context "without a signature" do
      let(:migration) do
        <<~RUBY
          rename_procedure "set_foo", to: "set_foo_value"
        RUBY
      end

      its(:execution) { is_expected.to raise_error(StandardError) }
    end

    context "with a signature" do
      let(:migration) do
        <<~RUBY
          rename_procedure "set_foo(int)", to: "meta.set_foo_value"
        RUBY
      end
      let(:new_snippet) do
        <<~RUBY
          create_procedure "meta.set_foo_value(a integer)" do |p|
            p.body "SET custom.foo = a"
          end
        RUBY
      end
      let(:new_query) { "CALL meta.set_foo_value(42);" }

      its(:execution) { is_expected.to enable_sql_request(new_query) }
      its(:execution) { is_expected.to disable_sql_request(old_query) }
      its(:execution) { is_expected.to insert(new_snippet).into_schema }
      its(:execution) { is_expected.to remove(old_snippet).from_schema }

      its(:inversion) { is_expected.to disable_sql_request(new_query) }
      its(:inversion) { is_expected.to enable_sql_request(old_query) }
      its(:inversion) { is_expected.not_to change_schema }
    end
  end

  context "without a name" do
    let(:migration) do
      <<~RUBY
        rename_procedure to: "meta.set_foo"
      RUBY
    end

    it { is_expected.to fail_validation.because(/name can't be blank/i) }
  end
end
