# frozen_string_literal: true

describe ActiveRecord::Migration, "#rename_check_constraint" do
  before_all do
    run_migration <<~RUBY
      create_table :users do |t|
        t.string :name
      end
    RUBY
  end
  before { run_migration(old_snippet) }

  context "when the constraint was anonymous" do
    let(:old_snippet) do
      <<~RUBY.squish
        add_check_constraint "users", "length(name) > 1"
      RUBY
    end

    context "with a new name" do
      let(:migration) do
        <<~RUBY.squish
          rename_check_constraint "users", "length(name) > 1", to: "my_new_key"
        RUBY
      end
      let(:new_snippet) do
        <<~RUBY.squish
          add_check_constraint "users", "length((name)::text) > 1",
                               name: "my_new_key"
        RUBY
      end

      its(:execution) { is_expected.to insert(new_snippet).into_schema }
      its(:reversion) { is_expected.not_to change_schema }
    end

    context "without a new name" do
      let(:migration) do
        <<~RUBY.squish
          rename_check_constraint "users", "length((name)::text) > 1"
        RUBY
      end

      it { is_expected.to fail_validation.because(/new name must be different/i) }
    end
  end

  context "when the constraint was named explicitly" do
    let(:old_snippet) do
      <<~RUBY.squish
        add_check_constraint "users", "length(name) > 1", name: "my_key"
      RUBY
    end

    context "without new name" do
      let(:migration) do
        <<~RUBY
          rename_check_constraint "users", "length((name)::text) > 1",
                                  name: "my_key"
        RUBY
      end
      let(:new_snippet) do
        <<~RUBY
          add_check_constraint "users", "length((name)::text) > 1"
        RUBY
      end

      its(:execution) { is_expected.to insert(new_snippet).into_schema }
      its(:reversion) { is_expected.not_to change_schema }
    end

    context "with a new name" do
      let(:migration) do
        <<~RUBY
          rename_check_constraint "users", "length((name)::text) > 1",
                                  name: "my_key",
                                  to: "new_key"
        RUBY
      end
      let(:snippet) do
        <<~RUBY.squish
          add_check_constraint "users", "length((name)::text) > 1", name: "new_key"
        RUBY
      end

      its(:execution) { is_expected.to insert(snippet).into_schema }
      its(:reversion) { is_expected.not_to change_schema }
    end
  end
end
