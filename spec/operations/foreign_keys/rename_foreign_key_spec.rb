# frozen_string_literal: true

describe ActiveRecord::Migration, "#rename_foreign_key" do
  before_all do
    run_migration <<~RUBY
      create_table :roles do |t|
        t.string :name
        t.index %i[name id], unique: true
      end

      create_table :users do |t|
        t.integer :role_id
        t.string :role_name
      end
    RUBY
  end
  before { run_migration(old_snippet) }

  context "when the key had an explicit name" do
    let(:old_snippet) do
      <<~RUBY.squish
        add_foreign_key "users", "roles",
                        primary_key: %w[name id],
                        name: "my_key"
      RUBY
    end

    context "when both names are explicitly specified" do
      let(:migration) do
        <<~RUBY.squish
          rename_foreign_key "users", name: "my_key", to: "my_new_key"
        RUBY
      end
      let(:new_snippet) do
        <<~RUBY.squish
          add_foreign_key "users", "roles",
                          primary_key: %w[name id],
                          name: "my_new_key"
        RUBY
      end

      its(:execution) { is_expected.to insert(new_snippet).into_schema }
      its(:execution) { is_expected.to remove(old_snippet).from_schema }
      its(:reversion) { is_expected.not_to change_schema }
    end

    context "when new name is not specified" do
      let(:migration) do
        <<~RUBY.snippet
          rename_foreign_key "users", name: "my_key"
        RUBY
      end
      let(:snippet) do
        <<~RUBY.snippet
          add_foreign_key "users", "roles",
                          columns: %i[role_name role_id],
                          primary_key: %i[name id]
        RUBY
      end
    end

    context "without the old name" do
      let(:migration) do
        <<~RUBY.squish
          rename_foreign_key "users", "roles", to: "my_new_key"
        RUBY
      end

      it { is_expected.to fail_validation.because(/name can't be blank/i) }
    end
  end

  context "when the key was anonymous" do
    let(:old_snippet) do
      <<~RUBY.squish
        add_foreign_key "users", "roles", primary_key: %w[name id]
      RUBY
    end

    context "with a new name" do
      let(:migration) do
        <<~RUBY.squish
          rename_foreign_key "users", "roles",
                             primary_key: %w[name id],
                             to: "my_key"
        RUBY
      end
      let(:new_snippet) do
        <<~RUBY.squish
          add_foreign_key "users", "roles",
                          primary_key: %w[name id],
                          name: "my_key"
        RUBY
      end

      its(:execution) { is_expected.to insert(new_snippet).into_schema }
      its(:execution) { is_expected.to remove(old_snippet).from_schema }
      its(:inversion) { is_expected.not_to change_schema }
    end
  end
end
