# frozen_string_literal: true

describe ActiveRecord::Migration, "#rename_trigger" do
  before_all do
    run_migration <<~RUBY
      create_table :foo
      create_function "avoid() trigger", language: :plpgsql, body: "BEGIN END;"
    RUBY
  end
  before { run_migration(old_snippet) }

  context "when a trigger had an explicit name" do
    let(:old_snippet) do
      <<~RUBY
        create_trigger "foo", "do_nothing" do |t|
          t.function "avoid()"
          t.type :after
          t.events %i[insert]
        end
      RUBY
    end

    context "with both old and new names" do
      let(:migration) do
        <<~RUBY
          rename_trigger :foo, :do_nothing, to: :do_something
        RUBY
      end
      let(:new_snippet) do
        <<~RUBY
          create_trigger "foo", "do_something" do |t|
            t.function "avoid()"
            t.type :after
            t.events %i[insert]
          end
        RUBY
      end

      its(:execution) { is_expected.to remove(old_snippet).from_schema }
      its(:execution) { is_expected.to insert(new_snippet).into_schema }
      its(:inversion) { is_expected.not_to change_schema }
    end

    context "when a new name can be generated from params" do
      let(:migration) do
        <<~RUBY
          rename_trigger "foo", "do_nothing" do |t|
            t.function "avoid()"
            t.type :after
            t.events %i[insert]
          end
        RUBY
      end
      let(:new_snippet) do
        <<~RUBY
          create_trigger "foo" do |t|
            t.function "avoid()"
            t.type :after
            t.events %i[insert]
          end
        RUBY
      end

      its(:execution) { is_expected.to remove(old_snippet).from_schema }
      its(:execution) { is_expected.to insert(new_snippet).into_schema }
      its(:inversion) { is_expected.not_to change_schema }
    end

    context "when a new name can't be generated" do
      let(:migration) do
        <<~RUBY
          rename_trigger "foo", "do_nothing"
        RUBY
      end

      it { is_expected.to fail_validation.because(/new name can't be blank/i) }
    end

    context "with the same name" do
      let(:migration) do
        <<~RUBY
          rename_trigger :foo, :do_nothing, to: :do_nothing
        RUBY
      end

      it { is_expected.to fail_validation.because(/new name must be different/i) }
    end

    context "without an old name" do
      let(:migration) do
        <<~RUBY
          rename_trigger :foo, to: :do_something
        RUBY
      end

      it { is_expected.to fail_validation.because(/name can't be blank/i) }
    end
  end

  context "when a trigger had a generated name" do
    let(:old_snippet) do
      <<~RUBY
        create_trigger "foo" do |t|
          t.function "avoid()"
          t.type :after
          t.events %i[insert]
        end
      RUBY
    end

    context "when the old name can be generated from params" do
      let(:migration) do
        <<~RUBY
          rename_trigger "foo", to: "do_something" do |t|
            t.function "avoid()"
            t.type :after
            t.events %i[insert]
          end
        RUBY
      end
      let(:new_snippet) do
        <<~RUBY
          create_trigger "foo", "do_something" do |t|
            t.function "avoid()"
            t.type :after
            t.events %i[insert]
          end
        RUBY
      end

      its(:execution) { is_expected.to remove(old_snippet).from_schema }
      its(:execution) { is_expected.to insert(new_snippet).into_schema }
      its(:inversion) { is_expected.not_to change_schema }
    end

    context "when the old name can't be generated" do
      let(:migration) do
        <<~RUBY
          rename_trigger "foo", to: "do_something"
        RUBY
      end

      it { is_expected.to fail_validation.because(/name can't be blank/i) }
    end

    context "without a new name" do
      let(:migration) do
        <<~RUBY
          rename_trigger "foo" do |t|
            t.function "avoid()"
            t.type :after
            t.events %i[insert]
          end
        RUBY
      end

      it { is_expected.to fail_validation.because(/new name must be different/i) }
    end
  end
end
