# frozen_string_literal: true

describe ActiveRecord::Migration, "#rename_table" do
  let(:migration) do
    <<~RUBY
      create_table :roles
      create_table :users do |t|
        t.integer :role_id, index: true
        t.string :name
        t.foreign_key :roles
        t.check_constraint "length(name) > 1"
      end

      rename_table :users, :customers
    RUBY
  end
  let(:snippet) do
    <<~RUBY
      create_table "customers", force: :cascade do |t|
        t.integer "role_id"
        t.string "name"
      end

      create_table "roles", force: :cascade do |t|
      end

      add_index "customers", ["role_id"], name: "index_customers_on_role_id"

      add_check_constraint "customers", "length((name)::text) > 1"

      add_foreign_key "customers", "roles"
    RUBY
  end

  its(:execution) { is_expected.to insert(snippet).into_schema }
  its(:inversion) { is_expected.not_to change_schema }
end
