# frozen_string_literal: true

describe ActiveRecord::Migration, "#create_domain" do
  before_all { run_migration "create_schema :dict" }

  context "with a full definition" do
    let(:migration) do
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
    let(:query) { "SELECT '12345'::dict.us_postal_code;" }

    its(:execution) { is_expected.to enable_sql_request(query) }
    its(:execution) { is_expected.to insert(migration).into_schema }
    its(:inversion) { is_expected.to disable_sql_request(query) }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "without type" do
    let(:migration) do
      <<~RUBY
        create_domain "dict.us_postal_code" do |d|
          d.collation "en_US"
          d.default_sql <<~Q
            '00000'::text
          Q
          d.null false
          d.constraint <<~Q, name: "valid_code"
            VALUE ~ '^\d{5}$'::text OR VALUE ~ '^\d{5}-\d{4}$'::text
          Q
          d.comment <<~COMMENT
            US postal code
          COMMENT
        end
      RUBY
    end

    it { is_expected.to fail_validation.because(/type can't be blank/i) }
  end

  context "without name" do
    let(:migration) do
      <<~RUBY
        create_domain as: "text" do |d|
          d.collation "en_US"
          d.default_sql <<~Q
            '00000'::text
          Q
          d.null false
          d.constraint <<~Q, name: "valid_code"
            VALUE ~ '^\d{5}$'::text OR VALUE ~ '^\d{5}-\d{4}$'::text
          Q
          d.comment <<~COMMENT
            US postal code
          COMMENT
        end
      RUBY
    end

    it { is_expected.to fail_validation.because(/name can't be blank/i) }
  end
end
