# frozen_string_literal: true

describe ActiveRecord::Migration, "#change_enum" do
  before_all { run_migration "create_schema :finances" }
  before { run_migration(old_snippet) }

  let(:old_snippet) do
    <<~RUBY
      create_enum "currency" do |e|
        e.values "eur", "usd"
        e.comment "Supported currencies"
      end
    RUBY
  end

  context "when values are renamed" do
    let(:migration) do
      <<~RUBY
        change_enum :currency do |e|
          e.rename_value "usd", to: "USD"
          e.rename_value "eur", to: "EUR"
        end
      RUBY
    end
    let(:new_snippet) do
      <<~RUBY
        create_enum "currency" do |e|
          e.values "EUR", "USD"
          e.comment "Supported currencies"
        end
      RUBY
    end
    let(:old_query) { "SELECT 'eur'::currency;" }
    let(:new_query) { "SELECT 'EUR'::currency;" }

    its(:execution) { is_expected.to disable_sql_request(old_query) }
    its(:execution) { is_expected.to enable_sql_request(new_query) }
    its(:execution) { is_expected.to remove(old_snippet).from_schema }
    its(:execution) { is_expected.to insert(new_snippet).into_schema }

    its(:inversion) { is_expected.to enable_sql_request(old_query) }
    its(:inversion) { is_expected.to disable_sql_request(new_query) }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "when values are added" do
    let(:migration) do
      <<~RUBY
        change_enum :currency do |e|
          e.add_value "jpy"
          e.add_value "cfr", before: "eur"
          e.add_value "gbp", after: "eur"
          e.add_value "btc", before: "cfr"
        end
      RUBY
    end
    let(:new_snippet) do
      <<~RUBY
        create_enum "currency" do |e|
          e.values "btc", "cfr", "eur", "gbp", "usd", "jpy"
          e.comment "Supported currencies"
        end
      RUBY
    end

    context "in PostgreSQL v11 and below", before_version: 12 do
      its(:execution) { is_expected.to raise_error(/supported in PostgreSQL v12+/i) }
    end

    context "in PostgreSQL v12+", since_version: 12 do
      its(:execution) { is_expected.to remove(old_snippet).from_schema }
      its(:execution) { is_expected.to insert(new_snippet).into_schema }
      it { is_expected.to be_irreversible.because_of(/adding new values/i) }
    end
  end

  context "when values both added and renamed", since_version: 12 do
    let(:migration) do
      <<~RUBY
        change_enum :currency do |e|
          e.rename_value "eur", to: "EUR"
          e.add_value "CFR", before: "eur"
          e.rename_value "usd", to: "USD"
        end
      RUBY
    end
    let(:new_snippet) do
      <<~RUBY
        create_enum "currency" do |e|
          e.values "CFR", "EUR", "USD"
          e.comment "Supported currencies"
        end
      RUBY
    end

    its(:execution) { is_expected.to remove(old_snippet).from_schema }
    its(:execution) { is_expected.to insert(new_snippet).into_schema }
    it { is_expected.to be_irreversible.because_of(/adding new values/i) }
  end

  context "when the comment is changed" do
    let(:new_snippet) do
      <<~RUBY
        create_enum "currency" do |e|
          e.values "eur", "usd"
          e.comment "Supported currency values"
        end
      RUBY
    end

    context "without the `from` option" do
      let(:migration) do
        <<~RUBY
          change_enum "currency" do |e|
            e.comment "Supported currency values"
          end
        RUBY
      end

      its(:execution) { is_expected.to remove(old_snippet).from_schema }
      its(:execution) { is_expected.to insert(new_snippet).into_schema }
      it { is_expected.to be_irreversible.because_of(/comment/i) }
    end

    context "with the `from` option" do
      let(:migration) do
        <<~RUBY
          change_enum "currency" do |e|
            e.comment "Supported currency values", from: "Supported currencies"
          end
        RUBY
      end

      its(:execution) { is_expected.to remove(old_snippet).from_schema }
      its(:execution) { is_expected.to insert(new_snippet).into_schema }
      its(:inversion) { is_expected.not_to change_schema }
    end
  end

  context "without any change" do
    let(:migration) { "change_enum :currencies" }

    it { is_expected.to fail_validation.because(/there are no changes/i) }
  end

  context "without a name" do
    let(:migration) do
      <<~RUBY
        change_enum do |e|
          e.rename_value "eur", to: "EUR"
        end
      RUBY
    end

    it { is_expected.to fail_validation.because(/name can't be blank/i) }
  end
end
