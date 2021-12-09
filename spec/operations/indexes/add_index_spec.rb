# frozen_string_literal: true

describe ActiveRecord::Migration, "#add_index" do
  context "when index added inside a table definition" do
    let(:migration) do
      <<~RUBY
        create_table :users do |t|
          t.string "name", index: true
        end
      RUBY
    end
    let(:snippet) do
      <<~RUBY
        create_table "users", force: :cascade do |t|
          t.string "name"
        end

        add_index "users", ["name"], name: "index_users_on_name"
      RUBY
    end

    its(:execution) { is_expected.to insert(snippet).into_schema }
  end

  context "when primary key added inside a table definition" do
    let(:migration) do
      <<~RUBY
        create_table :users, primary_key: :name do |t|
        end
      RUBY
    end
    let(:snippet) do
      <<~RUBY
        create_table "users", primary_key: "name", force: :cascade do |t|
        end
      RUBY
    end

    its(:execution) { is_expected.to insert(snippet).into_schema }
  end

  context "when index is added outside of a table definition" do
    let(:migration) do
      <<~RUBY
        create_table :users do |t|
          t.string "name"
        end

        add_index :users, :name
      RUBY
    end
    let(:snippet) do
      <<~RUBY
        create_table "users", force: :cascade do |t|
          t.string "name"
        end

        add_index "users", ["name"], name: "index_users_on_name"
      RUBY
    end

    its(:execution) { is_expected.to insert(snippet).into_schema }
  end

  context "with several indexes" do
    let(:migration) do
      <<~RUBY
        create_table :users do |t|
          t.string :role, index: true
          t.string :name, index: true
        end

        create_table :roles do |t|
          t.string :name, index: true
          t.string :access, array: true, index: true
        end
      RUBY
    end
    let(:snippet) do
      # Ordered by table and name
      <<~RUBY
        add_index "roles", ["access"], name: "index_roles_on_access"

        add_index "roles", ["name"], name: "index_roles_on_name"

        add_index "users", ["name"], name: "index_users_on_name"

        add_index "users", ["role"], name: "index_users_on_role"
      RUBY
    end

    its(:execution) { is_expected.to insert(snippet).into_schema }
  end
end
