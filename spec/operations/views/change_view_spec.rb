# frozen_string_literal: true

describe ActiveRecord::Migration, "#change_view" do
  before_all do
    run_migration <<~RUBY
      create_table "users", force: :cascade do |t|
        t.string "name"
        t.boolean "admin"
      end
    RUBY
  end
  before { run_migration(old_snippet) }

  let(:old_snippet) do
    <<~RUBY
      create_view "admin_users" do |v|
        v.sql_definition <<~Q.chomp
          SELECT users.id, users.name
          FROM users
          WHERE users.admin
        Q
        v.check :local
        v.comment "Old comment"
      end
    RUBY
  end
  let(:new_snippet) do
    <<~RUBY
      create_view "admin_users" do |v|
        v.sql_definition <<~Q.chomp
          SELECT NULL::bigint AS id, users.name
          FROM users
          WHERE users.admin
        Q
        v.check :cascaded
        v.comment "New comment"
      end
    RUBY
  end

  context "with explicitly reversible inline changes" do
    let(:migration) do
      <<~RUBY
        change_view "admin_users" do |v|
          v.sql_definition <<~Q.chomp, from: <<~Q.chomp
            -- the column can be nullified but neither deleted nor retyped
            SELECT NULL::bigint AS id, users.name
            FROM users
            WHERE users.admin
          Q
            SELECT users.id, users.name
            FROM users
            WHERE users.admin
          Q
          v.check :cascaded, from: :local
          v.comment "New comment", from: "Old comment"
        end
      RUBY
    end

    its(:execution) { is_expected.to insert(new_snippet).into_schema }
    its(:execution) { is_expected.to remove(old_snippet).from_schema }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "with explicitly reversible version changes" do
    let(:migration) do
      <<~RUBY
        change_view "admin_users" do |v|
          v.version 2, from: 1
          v.check :cascaded, from: :local
          v.comment "New comment", from: "Old comment"
        end
      RUBY
    end

    its(:execution) { is_expected.to insert(new_snippet).into_schema }
    its(:execution) { is_expected.to remove(old_snippet).from_schema }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "with irreversible changes" do
    let(:migration) do
      <<~RUBY
        change_view "admin_users" do |v|
          v.version 2
          v.check :cascaded
          v.comment "New comment"
        end
      RUBY
    end

    its(:execution) { is_expected.to insert(new_snippet).into_schema }
    its(:execution) { is_expected.to remove(old_snippet).from_schema }
    it { is_expected.to be_irreversible.because_of(/version|check|comment/i) }
  end

  context "with no changes" do
    let(:migration) do
      <<~RUBY
        change_view "admin_users"
      RUBY
    end

    it { is_expected.to fail_validation.because(/changes can't be blank/i) }
  end

  context "when the view is absent" do
    let(:migration) do
      <<~RUBY
        change_view "unknown" do |v|
          v.comment "New comment"
        end
      RUBY
    end

    context "without the `if_exists` option" do
      its(:execution) { is_expected.to raise_error(StandardError) }
    end

    context "with the `if_exists: true` option" do
      let(:migration) do
        <<~RUBY
          change_view "unknown(integer)", if_exists: true do |v|
            v.comment "New comment"
          end
        RUBY
      end

      its(:execution) { is_expected.not_to change_schema }
      it { is_expected.to be_irreversible.because_of(/if_exists: true/i) }
    end
  end

  context "without view name" do
    let(:migration) do
      <<~RUBY
        change_view check: :cascaded
      RUBY
    end

    it { is_expected.to fail_validation.because(/name can't be blank/i) }
  end
end
