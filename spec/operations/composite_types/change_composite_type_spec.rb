# frozen_string_literal: true

# frozen_text_literal: true

describe ActiveRecord::Migration, "#change_composite_type" do
  before_all { run_migration "create_schema :paint" }
  before { run_migration(old_snippet) }

  let(:old_snippet) do
    <<~RUBY
      create_composite_type "paint.colored_point" do |t|
        t.column "x", "integer"
        t.column "y", "integer"
        t.column "color", "text", collation: "en_US"
        t.comment "2D point with a color"
      end
    RUBY
  end
  let(:old_query) { "SELECT (10, -1, 'blue')::paint.colored_point" }

  context "when new column is added" do
    let(:migration) do
      <<~RUBY
        change_composite_type "paint.colored_point" do |t|
          t.add_column "z", "integer"
        end
      RUBY
    end
    let(:new_snippet) do
      <<~RUBY
        create_composite_type "paint.colored_point" do |t|
          t.column "x", "integer"
          t.column "y", "integer"
          t.column "color", "text", collation: "en_US"
          t.column "z", "integer"
          t.comment "2D point with a color"
        end
      RUBY
    end
    let(:new_query) { "SELECT (10, -1, 'blue', 6)::paint.colored_point" }

    its(:execution) { is_expected.to enable_sql_request(new_query) }
    its(:execution) { is_expected.to disable_sql_request(old_query) }
    its(:execution) { is_expected.to insert(new_snippet).into_schema }
    its(:execution) { is_expected.to remove(old_snippet).from_schema }

    its(:inversion) { is_expected.to disable_sql_request(new_query) }
    its(:inversion) { is_expected.to enable_sql_request(old_query) }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "when the column is dropped" do
    let(:migration) do
      <<~RUBY
        change_composite_type "paint.colored_point" do |t|
          t.drop_column "color", "text", collation: "en_US"
        end
      RUBY
    end
    let(:new_snippet) do
      <<~RUBY
        create_composite_type "paint.colored_point" do |t|
          t.column "x", "integer"
          t.column "y", "integer"
          t.comment "2D point with a color"
        end
      RUBY
    end
    let(:new_query) { "SELECT (10, 11)::paint.colored_point" }

    its(:execution) { is_expected.to enable_sql_request(new_query) }
    its(:execution) { is_expected.to disable_sql_request(old_query) }
    its(:execution) { is_expected.to insert(new_snippet).into_schema }
    its(:execution) { is_expected.to remove(old_snippet).from_schema }

    it { is_expected.to be_irreversible.because_of(/y/i) }
  end

  context "when an absent column is dropped without :if_exists option" do
    let(:migration) do
      <<~RUBY
        change_composite_type "paint.colored_point" do |t|
          t.drop_column "f"
        end
      RUBY
    end

    its(:execution) { is_expected.to raise_error(StandardError) }
  end

  context "when an absent column is dropped with `if_exists: true` option" do
    let(:migration) do
      <<~RUBY
        change_composite_type "paint.colored_point" do |t|
          t.drop_column "f", if_exists: true
        end
      RUBY
    end

    its(:execution) { is_expected.not_to change_schema }
    it { is_expected.to be_irreversible.because_of(/if_exists: true/i) }
  end

  context "when columns are renamed" do
    let(:migration) do
      <<~RUBY
        change_composite_type "paint.colored_point" do |t|
          t.rename_column "y", to: "z"
        end
      RUBY
    end
    let(:new_snippet) do
      <<~RUBY
        create_composite_type "paint.colored_point" do |t|
          t.column "x", "integer"
          t.column "z", "integer"
          t.column "color", "text", collation: "en_US"
          t.comment "2D point with a color"
        end
      RUBY
    end

    its(:execution) { is_expected.to insert(new_snippet).into_schema }
    its(:execution) { is_expected.to remove(old_snippet).from_schema }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "when columns are changed with :from options" do
    let(:migration) do
      <<~RUBY
        change_composite_type "paint.colored_point" do |t|
          t.change_column "x", "bigint", from_type: "integer"
          t.change_column "y", "bigint", from_type: "integer"
          t.change_column "color", "text", collation: "POSIX", from_type: "text", from_collation: "en_US"
        end
      RUBY
    end
    let(:new_snippet) do
      <<~RUBY
        create_composite_type "paint.colored_point" do |t|
          t.column "x", "bigint"
          t.column "y", "bigint"
          t.column "color", "text", collation: "POSIX"
          t.comment "2D point with a color"
        end
      RUBY
    end

    its(:execution) { is_expected.to insert(new_snippet).into_schema }
    its(:execution) { is_expected.to remove(old_snippet).from_schema }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "when columns are changed without :from options" do
    let(:migration) do
      <<~RUBY
        change_composite_type "paint.colored_point" do |t|
          t.change_column "x", "bigint"
          t.change_column "y", "bigint"
          t.change_column "color", "text", collation: "POSIX"
        end
      RUBY
    end
    let(:new_snippet) do
      <<~RUBY
        create_composite_type "paint.colored_point" do |t|
          t.column "x", "bigint"
          t.column "y", "bigint"
          t.column "color", "text", collation: "POSIX"
          t.comment "2D point with a color"
        end
      RUBY
    end

    its(:execution) { is_expected.to insert(new_snippet).into_schema }
    its(:execution) { is_expected.to remove(old_snippet).from_schema }
    it { is_expected.to be_irreversible }
  end

  context "when column is changed with `force: :cascade` option" do
    let(:migration) do
      <<~RUBY
        change_composite_type "paint.colored_point", force: :cascade do |t|
          t.change_column "x", "bigint", from_type: "integer"
        end
      RUBY
    end
    let(:new_snippet) do
      <<~RUBY
        create_composite_type "paint.colored_point" do |t|
          t.column "x", "bigint"
          t.column "y", "integer"
          t.column "color", "text", collation: "en_US"
          t.comment "2D point with a color"
        end
      RUBY
    end

    its(:execution) { is_expected.to insert(new_snippet).into_schema }
    its(:execution) { is_expected.to remove(old_snippet).from_schema }
    it { is_expected.to be_irreversible.because_of(/force: :cascade/) }
  end

  context "when comment is changed with :from option" do
    let(:migration) do
      <<~RUBY
        change_composite_type "paint.colored_point" do |d|
          d.comment "Colored 2D point", from: "2D point with a color"
        end
      RUBY
    end
    let(:new_snippet) do
      <<~RUBY
        create_composite_type "paint.colored_point" do |t|
          t.column "x", "integer"
          t.column "y", "integer"
          t.column "color", "text", collation: "en_US"
          t.comment "Colored 2D point"
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
        change_composite_type "paint.colored_point" do |d|
          d.comment "Colored 2D point"
        end
      RUBY
    end
    let(:new_snippet) do
      <<~RUBY
        create_composite_type "paint.colored_point" do |t|
          t.column "x", "integer"
          t.column "y", "integer"
          t.column "color", "text", collation: "en_US"
          t.comment "Colored 2D point"
        end
      RUBY
    end

    its(:execution) { is_expected.to remove(old_snippet).from_schema }
    its(:execution) { is_expected.to insert(new_snippet).into_schema }
    it { is_expected.to be_irreversible.because_of(/comment/i) }
  end

  context "without changes" do
    let(:migration) { 'change_composite_type "dict.us_postal_code"' }

    it { is_expected.to fail_validation.because(/there are no changes/i) }
  end
end
