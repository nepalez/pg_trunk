# frozen_string_literal: true

describe ActiveRecord::Migration, "#create_rule" do
  before_all do
    run_migration <<~RUBY
      create_table :users do |t|
        t.string :name
      end

      create_table :user_updates do |t|
        t.timestamps
      end
    RUBY
  end

  context "with a minimal definition" do
    let(:migration) do
      <<~RUBY
        create_rule "users", "prevent_insertion" do |r|
          r.event :insert
          r.kind :instead
          r.comment "Prevent insertion to users"
        end
      RUBY
    end

    its(:execution) { is_expected.to insert(migration).into_schema }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "with a commands definition" do
    let(:migration) do
      <<~RUBY
        create_rule "users", "count_updates" do |r|
          r.event :update
          r.command <<~Q.chomp
            INSERT INTO user_updates (created_at) VALUES (now())
          Q
          r.comment "Count updates of users"
        end
      RUBY
    end

    its(:execution) { is_expected.to insert(migration).into_schema }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "without an explicit name of the rule" do
    let(:migration) do
      <<~RUBY
        create_rule "users" do |r|
          r.event :update
          r.command <<~Q.chomp
            INSERT INTO user_updates (created_at) VALUES (now())
          Q
          r.comment "Count updates of users"
        end
      RUBY
    end

    its(:execution) { is_expected.to insert(migration).into_schema }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "with the `replace_existing: true` option" do
    let(:migration) do
      <<~RUBY
        create_rule "users", replace_existing: true do |r|
          r.event :update
          r.command <<~Q.chomp
            INSERT INTO user_updates (created_at) VALUES (now());
          Q
          r.comment "Count updates of users"
        end
      RUBY
    end
    let(:snippet) do
      <<~RUBY
        create_rule "users" do |r|
          r.event :update
          r.command <<~Q.chomp
            INSERT INTO user_updates (created_at) VALUES (now())
          Q
          r.comment "Count updates of users"
        end
      RUBY
    end

    its(:execution) { is_expected.to insert(snippet).into_schema }
    it { is_expected.to be_irreversible.because_of(/replace_existing: true/i) }
  end

  context "without an event" do
    let(:migration) do
      <<~RUBY
        create_rule "users" do |r|
          r.kind :instead
          r.comment "Prevent insertion to users"
        end
      RUBY
    end

    it { is_expected.to fail_validation.because(/event can't be blank/i) }
  end

  context "without a table" do
    let(:migration) do
      <<~RUBY
        create_rule do |r|
          r.event :insert
          r.kind :instead
          r.comment "Prevent insertion to users"
        end
      RUBY
    end

    it { is_expected.to fail_validation.because(/table can't be blank/i) }
  end
end
