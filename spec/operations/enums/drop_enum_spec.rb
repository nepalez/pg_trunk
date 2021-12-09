# frozen_string_literal: true

describe ActiveRecord::Migration, "#drop_enum" do
  before_all { run_migration "create_schema :finances" }
  before { run_migration(snippet) }

  let(:snippet) do
    <<~RUBY
      create_enum "currency" do |e|
        e.values "CHF", "EUR", "GBP", "USD", "JPY"
        e.comment "Supported currencies"
      end
    RUBY
  end
  let(:query) { "SELECT 'USD'::currency;" }

  context "with a full definition" do
    let(:migration) do
      <<~RUBY
        drop_enum "currency" do |e|
          e.values "CHF", "EUR", "GBP", "USD"
          e.value "JPY"
          e.comment "Supported currencies"
        end
      RUBY
    end

    its(:execution) { is_expected.to disable_sql_request(query) }
    its(:execution) { is_expected.to remove(snippet).from_schema }
    its(:inversion) { is_expected.to enable_sql_request(query) }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "with a qualified name only" do
    let(:migration) do
      <<~RUBY
        drop_enum "currency"
      RUBY
    end

    its(:execution) { is_expected.to disable_sql_request(query) }
    its(:execution) { is_expected.to remove(snippet).from_schema }
    it { is_expected.to be_irreversible.because(/values can't be blank/i) }
  end

  context "when enum is used" do
    before do
      run_migration <<~RUBY
        execute "CREATE TABLE sums (value integer, label currency);"
      RUBY
    end

    context "without the `force` option" do
      let(:migration) do
        <<~RUBY
          drop_enum "currency" do |e|
            e.values "CHF", "EUR", "GBP", "USD"
            e.value "JPY"
            e.comment "Supported currencies"
          end
        RUBY
      end

      its(:execution) { is_expected.to raise_error(StandardError) }
    end

    context "with the `force: :cascade` option" do
      let(:migration) do
        <<~RUBY
          drop_enum "currency", force: :cascade do |e|
            e.values "CHF", "EUR", "GBP", "USD", "JPY"
            e.comment "Supported currencies"
          end
        RUBY
      end

      its(:execution) { is_expected.to disable_sql_request(query) }
      its(:execution) { is_expected.to remove(snippet).from_schema }
      it { is_expected.to be_irreversible.because_of(/force: :cascade/i) }
    end
  end

  context "when enum is absent" do
    context "without the `force` option" do
      let(:migration) do
        <<~RUBY
          drop_enum "foo"
        RUBY
      end

      its(:execution) { is_expected.to raise_error(StandardError) }
    end

    context "with the `if_exists: true` option" do
      let(:migration) do
        <<~RUBY
          drop_enum "foo", if_exists: true
        RUBY
      end

      its(:execution) { is_expected.to enable_sql_request(query) }
      its(:execution) { is_expected.not_to change_schema }
      it { is_expected.to be_irreversible.because_of(/if_exists: true/i) }
    end
  end

  context "without a name" do
    let(:migration) do
      <<~RUBY
        drop_enum do |e|
          e.values "CHF", "EUR", "GBP", "USD"
          e.value "JPY"
          e.comment "Supported currencies"
        end
      RUBY
    end

    it { is_expected.to fail_validation.because(/name can't be blank/i) }
  end
end
