# frozen_string_literal: true

describe ActiveRecord::Migration, "#drop_statistics" do
  before_all do
    run_migration <<~RUBY
      create_table :users do |t|
        t.string :name
        t.string :family
      end
    RUBY
  end
  before { run_migration(snippet) }

  context "when the statistics was anonymous" do
    let(:snippet) do
      <<~RUBY
        create_statistics do |s|
          s.table "users"
          s.columns "family", "name"
          s.kinds :dependencies, :ndistinct
        end
      RUBY
    end
    let(:migration) do
      <<~RUBY
        drop_statistics do |s|
          s.table "users"
          s.columns "family", "name"
          s.kinds :dependencies, :ndistinct
        end
      RUBY
    end

    its(:execution) { is_expected.to remove(snippet).from_schema }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "when the statistics was named explicitly" do
    let(:snippet) do
      <<~RUBY
        create_statistics "my_stats" do |s|
          s.table "users"
          s.columns "family", "name"
          s.kinds :dependencies, :ndistinct
        end
      RUBY
    end
    let(:migration) do
      <<~RUBY
        drop_statistics "my_stats" do |s|
          s.table "users"
          s.columns "family", "name"
          s.kinds :dependencies, :ndistinct
        end
      RUBY
    end

    its(:execution) { is_expected.to remove(snippet).from_schema }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "without a full definition" do
    let(:snippet) do
      <<~RUBY
        create_statistics "my_stats" do |s|
          s.table "users"
          s.columns "family", "name"
          s.kinds :dependencies, :ndistinct
        end
      RUBY
    end
    let(:migration) do
      <<~RUBY
        drop_statistics "my_stats"
      RUBY
    end

    its(:execution) { is_expected.to remove(snippet).from_schema }
    it { is_expected.to be_irreversible.because(/table can't be blank/i) }
  end

  context "when a statistics was absent" do
    let(:snippet) { "" }

    context "without `if_exists` option" do
      let(:migration) do
        <<~RUBY
          drop_statistics "my_stats"
        RUBY
      end

      its(:execution) { is_expected.to raise_error(StandardError) }
    end

    context "with the `if_exists: true` option" do
      let(:migration) do
        <<~RUBY
          drop_statistics "my_stats", if_exists: true
        RUBY
      end

      its(:execution) { is_expected.not_to change_schema }
      it { is_expected.to be_irreversible.because_of(/if_exists: true/i) }
    end
  end
end
