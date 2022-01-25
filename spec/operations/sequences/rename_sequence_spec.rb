# frozen_string_literal: true

describe ActiveRecord::Migration, "#rename_sequence" do
  before_all { run_migration "create_schema :seq" }
  before { run_migration(old_snippet) }

  let(:old_snippet) do
    <<~RUBY
      create_sequence "global_num" do |s|
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

  context "with a new name" do
    let(:migration) do
      <<~RUBY
        rename_sequence "global_num", to: "seq.global_number"
      RUBY
    end
    let(:new_snippet) do
      <<~RUBY
        create_sequence "seq.global_number" do |s|
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
    its(:execution) { is_expected.to insert(new_snippet).into_schema }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "when sequence was absent" do
    let(:old_snippet) { "" }

    context "without the `:if_exists` option" do
      let(:migration) do
        <<~RUBY
          rename_sequence "global_num", to: "global_number"
        RUBY
      end

      its(:execution) { is_expected.to raise_error(StandardError) }
    end

    context "with the `if_exists: true` option" do
      let(:migration) do
        <<~RUBY
          rename_sequence "global_num", to: "global_number", if_exists: true
        RUBY
      end

      its(:execution) { is_expected.not_to change_schema }
      it { is_expected.to be_irreversible.because_of(/if_exists: true/i) }
    end
  end

  context "with the same name" do
    let(:migration) do
      <<~RUBY
        rename_sequence "global_num", to: "global_num"
      RUBY
    end

    it { is_expected.to fail_validation.because(/new name must be different/i) }
  end

  context "without new name" do
    let(:migration) do
      <<~RUBY
        rename_sequence "global_num"
      RUBY
    end

    it { is_expected.to fail_validation.because(/new name can't be blank/i) }
  end

  context "without current name" do
    let(:migration) do
      <<~RUBY
        rename_sequence to: "seq.global_number"
      RUBY
    end

    it { is_expected.to fail_validation.because(/name can't be blank/i) }
  end
end
