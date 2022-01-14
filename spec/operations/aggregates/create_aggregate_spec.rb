# frozen_string_literal: true

describe ActiveRecord::Migration, "#create_aggregate" do
  before do
    run_migration <<~RUBY
      create_function "taxi_accum(init numeric, km numeric, tax numeric) numeric" do |f|
        f.body "SELECT init + km * tax;"
        f.strict true
      end

      create_function "taxi_inv(init numeric, km numeric, tax numeric) numeric" do |f|
        f.body "SELECT init - km * tax;"
        f.strict true
      end

      create_function "taxi_final(numeric) numeric" do |f|
        f.body "SELECT round($1 + 5, -1);"
        f.strict true
      end
    RUBY
  end

  context "with a minimal set of params" do
    let(:migration) do
      <<~RUBY
        create_aggregate "agg_taxi(numeric, numeric)" do |a|
          a.state_function "taxi_accum" do |f|
            f.type "numeric"
            f.final "taxi_final"
          end
        end
      RUBY
    end

    its(:execution) { is_expected.to insert(migration).into_schema }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "with options for moving aggregate" do
    let(:migration) do
      <<~RUBY
        create_aggregate "agg_taxi(a numeric, b numeric)" do |a|
          a.state_function "taxi_accum" do |f|
            f.type "numeric"
            f.final "taxi_final"
          end
          a.moving_state_function "taxi_accum" do |f|
            f.type "numeric"
            f.final "taxi_final"
            f.inverse "taxi_inv"
          end
          a.parallel :safe
        end
      RUBY
    end

    its(:execution) { is_expected.to insert(migration).into_schema }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "without a state function" do
    let(:migration) do
      <<~RUBY
        create_aggregate "agg_taxi(numeric, numeric)"
      RUBY
    end

    it { is_expected.to fail_validation.because(/stype can't be blank/i) }
  end
end
