# frozen_string_literal: true

describe ActiveRecord::Migration, "#rename_domain" do
  before_all { run_migration "create_schema :dict" }
  before { run_migration(old_snippet) }

  let(:old_snippet) do
    <<~RUBY
      create_domain "existing_string", as: "text" do |d|
        d.null false
      end
    RUBY
  end
  let(:old_query) { "SELECT 'foo'::existing_string;" }

  context "with new name and schema" do
    let(:migration) do
      <<~RUBY
        rename_domain "existing_string", to: "dict.present_string"
      RUBY
    end
    let(:new_snippet) do
      <<~RUBY
        create_domain "dict.present_string", as: "text" do |d|
          d.null false
        end
      RUBY
    end
    let(:new_query) { "SELECT 'USD'::dict.present_string;" }

    its(:execution) { is_expected.to enable_sql_request(new_query) }
    its(:execution) { is_expected.to disable_sql_request(old_query) }
    its(:execution) { is_expected.to remove(old_snippet).from_schema }
    its(:execution) { is_expected.to insert(new_snippet).into_schema }

    its(:inversion) { is_expected.to disable_sql_request(new_query) }
    its(:inversion) { is_expected.to enable_sql_request(old_query) }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "with the same name and schema" do
    let(:migration) do
      <<~RUBY
        rename_domain "existing_string", to: "public.existing_string"
      RUBY
    end

    it { is_expected.to fail_validation.because(/new name must be different/i) }
  end

  context "without new schema/name" do
    let(:migration) do
      <<~RUBY
        rename_domain "existing_string"
      RUBY
    end

    it { is_expected.to fail_validation.because(/new name can't be blank/i) }
  end

  context "without current name" do
    let(:migration) do
      <<~RUBY
        rename_domain to: "dict.present_string"
      RUBY
    end

    it { is_expected.to fail_validation.because(/name can't be blank/i) }
  end
end
