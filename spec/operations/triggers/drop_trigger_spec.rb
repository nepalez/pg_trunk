# frozen_string_literal: true

describe ActiveRecord::Migration, "#drop_trigger" do
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
  before { run_migration(snippet) }

  context "when a trigger had an explicit name" do
    let(:snippet) do
      <<~RUBY
        create_trigger "users", "do_nothing" do |t|
          t.function "do_nothing()"
          t.for_each :row
          t.type :after
          t.events %i[update]
          t.comment "My new trigger"
        end
      RUBY
    end

    context "with the full definition of the trigger" do
      let(:migration) do
        <<~RUBY
          drop_trigger "users", "do_nothing" do |t|
            t.function "do_nothing()"
            t.for_each :row
            t.type :after
            t.events %i[update]
            t.comment "My new trigger"
          end
        RUBY
      end

      its(:execution) { is_expected.to remove(snippet).from_schema }
      its(:inversion) { is_expected.not_to change_schema }
    end

    context "with the explicit name only" do
      let(:migration) do
        <<~RUBY
          drop_trigger "users", "do_nothing"
        RUBY
      end

      its(:execution) { is_expected.to remove(snippet).from_schema }
      it { is_expected.to be_irreversible.because_of(/function/i) }
    end

    context "when the trigger not existed" do
      context "without the `if_exists` option" do
        let(:migration) do
          <<~RUBY
            drop_trigger "users", "weird"
          RUBY
        end

        its(:execution) { is_expected.to raise_error(StandardError) }
      end

      context "with the `if_exists` option" do
        let(:migration) do
          <<~RUBY
            drop_trigger "users", "weird", if_exists: true
          RUBY
        end

        its(:execution) { is_expected.not_to raise_error }
        it { is_expected.to be_irreversible.because_of(/if_exists: true/i) }
      end
    end
  end

  context "when a trigger was anonymous (with a generated name)" do
    let(:snippet) do
      <<~RUBY
        create_trigger "users" do |t|
          t.function "do_nothing()"
          t.for_each :row
          t.type :after
          t.events %i[update]
          t.comment "My new trigger"
        end
      RUBY
    end

    context "with the full definition of the trigger" do
      let(:migration) do
        <<~RUBY
          drop_trigger "users" do |t|
            t.function "do_nothing()"
            t.for_each :row
            t.type :after
            t.events %i[update]
            t.comment "My new trigger"
          end
        RUBY
      end

      its(:execution) { is_expected.to remove(snippet).from_schema }
      its(:inversion) { is_expected.not_to change_schema }
    end

    context "without a full definition" do
      let(:migration) do
        <<~RUBY
          drop_trigger "users"
        RUBY
      end

      it { is_expected.to fail_validation.because(/name can't be blank/i) }
    end
  end
end
