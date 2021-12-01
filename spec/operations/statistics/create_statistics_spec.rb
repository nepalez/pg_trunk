# frozen_string_literal: true

describe ActiveRecord::Migration, "#create_statistics" do
  before_all do
    run_migration <<~RUBY
      create_table :users do |t|
        t.string :name
        t.string :family
      end
    RUBY
  end

  context "with an explicit name" do
    let(:migration) do
      <<~RUBY
        create_statistics "my_stats" do |s|
          s.table "users"
          s.columns "family", "name"
          s.kinds :dependencies, :ndistinct
          s.comment "Collect all stats"
        end
      RUBY
    end

    its(:execution) { is_expected.to insert(migration).into_schema }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "without a name" do
    let(:migration) do
      <<~RUBY
        create_statistics do |s|
          s.table "users"
          s.columns "family", "name"
          s.kinds :dependencies, :ndistinct
          s.comment "Collect all stats"
        end
      RUBY
    end

    its(:execution) { is_expected.to insert(migration).into_schema }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "with one column" do
    let(:migration) do
      <<~RUBY
        create_statistics "my_stats" do |s|
          s.table "users"
          s.columns "family"
          s.kinds :dependencies, :ndistinct
          s.comment "Collect all stats"
        end
      RUBY
    end

    it { is_expected.to fail_validation.because(/add more columns/i) }
  end

  context "with several expressions", since_version: 14 do
    let(:migration) do
      <<~RUBY
        create_statistics "my_stats" do |s|
          s.table "users"
          s.expression "length(family::text)"
          s.expression "length(name::text)"
          s.kinds :dependencies, :ndistinct
          s.comment "Collect all stats"
        end
      RUBY
    end

    its(:execution) { is_expected.to insert(migration).into_schema }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "with several columns and expressions", since_version: 14 do
    let(:migration) do
      <<~RUBY
        create_statistics "my_stats" do |s|
          s.table "users"
          s.columns "name"
          s.expression "length(family::text)"
          s.kinds :dependencies, :ndistinct
          s.comment "Collect all stats"
        end
      RUBY
    end

    its(:execution) { is_expected.to insert(migration).into_schema }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "with mcv kind" do
    let(:migration) do
      <<~RUBY
        create_statistics "my_stats" do |s|
          s.table "users"
          s.columns "family", "name"
          s.kinds :dependencies, :mcv, :ndistinct
          s.comment "Collect all stats"
        end
      RUBY
    end

    context "before version 12", before_version: 12 do
      its(:execution) { is_expected.to raise_error(/supported in PostgreSQL v12+/i) }
    end

    context "since version 12", since_version: 12 do
      its(:execution) { is_expected.to insert(migration).into_schema }
      its(:inversion) { is_expected.not_to change_schema }
    end
  end

  context "with one expression only", since_version: 14 do
    context "without kinds" do
      let(:migration) do
        <<~RUBY
          create_statistics "my_stats" do |s|
            s.table "users"
            s.expression "length(family::text)"
            s.comment "Collect all stats"
          end
        RUBY
      end

      its(:execution) { is_expected.to insert(migration).into_schema }
      its(:inversion) { is_expected.not_to change_schema }
    end

    context "with kinds" do
      let(:migration) do
        <<~RUBY
          create_statistics "my_stats" do |s|
            s.table "users"
            s.expression "length(family::text)"
            s.kinds :dependencies
            s.comment "Collect all stats"
          end
        RUBY
      end

      it { is_expected.to fail_validation.because(/kinds must be blank/i) }
    end
  end

  context "with expressions", before_version: 14 do
    let(:migration) do
      <<~RUBY
        create_statistics "my_stats" do |s|
          s.table "users"
          s.columns "name"
          s.expression "length(family::text)"
          s.kinds :dependencies, :ndistinct
          s.comment "Collect all stats"
        end
      RUBY
    end

    its(:execution) { is_expected.to raise_error(/supported in PostgreSQL v14+/i) }
  end

  context "when the statistics existed" do
    before do
      run_migration <<~RUBY
        create_statistics "my_stats" do |s|
          s.table "users"
          s.columns "family", "name"
          s.comment "Collect all stats"
        end
      RUBY
    end

    context "without the `if_not_exists` option" do
      let(:migration) do
        <<~RUBY
          create_statistics "my_stats" do |s|
            s.table "users"
            s.columns "family", "name"
            s.comment "Collect all stats"
          end
        RUBY
      end

      its(:execution) { is_expected.to raise_error(StandardError) }
    end

    context "with the `if_not_exists: true` option" do
      let(:migration) do
        <<~RUBY
          create_statistics "my_stats", if_not_exists: true do |s|
            s.table "users"
            s.columns "family", "name"
            s.comment "Collect all stats"
          end
        RUBY
      end

      its(:execution) { is_expected.not_to change_schema }
      it { is_expected.to be_irreversible.because_of(/if_not_exists: true/i) }
    end

    context "without a table" do
      let(:migration) do
        <<~RUBY
          create_statistics "my_stats" do |s|
            s.columns "family", "name"
            s.kinds :dependencies, :ndistinct
          end
        RUBY
      end

      it { is_expected.to fail_validation.because(/table can't be blank/i) }
    end

    context "without columns and expressions" do
      let(:migration) do
        <<~RUBY
          create_statistics "my_stats" do |s|
            s.table "users"
            s.kinds :dependencies, :ndistinct
          end
        RUBY
      end

      it { is_expected.to fail_validation.because(/can't be blank/i) }
    end
  end
end
