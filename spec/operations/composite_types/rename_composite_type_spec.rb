# frozen_string_literal: true

describe ActiveRecord::Migration, "#rename_composite_type" do
  before_all { run_migration "create_schema :paint" }
  before { run_migration(old_snippet) }

  let(:old_snippet) do
    <<~RUBY
      create_composite_type "paint.colored_point" do |t|
        t.column "x", "integer"
        t.column "y", "integer"
        t.column "color", "text", collation: "en_US"
      end
    RUBY
  end
  let(:old_query) { "SELECT (1, 1, 'black')::paint.colored_point;" }

  context "with new name and schema" do
    let(:migration) do
      <<~RUBY
        rename_enum "paint.colored_point", to: "cpoint"
      RUBY
    end
    let(:new_snippet) do
      <<~RUBY
        create_composite_type "cpoint" do |t|
          t.column "x", "integer"
          t.column "y", "integer"
          t.column "color", "text", collation: "en_US"
        end
      RUBY
    end
    let(:new_query) { "SELECT (1, 1, 'black')::cpoint;" }

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
        rename_enum "paint.colored_point", to: "paint.colored_point"
      RUBY
    end

    it { is_expected.to fail_validation.because(/new name must be different/i) }
  end

  context "without new schema/name" do
    let(:migration) do
      <<~RUBY
        rename_composite_type "paint.colored_point"
      RUBY
    end

    it { is_expected.to fail_validation.because(/new name can't be blank/i) }
  end

  context "without name" do
    let(:migration) do
      <<~RUBY
        rename_composite_type to: "cpoint"
      RUBY
    end

    it { is_expected.to fail_validation.because(/name can't be blank/i) }
  end
end
