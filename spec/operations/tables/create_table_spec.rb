# frozen_string_literal: true

describe ActiveRecord::Migration, "#create_table" do
  context "with indexes and check constraints" do
    let(:migration) do
      <<~RUBY
        create_table :roles
        create_table :users do |t|
          t.integer :role_id, index: true
          t.string :name
          t.check_constraint "length(name) > 2"
          t.foreign_key :roles
        end
      RUBY
    end
    let(:snippet) do
      <<~RUBY
        create_table "roles", force: :cascade do |t|
        end

        create_table "users", force: :cascade do |t|
          t.integer "role_id"
          t.string "name"
        end

        add_index "users", ["role_id"], name: "index_users_on_role_id"
      RUBY
    end

    its(:execution) { is_expected.to insert(snippet).into_schema }
  end

  context "with a custom id (primary key) definition" do
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
end
