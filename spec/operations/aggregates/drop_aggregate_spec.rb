# frozen_string_literal: true

describe ActiveRecord::Migration, "#drop_aggregate" do
  before do
    run_migration <<~RUBY
      create_function "taxi_accum(init numeric, km numeric, tax numeric) numeric" do |f|
        f.body "SELECT init + km * tax;"
        f.strict true
      end

      create_function "taxi_final(numeric) numeric" do |f|
        f.body "SELECT round($1 + 5, -1);"
        f.strict true
      end

      create_aggregate "agg_taxi(numeric, numeric)" do |a|
        a.state_function "taxi_accum" do |f|
          f.initial 3.5
          f.type "numeric"
          f.final "taxi_final"
        end
      end
    RUBY
  end

  context "with the name only" do
    let(:migration) do
      <<~RUBY
        drop_aggregate "agg_taxi(numeric, numeric)"
      RUBY
    end
    let(:snippet) do
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

    its(:execution) { is_expected.to remove(snippet).from_schema }
    it { is_expected.to be_irreversible.because(/can't be blank/i) }
  end

  context "with a full definition" do
    let(:migration) do
      <<~RUBY
        drop_aggregate "agg_taxi(numeric, numeric)" do |a|
          a.state_function "taxi_accum" do |f|
            f.initial 3.5
            f.type "numeric"
            f.final "taxi_final"
          end
        end
      RUBY
    end
    let(:snippet) do
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

    its(:execution) { is_expected.to remove(snippet).from_schema }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "when the aggregate was used" do
    before do
      run_migration <<~RUBY
        create_table "data" do |t|
          t.integer :car_id
          t.numeric :km
          t.numeric :tax
        end

        create_view "taxi_sum" do |v|
          v.sql_definition <<~SQL
            SELECT car_id, agg_taxi(km, tax)
            FROM data
            GROUP BY car_id
          SQL
        end
      RUBY
    end

    context "without the `force` option" do
      let(:migration) do
        <<~RUBY
          drop_aggregate "agg_taxi(numeric, numeric)"
        RUBY
      end

      its(:execution) { is_expected.to raise_error(StandardError) }
    end

    context "with the `force: :cascade` option" do
      let(:migration) do
        <<~RUBY
          drop_aggregate "agg_taxi(numeric, numeric)", force: :cascade
        RUBY
      end

      its(:execution) { is_expected.not_to raise_error }
      it { is_expected.to be_irreversible.because_of(/force: :cascade/i) }
    end
  end

  context "when the aggregate was absent" do
    context "without the `if_exists` option" do
      let(:migration) do
        <<~RUBY
          drop_aggregate "unknown(text, text)"
        RUBY
      end

      its(:execution) { is_expected.to raise_error(StandardError) }
    end

    context "with the `if_exists: true` option" do
      let(:migration) do
        <<~RUBY
          drop_aggregate "unknown(text, text)", if_exists: true
        RUBY
      end

      its(:execution) { is_expected.not_to change_schema }
      it { is_expected.to be_irreversible.because_of(/if_exists: true/i) }
    end
  end
end
