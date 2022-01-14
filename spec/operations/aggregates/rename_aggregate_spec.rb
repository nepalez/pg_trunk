# frozen_string_literal: true

describe ActiveRecord::Migration, "#rename_aggregate" do
  before do
    run_migration <<~RUBY
      create_schema "taxi"

      create_function "taxi_accum(init numeric, km numeric, tax numeric) numeric" do |f|
        f.body "SELECT init + km * tax;"
        f.strict true
      end

      create_function "taxi_final(numeric) numeric" do |f|
        f.body "SELECT round($1 + 5, -1);"
        f.strict true
      end
    RUBY

    run_migration(old_snippet)
  end

  let(:old_snippet) do
    <<~RUBY
      create_aggregate "agg_taxi(numeric, numeric)" do |a|
        a.state_function "taxi_accum" do |f|
          f.type "numeric"
          f.initial "3.5"
          f.final "taxi_final"
        end
      end
    RUBY
  end

  context "with new name and schema" do
    let(:migration) do
      <<~RUBY
        rename_aggregate "agg_taxi(numeric, numeric)", to: "taxi.agg"
      RUBY
    end
    let(:new_snippet) do
      <<~RUBY
        create_aggregate "taxi.agg(numeric, numeric)" do |a|
          a.state_function "taxi_accum" do |f|
            f.type "numeric"
            f.initial "3.5"
            f.final "taxi_final"
          end
        end
      RUBY
    end

    its(:execution) { is_expected.to insert(new_snippet).into_schema }
    its(:execution) { is_expected.to remove(old_snippet).from_schema }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "with the same name and schema" do
    let(:migration) do
      <<~RUBY
        rename_aggregate "agg_taxi(numeric, numeric)", to: "public.agg_taxi"
      RUBY
    end

    it { is_expected.to fail_validation.because(/name or the schema must be changed/i) }
  end

  context "without a signature" do
    let(:migration) do
      <<~RUBY
        rename_aggregate "agg_taxi", to: "taxi.agg"
      RUBY
    end

    its(:execution) { is_expected.to raise_error(StandardError) }
  end
end
