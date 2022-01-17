# frozen_string_literal: true

describe ActiveRecord::Migration, "#rename_rule" do
  before_all do
    run_migration <<~RUBY
      create_table :users do |t|
        t.string :name
      end
    RUBY
  end
  before { run_migration(old_snippet) }

  context "when a rule was named" do
    let(:old_snippet) do
      <<~RUBY
        create_rule "users", "prevent_insertion" do |r|
          r.event :insert
          r.kind :instead
          r.comment "Prevent insertion to users"
        end
      RUBY
    end

    context "with a new name" do
      let(:migration) do
        <<~RUBY
          rename_rule "users", "prevent_insertion", to: "do_nothing"
        RUBY
      end
      let(:new_snippet) do
        <<~RUBY
          create_rule "users", "do_nothing" do |r|
            r.event :insert
            r.kind :instead
            r.comment "Prevent insertion to users"
          end
        RUBY
      end

      its(:execution) { is_expected.to remove(old_snippet).from_schema }
      its(:execution) { is_expected.to insert(new_snippet).into_schema }
      its(:inversion) { is_expected.not_to change_schema }
    end

    context "with the same name" do
      let(:migration) do
        <<~RUBY
          rename_rule "users", "prevent_insertion", to: "prevent_insertion"
        RUBY
      end

      it { is_expected.to fail_validation.because(/new name must be different/i) }
    end

    context "without new name" do
      let(:migration) do
        <<~RUBY
          rename_rule "users", "prevent_insertion" do |r|
            r.event :insert
            r.kind :instead
          end
        RUBY
      end
      let(:new_snippet) do
        <<~RUBY
          create_rule "users" do |r|
            r.event :insert
            r.kind :instead
            r.comment "Prevent insertion to users"
          end
        RUBY
      end

      its(:execution) { is_expected.to remove(old_snippet).from_schema }
      its(:execution) { is_expected.to insert(new_snippet).into_schema }
      its(:inversion) { is_expected.not_to change_schema }
    end

    context "when absent name can't be generated from kind/event" do
      let(:migration) do
        <<~RUBY
          rename_rule "users", "prevent_insertion"
        RUBY
      end

      it { is_expected.to fail_validation.because(/new name can't be blank/i) }
    end
  end

  context "when a rule was anonymous" do
    let(:old_snippet) do
      <<~RUBY
        create_rule "users" do |r|
          r.event :insert
          r.kind :instead
          r.comment "Prevent insertion to users"
        end
      RUBY
    end

    context "with a new name" do
      let(:migration) do
        <<~RUBY
          rename_rule "users", to: "do_nothing" do |r|
            r.event :insert
            r.kind :instead
          end
        RUBY
      end
      let(:new_snippet) do
        <<~RUBY
          create_rule "users", "do_nothing" do |r|
            r.event :insert
            r.kind :instead
            r.comment "Prevent insertion to users"
          end
        RUBY
      end

      its(:execution) { is_expected.to remove(old_snippet).from_schema }
      its(:execution) { is_expected.to insert(new_snippet).into_schema }
      its(:inversion) { is_expected.not_to change_schema }
    end

    context "without new name" do
      let(:migration) do
        <<~RUBY
          rename_rule "users" do |r|
            r.event :insert
            r.kind :instead
          end
        RUBY
      end

      it { is_expected.to fail_validation.because(/new name must be different/i) }
    end

    context "when absent name can't be generated" do
      let(:migration) do
        <<~RUBY
          rename_rule "users", to: "do_nothing"
        RUBY
      end

      it { is_expected.to fail_validation.because(/name can't be blank/i) }
    end
  end
end
