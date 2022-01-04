# frozen_string_literal: true

describe ActiveRecord::Migration, "#drop_domain" do
  before_all { run_migration "create_schema :dict" }
  before { run_migration(snippet) }

  let(:snippet) do
    <<~RUBY
      create_domain "dict.us_postal_code", as: "text" do |d|
        d.collation "en_US"
        d.default_sql "'00000'::text"
        d.null false
        d.constraint %q(VALUE ~ '^\\d{5}(-\\d{4})?$'::text), name: "valid_code"
        d.comment "US postal code"
      end
    RUBY
  end
  let(:query) { "SELECT '00000-0000'::dict.us_postal_code;" }

  context "with a full definition" do
    let(:migration) do
      <<~RUBY
        drop_domain "dict.us_postal_code", as: "text" do |d|
          d.collation "en_US"
          d.default_sql "'00000'::text"
          d.constraint %q(VALUE ~ '^\\d{5}(-\\d{4})?$'::text), name: "valid_code"
          d.null false
          d.comment "US postal code"
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
        drop_domain "dict.us_postal_code"
      RUBY
    end

    its(:execution) { is_expected.to disable_sql_request(query) }
    its(:execution) { is_expected.to remove(snippet).from_schema }
    it { is_expected.to be_irreversible.because(/type can't be blank/i) }
  end

  context "when domain is used" do
    before do
      run_migration <<~RUBY
        execute <<~Q
          CREATE TABLE sums (value integer, zip dict.us_postal_code);
        Q
      RUBY
    end

    context "without the `force` option" do
      let(:migration) do
        <<~RUBY
          drop_domain "dict.us_postal_code"
        RUBY
      end

      its(:execution) { is_expected.to raise_error(StandardError) }
    end

    context "with the `force: :cascade` option" do
      let(:migration) do
        <<~RUBY
          drop_domain "dict.us_postal_code", force: :cascade
        RUBY
      end

      its(:execution) { is_expected.to disable_sql_request(query) }
      its(:execution) { is_expected.to remove(snippet).from_schema }
      it { is_expected.to be_irreversible.because_of(/force: :cascade/i) }
    end
  end

  context "when domain is absent without `if_exists` option" do
    let(:migration) do
      <<~RUBY
        drop_domain "foo"
      RUBY
    end

    its(:execution) { is_expected.to raise_error(StandardError) }
  end

  context "when domain is absent with `if_exists: true` option" do
    let(:migration) do
      <<~RUBY
        drop_domain "foo", if_exists: true
      RUBY
    end

    its(:execution) { is_expected.not_to change_schema }
    it { is_expected.to be_irreversible.because_of(/if_exists: true/i) }
  end

  context "without a name" do
    let(:migration) do
      <<~RUBY
        drop_domain as: "text" do |d|
          d.collation "en_US"
          d.default_sql "'00000'::text"
          d.constraint %q(VALUE ~ '^\d{5}$' OR VALUE ~ '^\d{5}-\d{4}$'), name: "valid_code"
          d.null false
          d.comment "US postal code"
        end
      RUBY
    end

    it { is_expected.to fail_validation.because(/name can't be blank/i) }
  end
end
