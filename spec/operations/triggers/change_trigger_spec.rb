# frozen_string_literal: true

describe ActiveRecord::Migration, "#change_trigger" do
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

      create_function "set_foo() trigger" do |f|
        f.language "plpgsql"
        f.body "BEGIN SET custom.foo = 42; END;"
      end
    RUBY
  end
  before { run_migration(old_snippet) }

  let(:old_snippet) do
    <<~RUBY
      create_trigger "users", "do_nothing" do |t|
        t.function "do_nothing()"
        t.for_each :row
        t.type :after
        t.events %i[update]
        t.comment "Old comment"
      end
    RUBY
  end

  context "in PostgreSQL v14+", since_version: 14 do
    context "with explicitly reversible changes" do
      let(:migration) do
        <<~RUBY
          change_trigger "users", "do_nothing" do |t|
            t.function "set_foo()", from: "do_nothing()"
            t.type :before, from: :after
            t.events %i[insert update], from: %i[update]
            t.comment "New comment", from: "Old comment"
          end
        RUBY
      end
      let(:new_snippet) do
        <<~RUBY
          create_trigger "users", "do_nothing" do |t|
            t.function "set_foo()"
            t.for_each :row
            t.type :before
            t.events %i[insert update]
            t.comment "New comment"
          end
        RUBY
      end

      its(:execution) { is_expected.to insert(new_snippet).into_schema }
      its(:execution) { is_expected.to remove(old_snippet).from_schema }
      its(:inversion) { is_expected.not_to change_schema }
    end

    context "with implicitly reversible changes" do
      let(:migration) do
        <<~RUBY
          change_trigger "users", "do_nothing" do |t|
            t.for_each :statement
          end
        RUBY
      end
      let(:new_snippet) do
        <<~RUBY
          create_trigger "users", "do_nothing" do |t|
            t.function "do_nothing()"
            t.type :after
            t.events %i[update]
            t.comment "Old comment"
          end
        RUBY
      end

      its(:execution) { is_expected.to insert(new_snippet).into_schema }
      its(:execution) { is_expected.to remove(old_snippet).from_schema }
      its(:inversion) { is_expected.not_to change_schema }
    end

    context "with irreversible changes" do
      let(:migration) do
        <<~RUBY
          change_trigger "users", "do_nothing" do |t|
            t.function "set_foo()"
            t.type :before
            t.events %i[insert update]
            t.comment "New comment"
          end
        RUBY
      end
      let(:new_snippet) do
        <<~RUBY
          create_trigger "users", "do_nothing" do |t|
            t.function "set_foo()"
            t.for_each :row
            t.type :before
            t.events %i[insert update]
            t.comment "New comment"
          end
        RUBY
      end

      its(:execution) { is_expected.to insert(new_snippet).into_schema }
      its(:execution) { is_expected.to remove(old_snippet).from_schema }
      it { is_expected.to be_irreversible.because_of(/body|comment/i) }
    end

    context "when the procedure is absent" do
      let(:migration) do
        <<~RUBY
          change_trigger "users", "unknown" do |t|
            t.comment "New comment", from: "Old comment"
          end
        RUBY
      end

      context "without the `if_exists` option" do
        its(:execution) { is_expected.to raise_error(StandardError) }
      end

      context "with the `if_exists: true` option" do
        let(:migration) do
          <<~RUBY
            change_trigger "users", "unknown", if_exists: true do |t|
              t.comment "New comment", from: "Old comment"
            end
          RUBY
        end

        its(:execution) { is_expected.not_to change_schema }
        it { is_expected.to be_irreversible.because_of(/if_exists: true/i) }
      end
    end

    context "with unknown table" do
      let(:migration) do
        <<~RUBY
          change_trigger "user", "do_nothing" do |t|
            t.comment "New comment", from: "Old comment"
          end
        RUBY
      end

      its(:execution) { is_expected.to raise_error(StandardError) }
    end
  end

  context "in PostgreSQL before v14", before_version: 14 do
    context "with explicitly reversible changes" do
      let(:migration) do
        <<~RUBY
          change_trigger "users", "do_nothing" do |t|
            t.function "set_foo()", from: "do_nothing()"
            t.type :before, from: :after
            t.events %i[insert update], from: %i[update]
            t.comment "New comment", from: "Old comment"
          end
        RUBY
      end

      its(:execution) { is_expected.to raise_error(/supported by PostgreSQL server v14+/i) }
    end
  end

  context "with no changes" do
    let(:migration) do
      <<~RUBY
        change_trigger "users", "do_nothing"
      RUBY
    end

    it { is_expected.to fail_validation.because(/changes can't be blank/i) }
  end

  context "without name" do
    let(:migration) do
      <<~RUBY
        change_trigger "users", if_exists: true do |t|
          t.comment "New comment", from: "Old comment"
        end
      RUBY
    end

    it { is_expected.to fail_validation.because(/name can't be blank/i) }
  end
end
