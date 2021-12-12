# frozen_string_literal: true

describe ActiveRecord::Migration, "#rename_function" do
  before do
    run_migration <<~RUBY
      create_schema :math
    RUBY

    run_migration(old_snippet)
  end

  let(:new_snippet) do
    <<~RUBY
      create_function "math.multiply(a integer, b integer) integer" do |f|
        f.body "SELECT a * b"
      end
    RUBY
  end
  let(:old_snippet) do
    <<~RUBY
      create_function "mult(a integer, b integer) integer" do |f|
        f.body "SELECT a * b"
      end
    RUBY
  end
  let(:old_query) { "SELECT mult(7, 6);" }
  let(:new_query) { "SELECT math.multiply(7, 6);" }

  context "with new name and schema" do
    let(:migration) do
      <<~RUBY
        rename_function "mult", to: "math.multiply"
      RUBY
    end

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
        rename_function "mult", to: "public.mult"
      RUBY
    end

    it { is_expected.to fail_validation.because(/new name must be different/i) }
  end

  context "when several functions exist" do
    before do
      run_migration <<~RUBY
        create_function "mult(a integer, b integer, c integer) integer",
                        body: "SELECT a * b * c"
      RUBY
    end

    context "without a signature" do
      let(:migration) do
        <<~RUBY
          rename_function "mult", to: "math.multiply"
        RUBY
      end

      its(:execution) { is_expected.to raise_error(StandardError) }
    end

    context "with a signature" do
      let(:migration) do
        <<~RUBY
          rename_function "mult(int, integer)", to: "math.multiply"
        RUBY
      end

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
        rename_function to: "math.mult"
      RUBY
    end

    it { is_expected.to fail_validation.because(/name can't be blank/i) }
  end
end
