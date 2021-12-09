# frozen_string_literal: true

describe ActiveRecord::Migration, "#rename_enum" do
  before_all { run_migration "create_schema :finances" }
  before { run_migration(old_snippet) }

  let(:old_snippet) do
    <<~RUBY
      create_enum "currency" do |e|
        e.values "CHF", "EUR", "GBP", "USD", "JPY"
        e.comment "Supported currencies"
      end
    RUBY
  end
  let(:old_query) { "SELECT 'USD'::currency;" }

  context "with new name and schema" do
    let(:migration) do
      <<~RUBY
        rename_enum "currency", to: "finances.currency_value"
      RUBY
    end
    let(:new_snippet) do
      <<~RUBY
        create_enum "finances.currency_value" do |e|
          e.values "CHF", "EUR", "GBP", "USD", "JPY"
          e.comment "Supported currencies"
        end
      RUBY
    end
    let(:new_query) { "SELECT 'USD'::finances.currency_value;" }

    its(:execution) { is_expected.to enable_sql_request(new_query) }
    its(:execution) { is_expected.to disable_sql_request(old_query) }
    its(:execution) { is_expected.to remove(old_snippet).from_schema }
    its(:execution) { is_expected.to insert(new_snippet).into_schema }

    its(:inversion) { is_expected.to disable_sql_request(new_query) }
    its(:inversion) { is_expected.to enable_sql_request(old_query) }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "with the same name and schema" do
    let(:migration) do
      <<~RUBY
        rename_enum "currency", to: "public.currency"
      RUBY
    end

    it { is_expected.to fail_validation.because(/new name must be different/i) }
  end

  context "without new schema/name" do
    let(:migration) do
      <<~RUBY
        rename_enum "currency"
      RUBY
    end

    it { is_expected.to fail_validation.because(/new name can't be blank/i) }
  end

  context "without current name" do
    let(:migration) do
      <<~RUBY
        rename_enum to: "finances.currency_value"
      RUBY
    end

    it { is_expected.to fail_validation.because(/name can't be blank/i) }
  end
end
