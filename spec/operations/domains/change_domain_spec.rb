# frozen_string_literal: true

describe ActiveRecord::Migration, "#change_domain" do
  before_all { run_migration "create_schema :dict" }
  before { run_migration(old_snippet) }

  let(:old_snippet) do
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

  context "when not null constraint is changed" do
    let(:migration) do
      <<~RUBY
        change_domain "dict.us_postal_code" do |d|
          d.null true
        end
      RUBY
    end
    let(:new_snippet) do
      <<~RUBY
        create_domain "dict.us_postal_code", as: "text" do |d|
          d.collation "en_US"
          d.default_sql "'00000'::text"
          d.constraint %q(VALUE ~ '^\\d{5}(-\\d{4})?$'::text), name: "valid_code"
          d.comment "US postal code"
        end
      RUBY
    end
    let(:query) { "SELECT NULL::dict.us_postal_code;" }

    its(:execution) { is_expected.to enable_sql_request(query) }
    its(:execution) { is_expected.to remove(old_snippet).from_schema }
    its(:execution) { is_expected.to insert(new_snippet).into_schema }

    its(:inversion) { is_expected.to disable_sql_request(query) }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "when new constraint is added" do
    let(:migration) do
      <<~RUBY
        change_domain "dict.us_postal_code" do |d|
          d.add_constraint %q(VALUE ~ '^\\d{5}$'::text), name: "new_check"
        end
      RUBY
    end
    let(:new_snippet) do
      <<~RUBY
        create_domain "dict.us_postal_code", as: "text" do |d|
          d.collation "en_US"
          d.default_sql "'00000'::text"
          d.null false
          d.constraint %q(VALUE ~ '^\\d{5}$'::text), name: "new_check"
          d.constraint %q(VALUE ~ '^\\d{5}(-\\d{4})?$'::text), name: "valid_code"
          d.comment "US postal code"
        end
      RUBY
    end
    let(:query) { "SELECT '00000-0000'::dict.us_postal_code;" }

    its(:execution) { is_expected.to disable_sql_request(query) }
    its(:execution) { is_expected.to remove(old_snippet).from_schema }
    its(:execution) { is_expected.to insert(new_snippet).into_schema }

    its(:inversion) { is_expected.to enable_sql_request(query) }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "when existing constraint is dropped with :check option" do
    let(:migration) do
      <<~RUBY
        change_domain "dict.us_postal_code" do |d|
          d.drop_constraint "valid_code", check: %q(VALUE ~ '^\\d{5}(-\\d{4})?$'::text)
        end
      RUBY
    end
    let(:new_snippet) do
      <<~RUBY
        create_domain "dict.us_postal_code", as: "text" do |d|
          d.collation "en_US"
          d.default_sql "'00000'::text"
          d.null false
          d.comment "US postal code"
        end
      RUBY
    end
    let(:query) { "SELECT 'foobar'::dict.us_postal_code;" }

    its(:execution) { is_expected.to enable_sql_request(query) }
    its(:execution) { is_expected.to remove(old_snippet).from_schema }
    its(:execution) { is_expected.to insert(new_snippet).into_schema }

    its(:inversion) { is_expected.to disable_sql_request(query) }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "with `force: :cascade` option" do
    let(:migration) do
      <<~RUBY
        change_domain "dict.us_postal_code", force: :cascade do |d|
          d.drop_constraint "valid_code", check: %q(VALUE ~ '^\\d{5}(-\\d{4})?$'::text)
        end
      RUBY
    end
    let(:new_snippet) do
      <<~RUBY
        create_domain "dict.us_postal_code", as: "text" do |d|
          d.collation "en_US"
          d.default_sql "'00000'::text"
          d.null false
          d.comment "US postal code"
        end
      RUBY
    end
    let(:query) { "SELECT '00000-0000'::dict.us_postal_code;" }

    its(:execution) { is_expected.to enable_sql_request(query) }
    its(:execution) { is_expected.to remove(old_snippet).from_schema }
    its(:execution) { is_expected.to insert(new_snippet).into_schema }
    it { is_expected.to be_irreversible.because_of(/force: :cascade/i) }
  end

  context "when existing constraint is dropped without :check option" do
    let(:migration) do
      <<~RUBY
        change_domain "dict.us_postal_code" do |d|
          d.drop_constraint "valid_code"
        end
      RUBY
    end
    let(:new_snippet) do
      <<~RUBY
        create_domain "dict.us_postal_code", as: "text" do |d|
          d.collation "en_US"
          d.default_sql "'00000'::text"
          d.null false
          d.comment "US postal code"
        end
      RUBY
    end
    let(:query) { "SELECT '00000-0000'::us_postal_code;" }

    its(:execution) { is_expected.to disable_sql_request(query) }
    its(:execution) { is_expected.to remove(old_snippet).from_schema }
    its(:execution) { is_expected.to insert(new_snippet).into_schema }
    it { is_expected.to be_irreversible.because_of(/check/i) }
  end

  context "when absent constraint is dropped without :if_exists option" do
    let(:migration) do
      <<~RUBY
        change_domain "dict.us_postal_code" do |d|
          d.drop_constraint "foo"
        end
      RUBY
    end

    its(:execution) { is_expected.to raise_error(StandardError) }
  end

  context "when absent constraint is dropped with `if_exists: true` option" do
    let(:migration) do
      <<~RUBY
        change_domain "dict.us_postal_code" do |d|
          d.drop_constraint "foo", if_exists: true
        end
      RUBY
    end

    its(:execution) { is_expected.not_to change_schema }
    it { is_expected.to be_irreversible.because_of(/if_exists: true/i) }
  end

  context "when default_sql value is changed with :from option" do
    let(:migration) do
      <<~RUBY
        change_domain "dict.us_postal_code" do |d|
          d.default_sql "'11111-0000'", from: "'00000'"
        end
      RUBY
    end
    let(:new_snippet) do
      <<~RUBY
        create_domain "dict.us_postal_code", as: "text" do |d|
          d.collation "en_US"
          d.default_sql "'11111-0000'::text"
          d.null false
          d.constraint %q(VALUE ~ '^\\d{5}(-\\d{4})?$'::text), name: "valid_code"
          d.comment "US postal code"
        end
      RUBY
    end

    its(:execution) { is_expected.to remove(old_snippet).from_schema }
    its(:execution) { is_expected.to insert(new_snippet).into_schema }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "when default_sql value is changed without :from option" do
    let(:migration) do
      <<~RUBY
        change_domain "dict.us_postal_code" do |d|
          d.default_sql "'11111-0000'"
        end
      RUBY
    end
    let(:new_snippet) do
      <<~RUBY
        create_domain "dict.us_postal_code", as: "text" do |d|
          d.collation "en_US"
          d.default_sql "'11111-0000'::text"
          d.null false
          d.constraint %q(VALUE ~ '^\\d{5}(-\\d{4})?$'::text), name: "valid_code"
          d.comment "US postal code"
        end
      RUBY
    end

    its(:execution) { is_expected.to remove(old_snippet).from_schema }
    its(:execution) { is_expected.to insert(new_snippet).into_schema }
    it { is_expected.to be_irreversible.because_of(/default_sql/i) }
  end

  context "when comment is changed with :from option" do
    let(:migration) do
      <<~RUBY
        change_domain "dict.us_postal_code" do |d|
          d.comment "US postal code (zip)", from: "US postal code"
        end
      RUBY
    end
    let(:new_snippet) do
      <<~RUBY
        create_domain "dict.us_postal_code", as: "text" do |d|
          d.collation "en_US"
          d.default_sql "'00000'::text"
          d.null false
          d.constraint %q(VALUE ~ '^\\d{5}(-\\d{4})?$'::text), name: "valid_code"
          d.comment "US postal code (zip)"
        end
      RUBY
    end

    its(:execution) { is_expected.to remove(old_snippet).from_schema }
    its(:execution) { is_expected.to insert(new_snippet).into_schema }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "when comment is changed without :from option" do
    let(:migration) do
      <<~RUBY
        change_domain "dict.us_postal_code" do |d|
          d.comment "US postal code (zip)"
        end
      RUBY
    end
    let(:new_snippet) do
      <<~RUBY
        create_domain "dict.us_postal_code", as: "text" do |d|
          d.collation "en_US"
          d.default_sql "'00000'::text"
          d.null false
          d.constraint %q(VALUE ~ '^\\d{5}(-\\d{4})?$'::text), name: "valid_code"
          d.comment "US postal code (zip)"
        end
      RUBY
    end

    its(:execution) { is_expected.to remove(old_snippet).from_schema }
    its(:execution) { is_expected.to insert(new_snippet).into_schema }
    it { is_expected.to be_irreversible.because_of(/comment/i) }
  end

  context "without changes" do
    let(:migration) { 'change_domain "dict.us_postal_code"' }

    it { is_expected.to fail_validation.because(/there are no changes/i) }
  end
end
