# frozen_string_literal: true

describe ActiveRecord::Migration, "#create_composite_type" do
  before_all { run_migration "create_schema :paint" }

  context "with a full definition" do
    let(:migration) do
      <<~RUBY
        create_composite_type "paint.colored_point" do |t|
          t.column "x", "integer"
          t.column "y", "integer"
          t.column "color", "text", collation: "en_US"
          t.comment "2D point with a color"
        end
      RUBY
    end
    let(:query) { "SELECT (10, -1, 'blue')::paint.colored_point" }

    its(:execution) { is_expected.to enable_sql_request(query) }
    its(:execution) { is_expected.to insert(migration).into_schema }
    its(:inversion) { is_expected.to disable_sql_request(query) }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "without columns" do
    let(:migration) do
      <<~RUBY
        create_composite_type "paint.nothing" do |t|
          t.comment "2D point with a color"
        end
      RUBY
    end
    let(:query) { "SELECT NULL::paint.nothing" }

    its(:execution) { is_expected.to enable_sql_request(query) }
    its(:execution) { is_expected.to insert(migration).into_schema }
    its(:inversion) { is_expected.to disable_sql_request(query) }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "without name" do
    let(:migration) do
      <<~RUBY
        create_composite_type do |t|
          t.column "x", "integer"
          t.column "y", "integer"
          t.column "color", "text", collation: "en_US"
          t.comment "2D point with a color"
        end
      RUBY
    end

    it { is_expected.to fail_validation.because(/name can't be blank/i) }
  end
end
