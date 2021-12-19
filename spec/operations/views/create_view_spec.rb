# frozen_string_literal: true

describe ActiveRecord::Migration, "#create_view" do
  before_all do
    run_migration <<~RUBY
      create_table "users", force: :cascade do |t|
        t.string "name"
        t.boolean "admin"
      end
    RUBY
  end

  # from /spec/dummy/db/views/admin_users_v01.sql
  let(:snippet) do
    <<~RUBY
      create_view "admin_users" do |v|
        v.sql_definition <<~Q.chomp
          SELECT users.id, users.name
          FROM users
          WHERE users.admin
        Q
      end
    RUBY
  end

  context "when a view was absent" do
    let(:migration) do
      <<~RUBY
        create_view "admin_users" do |v|
          v.sql_definition <<~Q.chomp
            SELECT users.id, users.name
            FROM users
            WHERE users.admin
          Q
          v.check :local
          v.comment "Admin users only"
        end
      RUBY
    end
    let(:query) { "SELECT * FROM admin_users;" }

    its(:execution) { is_expected.to enable_sql_request(query) }
    its(:execution) { is_expected.to insert(migration).into_schema }

    its(:inversion) { is_expected.to disable_sql_request(query) }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "when a view was present" do
    before do
      run_migration <<~RUBY
        create_view "admin_users", sql_definition: "SELECT id, name FROM users"
      RUBY
    end

    context "without the `replace_existing` option" do
      let(:migration) do
        <<~RUBY
          create_view "admin_users" do |v|
            v.sql_definition <<~Q.chomp
              SELECT users.id, users.name
              FROM users
              WHERE users.admin
            Q
            v.check :local
            v.comment "Admin users only"
          end
        RUBY
      end

      its(:execution) { is_expected.to raise_error(StandardError) }
    end

    context "with the `replace_existing: true` option" do
      let(:migration) do
        <<~RUBY
          create_view "admin_users", replace_existing: true do |v|
            v.sql_definition <<~Q.chomp
              SELECT users.id, users.name
              FROM users
              WHERE users.admin
            Q
          end
        RUBY
      end

      its(:execution) { is_expected.to insert(snippet).into_schema }
      it { is_expected.to be_irreversible.because_of(/replace_existing: true/i) }
    end
  end

  context "without sql definition" do
    context "with an existing version" do
      let(:migration) do
        <<~RUBY
          create_view "admin_users", version: 1
        RUBY
      end

      its(:execution) { is_expected.to insert(snippet).into_schema }
      its(:inversion) { is_expected.not_to change_schema }
    end

    context "with an absent version" do
      let(:migration) do
        <<~RUBY
          create_view "admin_users", version: 99
        RUBY
      end

      its(:execution) { is_expected.to raise_error(StandardError) }
    end

    context "without version" do
      let(:migration) do
        <<~RUBY
          create_view "admin_users"
        RUBY
      end

      it { is_expected.to fail_validation.because(/sql definition can't be blank/i) }
    end
  end

  context "without a name" do
    let(:migration) do
      <<~RUBY
        create_view sql_definition: "SELECT * FROM users"
      RUBY
    end

    it { is_expected.to fail_validation.because(/name can't be blank/i) }
  end
end
