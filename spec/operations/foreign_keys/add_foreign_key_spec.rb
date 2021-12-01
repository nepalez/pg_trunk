# frozen_string_literal: true

describe ActiveRecord::Migration, "#add_foreign_key" do
  before_all do
    run_migration <<~RUBY
      create_table :roles do |t|
        t.string :name, index: { unique: true }
        t.index %i[name id], unique: true
      end

      create_table :users do |t|
        t.integer :role_id
        t.string  :role_name
        t.string  :role
      end
    RUBY
  end

  context "without options" do
    let(:migration) do
      <<~RUBY.squish
        add_foreign_key "users", "roles"
      RUBY
    end
    let(:invalid_query) do
      <<~Q
        -- breaks fk constraint
        INSERT INTO users (role_id) VALUES (1);
      Q
    end
    let(:valid_query) do
      <<~Q
        INSERT INTO roles (id) VALUES (1);
        INSERT INTO users (role_id) VALUES (1);
      Q
    end

    its(:execution) { is_expected.to enable_sql_request(valid_query) }
    its(:execution) { is_expected.to disable_sql_request(invalid_query) }
    its(:execution) { is_expected.to insert(migration).into_schema }

    its(:inversion) { is_expected.not_to change_schema }
    its(:inversion) { is_expected.to reenable_sql_request(invalid_query) }
  end

  context "with a custom primary key" do
    let(:migration) do
      <<~RUBY.squish
        add_foreign_key "users", "roles", primary_key: "name"
      RUBY
    end
    let(:invalid_query) do
      <<~Q
        -- breaks fk constraint
        INSERT INTO users (role_name) VALUES ('admin');
      Q
    end
    let(:valid_query) do
      <<~Q
        INSERT INTO roles (name) VALUES ('admin');
        INSERT INTO users (role_name) VALUES ('admin');
      Q
    end

    its(:execution) { is_expected.to enable_sql_request(valid_query) }
    its(:execution) { is_expected.to disable_sql_request(invalid_query) }
    its(:execution) { is_expected.to insert(migration).into_schema }

    its(:inversion) { is_expected.to reenable_sql_request(invalid_query) }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "with a custom name" do
    let(:migration) do
      <<~RUBY.squish
        add_foreign_key "users", "roles", name: "user_role_fk"
      RUBY
    end

    its(:execution) { is_expected.to insert(migration).into_schema }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "with cascades" do
    let(:migration) do
      <<~RUBY.squish
        add_foreign_key "users", "roles",
                        on_update: :cascade,
                        on_delete: :restrict
      RUBY
    end

    its(:execution) { is_expected.to insert(migration).into_schema }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "with a multi-key constraint" do
    let(:migration) do
      <<~RUBY.squish
        add_foreign_key "users", "roles",
                        primary_key: %w[name id],
                        match: :full
      RUBY
    end
    let(:invalid_query) do
      <<~Q
        -- breaks fk constraint
        INSERT INTO roles (id, name) VALUES (1, 'admin'), (2, 'developer');
        INSERT INTO users (role_id, role_name) VALUES (1, 'developer');
      Q
    end
    let(:valid_query) do
      <<~Q
        INSERT INTO roles (id, name) VALUES (1, 'developer');
        INSERT INTO users (role_id, role_name) VALUES (1, 'developer');
      Q
    end

    its(:execution) { is_expected.to enable_sql_request(valid_query) }
    its(:execution) { is_expected.to disable_sql_request(invalid_query) }
    its(:execution) { is_expected.to insert(migration).into_schema }

    its(:inversion) { is_expected.to reenable_sql_request(invalid_query) }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "with a custom multi-key constraint" do
    let(:migration) do
      <<~RUBY.squish
        add_foreign_key "users", "roles",
                        columns: %w[role role_id],
                        primary_key: %w[name id],
                        match: :full
      RUBY
    end

    its(:execution) { is_expected.to insert(migration).into_schema }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "with a comment" do
    let(:migration) do
      <<~RUBY
        add_foreign_key "users", "roles", comment: "The user's role"
      RUBY
    end

    its(:execution) { is_expected.to insert(migration).into_schema }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "when foreign key already existed" do
    before do
      run_migration <<~RUBY
        add_foreign_key "users", "roles"
      RUBY
    end

    context "without the `if_not_exists` option" do
      let(:migration) do
        <<~RUBY
          add_foreign_key "users", "roles"
        RUBY
      end

      its(:execution) { is_expected.to raise_error(StandardError) }
    end

    context "with the `if_not_exists: true` option" do
      let(:migration) do
        <<~RUBY
          add_foreign_key "users", "roles", if_not_exists: true
        RUBY
      end

      its(:execution) { is_expected.not_to raise_error }
      it { is_expected.to be_irreversible.because_of(/if_not_exists: true/i) }
    end
  end

  context "without a reference" do
    let(:migration) do
      <<~RUBY.squish
        add_foreign_key "users"
      RUBY
    end

    it { is_expected.to fail_validation.because(/reference can't be blank/i) }
  end

  context "inside table definition" do
    let(:migration) do
      <<~RUBY
        change_table :users do |t|
          t.foreign_key "roles"
        end
      RUBY
    end
    let(:snippet) do
      <<~RUBY.squish
        add_foreign_key "users", "roles"
      RUBY
    end

    its(:execution) { is_expected.to insert(snippet).into_schema }
    its(:inversion) { is_expected.not_to change_schema }
  end
end
