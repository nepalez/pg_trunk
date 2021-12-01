# frozen_string_literal: true

describe ActiveRecord::Migration, "#rename_statistics" do
  before_all do
    run_migration <<~RUBY
      create_table :users do |t|
        t.string :name
        t.string :family
      end
    RUBY
  end
  before { run_migration(old_snippet) }

  context "when the constraint was anonymous" do
    let(:old_snippet) do
      <<~RUBY
        create_statistics do |s|
          s.table :users
          s.kinds :dependencies, :ndistinct
          s.columns "name", "family"
        end
      RUBY
    end

    context "with a new name" do
      let(:migration) do
        <<~RUBY
          rename_statistics to: "my_stats" do |s|
            s.table :users
            s.kinds :dependencies, :ndistinct
            s.columns "name", "family"
          end
        RUBY
      end
      let(:new_snippet) do
        <<~RUBY
          create_statistics "my_stats" do |s|
            s.table "users"
            s.columns "family", "name"
            s.kinds :dependencies, :ndistinct
          end
        RUBY
      end

      its(:execution) { is_expected.to insert(new_snippet).into_schema }
      its(:reversion) { is_expected.not_to change_schema }
    end

    context "without a new name" do
      let(:migration) do
        <<~RUBY
          rename_statistics do |s|
            s.table :users
            s.kinds :dependencies, :ndistinct
            s.columns "name", "family"
          end
        RUBY
      end

      it { is_expected.to fail_validation.because(/new name must be different/i) }
    end
  end

  context "when the constraint was named explicitly" do
    let(:old_snippet) do
      <<~RUBY
        create_statistics "my_old_name" do |s|
          s.table "users"
          s.kinds :dependencies, :ndistinct
          s.columns "name", "family"
        end
      RUBY
    end

    context "with a new name" do
      let(:migration) do
        <<~RUBY
          rename_statistics "my_old_name", to: "my_new_name"
        RUBY
      end
      let(:new_snippet) do
        <<~RUBY
          create_statistics "my_new_name" do |s|
            s.table "users"
            s.columns "family", "name"
            s.kinds :dependencies, :ndistinct
          end
        RUBY
      end

      its(:execution) { is_expected.to insert(new_snippet).into_schema }
      its(:reversion) { is_expected.not_to change_schema }
    end

    context "when missed new name can be generated" do
      let(:migration) do
        <<~RUBY
          rename_statistics "my_old_name" do |s|
            s.table "users"
            s.kinds :dependencies, :ndistinct
            s.columns "name", "family"
          end
        RUBY
      end
      let(:snippet) do
        <<~RUBY
          create_statistics do |s|
            s.table "users"
            s.columns "family", "name"
            s.kinds :dependencies, :ndistinct
          end
        RUBY
      end

      its(:execution) { is_expected.to insert(snippet).into_schema }
      its(:reversion) { is_expected.not_to change_schema }
    end

    context "when missed new name can't be generated" do
      let(:migration) do
        <<~RUBY
          rename_statistics "my_old_name"
        RUBY
      end

      it { is_expected.to fail_validation.because(/new name can't be blank/i) }
    end
  end
end
