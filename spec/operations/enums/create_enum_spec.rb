# frozen_string_literal: true

describe ActiveRecord::Migration, "#create_enum" do
  before_all { run_migration "create_schema :finances" }

  context "with a full definition" do
    let(:migration) do
      <<~RUBY
        create_enum "finances.currency" do |e|
          e.values "EUR", "USD"
          e.comment "Supported currency values"
        end
      RUBY
    end
    let(:query) { "SELECT 'EUR'::finances.currency;" }

    its(:execution) { is_expected.to enable_sql_request(query) }
    its(:execution) { is_expected.to insert(migration).into_schema }
    its(:inversion) { is_expected.to disable_sql_request(query) }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "without values" do
    let(:migration) { "create_enum :currency" }

    it { is_expected.to fail_validation.because(/values can't be blank/i) }
  end

  context "without name" do
    let(:migration) do
      <<~RUBY
        create_enum do |e|
          e.values "EUR", "USD"
        end
      RUBY
    end

    it { is_expected.to fail_validation.because(/name can't be blank/i) }
  end
end
