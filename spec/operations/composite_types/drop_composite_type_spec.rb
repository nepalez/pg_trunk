# frozen_string_literal: true

describe ActiveRecord::Migration, "#drop_composite_type" do
  before_all { run_migration "create_schema :paint" }
  before { run_migration(snippet) }

  let(:snippet) do
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

  context "with a full definition" do
    let(:migration) do
      <<~RUBY
        drop_composite_type "paint.colored_point" do |t|
          t.column "x", "integer"
          t.column "y", "integer"
          t.column "color", "text", collation: "en_US"
          t.comment "2D point with a color"
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
        drop_composite_type "paint.colored_point"
      RUBY
    end
    let(:new_snippet) do
      <<~RUBY
        create_composite_type "paint.colored_point"
      RUBY
    end

    its(:execution) { is_expected.to disable_sql_request(query) }
    its(:execution) { is_expected.to remove(snippet).from_schema }

    its(:inversion) { is_expected.to remove(snippet).from_schema }
    its(:inversion) { is_expected.to insert(new_snippet).into_schema }
  end

  context "when the type is used" do
    before do
      run_migration <<~RUBY
        # The function depends on the composite type
        create_function "make_red(p paint.colored_point) paint.colored_point",
                        body: "SELECT (p.x, p.y, 'red')::paint.colored_point"
      RUBY
    end

    context "without the `force` option" do
      let(:migration) do
        <<~RUBY
          drop_composite_type "paint.colored_point"
        RUBY
      end

      its(:execution) { is_expected.to raise_error(StandardError) }
    end

    context "with the `force: :cascade` option" do
      let(:migration) do
        <<~RUBY
          drop_composite_type "paint.colored_point", force: :cascade
        RUBY
      end

      its(:execution) { is_expected.to disable_sql_request(query) }
      its(:execution) { is_expected.to remove(snippet).from_schema }
      it { is_expected.to be_irreversible.because_of(/force: :cascade/i) }
    end
  end

  context "when the type is absent without the `if_exists` option" do
    let(:migration) do
      <<~RUBY
        drop_composite_type "foo"
      RUBY
    end

    its(:execution) { is_expected.to raise_error(StandardError) }
  end

  context "when the type is absent with the `if_exists: true` option" do
    let(:migration) do
      <<~RUBY
        drop_composite_type "foo", if_exists: true
      RUBY
    end

    its(:execution) { is_expected.not_to change_schema }
    it { is_expected.to be_irreversible.because_of(/if_exists: true/i) }
  end
end
