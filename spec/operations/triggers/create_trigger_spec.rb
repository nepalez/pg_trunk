# frozen_string_literal: true

describe ActiveRecord::Migration, "#create_trigger" do
  before_all do
    run_migration <<~RUBY
      create_table "users", force: :cascade do |t|
        t.string "name"
        t.boolean "admin"
      end

      create_function "do_nothing() trigger" do |f|
        f.language "plpgsql"
        f.body "BEGIN END;"
      end
    RUBY
  end

  context "with an explicit name" do
    let(:migration) do
      <<~RUBY
        create_trigger "users", "do_nothing" do |t|
          t.function "do_nothing()"
          t.for_each :row
          t.type :after
          t.events %i[update]
          t.comment "Block granting rights of an admin"
        end
      RUBY
    end

    its(:execution) { is_expected.to insert(migration).into_schema }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "with a constraint" do
    let(:migration) do
      <<~RUBY
        create_trigger "users", "do_nothing" do |t|
          t.function "do_nothing()"
          t.constraint true
          t.events %i[update]
          t.comment "Block granting rights of an admin"
        end
      RUBY
    end
    let(:snippet) do
      <<~RUBY
        create_trigger "users", "do_nothing" do |t|
          t.function "do_nothing()"
          t.constraint true
          t.for_each :row
          t.type :after
          t.events %i[update]
          t.comment "Block granting rights of an admin"
        end
      RUBY
    end

    its(:execution) { is_expected.to insert(snippet).into_schema }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "without a name" do
    let(:migration) do
      <<~RUBY
        create_trigger "users" do |t|
          t.function "do_nothing()"
          t.for_each :row
          t.type :before
          t.events %i[insert]
          t.comment "Block creation of an admin"
        end
      RUBY
    end

    its(:execution) { is_expected.to insert(migration).into_schema }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "without a function" do
    let(:migration) do
      <<~RUBY
        create_trigger "users" do |t|
          t.type :instead_of
          t.events %i[insert]
        end
      RUBY
    end

    it { is_expected.to fail_validation.because_of(/function/i) }
  end

  context "without events definition" do
    let(:migration) do
      <<~RUBY
        create_trigger "users" do |t|
          t.function "do_nothing()"
        end
      RUBY
    end

    it { is_expected.to fail_validation.because_of(/events/i) }
  end
end
