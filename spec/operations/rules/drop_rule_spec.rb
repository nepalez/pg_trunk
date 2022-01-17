# frozen_string_literal: true

describe ActiveRecord::Migration, "#drop_rule" do
  before_all do
    run_migration <<~RUBY
      create_table :users do |t|
        t.string :name
      end
    RUBY
  end
  before { run_migration(snippet) }

  context "when a rule was named" do
    let(:snippet) do
      <<~RUBY
        create_rule "users", "prevent_insertion" do |r|
          r.event :insert
          r.kind :instead
          r.comment "Prevent insertion to users"
        end
      RUBY
    end

    context "with a full definition" do
      let(:migration) do
        <<~RUBY
          drop_rule "users", "prevent_insertion" do |r|
            r.event :insert
            r.kind :instead
            r.comment "Prevent insertion to users"
          end
        RUBY
      end

      its(:execution) { is_expected.to remove(snippet).from_schema }
      its(:inversion) { is_expected.not_to change_schema }
    end

    context "with a name only" do
      let(:migration) do
        <<~RUBY
          drop_rule "users", "prevent_insertion"
        RUBY
      end

      its(:execution) { is_expected.to remove(snippet).from_schema }
      it { is_expected.to be_irreversible.because(/event can't be blank/i) }
    end

    context "with if_exists: true option" do
      let(:migration) do
        <<~RUBY
          drop_rule "users", "prevent_insertion", if_exists: true do |r|
            r.event :insert
            r.kind :instead
            r.comment "Prevent insertion to users"
          end
        RUBY
      end

      its(:execution) { is_expected.to remove(snippet).from_schema }
      it { is_expected.to be_irreversible.because_of(/if_exists: true/i) }
    end

    context "with force: :cascade option" do
      let(:migration) do
        <<~RUBY
          drop_rule "users", "prevent_insertion", force: :cascade do |r|
            r.event :insert
            r.kind :instead
            r.comment "Prevent insertion to users"
          end
        RUBY
      end

      its(:execution) { is_expected.to remove(snippet).from_schema }
      it { is_expected.to be_irreversible.because_of(/force: :cascade/i) }
    end
  end

  context "when a rule was anonymous" do
    let(:snippet) do
      <<~RUBY
        create_rule "users" do |r|
          r.event :insert
          r.kind :instead
          r.comment "Prevent insertion to users"
        end
      RUBY
    end

    context "with a full definition" do
      let(:migration) do
        <<~RUBY
          drop_rule "users" do |r|
            r.event :insert
            r.kind :instead
            r.comment "Prevent insertion to users"
          end
        RUBY
      end

      its(:execution) { is_expected.to remove(snippet).from_schema }
      its(:inversion) { is_expected.not_to change_schema }
    end

    context "with a table only" do
      let(:migration) do
        <<~RUBY
          drop_rule "users"
        RUBY
      end

      it { is_expected.to fail_validation.because(/name can't be blank/i) }
    end
  end
end
