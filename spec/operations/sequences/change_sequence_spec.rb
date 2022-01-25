# frozen_string_literal: true

describe ActiveRecord::Migration, "#change_sequence" do
  before { run_migration(old_snippet) }

  let(:old_snippet) do
    <<~RUBY
      create_sequence "global_num", as: "integer" do |s|
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

  context "with reversible changes" do
    let(:migration) do
      <<~RUBY
        change_sequence "global_num" do |s|
          s.type "bigint", from: "integer"
          s.increment_by 3, from: 2
          s.min_value 1, from: 0
          s.max_value 3000, from: 2000
          s.start_with 2, from: 1
          s.cache 20, from: 10
          s.cycle false
          s.comment "Global numbers", from: "Sequence for global numbers (odds then evens)"
        end
      RUBY
    end
    let(:new_snippet) do
      <<~RUBY
        create_sequence "global_num" do |s|
          s.increment_by 3
          s.max_value 3000
          s.start_with 2
          s.cache 20
          s.comment "Global numbers"
        end
      RUBY
    end

    its(:execution) { is_expected.to remove(old_snippet).from_schema }
    its(:execution) { is_expected.to insert(new_snippet).into_schema }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "with irreversible changes" do
    let(:migration) do
      <<~RUBY
        change_sequence "global_num" do |s|
          s.type "bigint"
          s.increment_by 3
          s.min_value 1
          s.max_value 3000
          s.start_with 2
          s.cache 20
          s.cycle false
          s.comment "Global numbers"
        end
      RUBY
    end
    let(:new_snippet) do
      <<~RUBY
        create_sequence "global_num" do |s|
          s.increment_by 3
          s.max_value 3000
          s.start_with 2
          s.cache 20
          s.comment "Global numbers"
        end
      RUBY
    end

    its(:execution) { is_expected.to remove(old_snippet).from_schema }
    its(:execution) { is_expected.to insert(new_snippet).into_schema }
    it { is_expected.to be_irreversible.because_of(/undefined values to revert/i) }
  end

  context "when sequence was absent" do
    let(:old_snippet) { "" }

    context "without the `:if_exists` option" do
      let(:migration) do
        <<~RUBY
          change_sequence "global_num" do |s|
            s.comment "Global numbers"
          end
        RUBY
      end

      its(:execution) { is_expected.to raise_error(StandardError) }
    end

    context "with the `if_exists: true` option" do
      let(:migration) do
        <<~RUBY
          change_sequence "global_num", if_exists: true do |s|
            s.comment "Global numbers"
          end
        RUBY
      end

      its(:execution) { is_expected.not_to change_schema }
      it { is_expected.to be_irreversible.because_of(/if_exists: true/i) }
    end
  end

  context "without changes" do
    let(:migration) do
      <<~RUBY
        change_sequence "global_num"
      RUBY
    end

    it { is_expected.to fail_validation.because(/changes can't be blank/i) }
  end

  context "without a name" do
    let(:migration) do
      <<~RUBY
        change_sequence do |s|
          s.comment "Global numbers"
        end
      RUBY
    end

    it { is_expected.to fail_validation.because(/name can't be blank/i) }
  end
end
