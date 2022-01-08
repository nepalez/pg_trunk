# frozen_string_literal: true

# There is a couple tests just to check the order of objects creation
# in the resulting database schema.
describe ActiveRecord::Migration do
  context "with a table -> function -> check_constraint dependency" do
    let(:migration) do
      <<~RUBY
        create_table "users", force: :cascade do |t|
          t.string "first_name"
          t.string "last_name"
        end

        create_function "full_name(u users) text" do |f|
          f.volatility :immutable
          f.strict true
          f.parallel :safe
          f.body <<~Q.chomp
            SELECT (
            CASE WHEN u.first_name IS NULL THEN '' ELSE u.first_name || ' ' END
            ) || COALESCE(u.last_name, '')
          Q
        end

        add_check_constraint "users", "length(users.full_name) > 0"

        # no dependencies here, that's why the table must be moved up
        # before users (in alphabetical order)
        create_table "colors" do |t|
          t.string "name"
          t.string "code"
        end
      RUBY
    end
    let(:snippet) do
      <<~RUBY
        create_table "colors", force: :cascade do |t|
          t.string "name"
          t.string "code"
        end

        create_table "users", force: :cascade do |t|
          t.string "first_name"
          t.string "last_name"
        end

        create_function "full_name(u users) text" do |f|
          f.volatility :immutable
          f.strict true
          f.parallel :safe
          f.body <<~Q.chomp
            SELECT (
            CASE WHEN u.first_name IS NULL THEN '' ELSE u.first_name || ' ' END
            ) || COALESCE(u.last_name, '')
          Q
        end

        add_check_constraint "users", "length(full_name(users.*)) > 0"
      RUBY
    end

    its(:execution) { is_expected.to insert(snippet).into_schema }
  end

  context "with a table -> function -> index dependency" do
    let(:migration) do
      <<~RUBY
        create_table "users", force: :cascade do |t|
          t.string "first_name"
          t.string "last_name"
        end

        create_function "full_name(u users) text" do |f|
          f.volatility :immutable
          f.strict true
          f.parallel :safe
          f.body <<~Q.chomp
            SELECT (
            CASE WHEN u.first_name IS NULL THEN '' ELSE u.first_name || ' ' END
            ) || COALESCE(u.last_name, '')
          Q
        end

        add_index "users", "full_name(users.*)", name: "users_full_name_idx"
      RUBY
    end

    its(:execution) { is_expected.to insert(migration).into_schema }
  end

  context "with a composite -> domain -> function dependency", since_version: 12 do
    let(:migration) do
      <<~RUBY
        create_composite_type "color_point" do |t|
          t.column "x", "integer"
          t.column "y", "integer"
          t.column "color", "text"
        end

        create_domain "rb_point", as: "color_point" do |d|
          d.constraint <<~Q.chomp, name: "valid_color"
            (VALUE).color = 'red'::text OR (VALUE).color = 'blue'::text
          Q
          d.constraint "(VALUE).x IS NOT NULL", name: "valid_x"
          d.constraint "(VALUE).y IS NOT NULL", name: "valid_y"
        end

        create_function "distance(a rb_point, b rb_point) double precision" do |f|
          f.body <<~Q.chomp
            SELECT |/ (((b.x) - (a.x)) ^ 2 + ((b.y) - (a.y)) ^ 2 +
            (CASE WHEN b.color != a.color THEN 1 ELSE 0 END))
          Q
          f.comment <<~Q.chomp
            Apply the Pythagorean theorem adding 1 as a distance between colors
          Q
        end
      RUBY
    end

    its(:execution) { is_expected.to insert(migration).into_schema }
  end

  context "with a enum -> table dependency", since_version: 12 do
    let(:migration) do
      <<~RUBY
        create_enum "currency" do |e|
          e.values "CFR", "EUR", "JPY", "USD"
        end

        create_table "transactions", force: :cascade do |t|
          t.text "sender"
          t.text "receiver"
          t.column "currency", "currency"
        end
      RUBY
    end

    its(:execution) { is_expected.to insert(migration).into_schema }
  end

  context "with a domain -> table dependency", since_version: 12 do
    let(:migration) do
      <<~RUBY
        create_domain "currency", as: "text" do |d|
          d.constraint "VALUE ~ '^[A-Z]{3}$'::text", name: "currency_check"
        end

        create_table "transactions", force: :cascade do |t|
          t.text "sender"
          t.text "receiver"
          t.column "currency", "currency"
        end
      RUBY
    end

    its(:execution) { is_expected.to insert(migration).into_schema }
  end

  context "with a composite_type -> table dependency", since_version: 12 do
    let(:migration) do
      <<~RUBY
        create_composite_type "sum" do |t|
          t.column "currency", "text"
          t.column "value", "integer"
        end

        create_table "transactions", force: :cascade do |t|
          t.text "sender"
          t.text "receiver"
          t.column "summa", "sum"
        end
      RUBY
    end

    its(:execution) { is_expected.to insert(migration).into_schema }
  end
end
