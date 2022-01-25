# frozen_string_literal: true

describe ActiveRecord::Migration, "#drop_sequence" do
  before_all { run_migration("create_schema :app") }
  before { run_migration(old_snippet) }

  let(:old_snippet) do
    <<~RUBY
      create_sequence "app.global_num", as: "integer" do |s|
        s.increment_by 2
        s.min_value 0
        s.max_value 2000
        s.start_with 1
        s.cache 10
        s.cycle true
        s.comment "Sequence for global numbers (odds then evens)"
      end
    RUBY
  end

  context "with a full definition" do
    let(:migration) do
      <<~RUBY
        drop_sequence "app.global_num", as: "integer" do |s|
          s.increment_by 2
          s.min_value 0
          s.max_value 2000
          s.start_with 1
          s.cache 10
          s.cycle true
          s.comment "Sequence for global numbers (odds then evens)"
        end
      RUBY
    end

    its(:execution) { is_expected.to remove(old_snippet).from_schema }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "with a minimal definition" do
    let(:migration) do
      <<~RUBY
        drop_sequence "app.global_num"
      RUBY
    end
    let(:new_snippet) do
      <<~RUBY
        create_sequence "app.global_num"
      RUBY
    end

    its(:execution) { is_expected.to remove(old_snippet).from_schema }
    its(:inversion) { is_expected.to remove(old_snippet).from_schema }
    its(:inversion) { is_expected.to insert(new_snippet).into_schema }
  end

  context "when the sequence was absent" do
    before { run_migration(migration) }

    context "without the `:if_exists` option" do
      let(:migration) do
        <<~RUBY
          drop_sequence "app.global_num"
        RUBY
      end

      its(:execution) { is_expected.to raise_error(StandardError) }
    end

    context "with the `if_exists: true` option" do
      let(:migration) do
        <<~RUBY
          drop_sequence "app.global_num", if_exists: true
        RUBY
      end

      its(:execution) { is_expected.not_to change_schema }
      it { is_expected.to be_irreversible.because_of(/if_exists: true/i) }
    end
  end

  context "with the force: :cascade option" do
    let(:migration) do
      <<~RUBY
        drop_sequence "app.global_num", force: :cascade
      RUBY
    end

    its(:execution) { is_expected.to remove(old_snippet).from_schema }
    it { is_expected.to be_irreversible.because_of(/force: :cascade/i) }
  end

  context "without a name" do
    let(:migration) do
      <<~RUBY
        drop_sequence
      RUBY
    end

    it { is_expected.to fail_validation.because(/name can't be blank/i) }
  end
end
