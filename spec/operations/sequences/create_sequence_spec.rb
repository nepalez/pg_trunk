# frozen_string_literal: true

describe ActiveRecord::Migration, "#create_sequence" do
  before_all do
    run_migration <<~RUBY
      create_schema :app

      create_table :customers do |t|
        t.bigint :global_num
      end
    RUBY
  end

  context "with a minimal definition" do
    let(:migration) do
      <<~RUBY
        create_sequence "app.global_num"
      RUBY
    end

    its(:execution) { is_expected.to insert(migration).into_schema }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "with a table-agnostic definition" do
    let(:migration) do
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

    its(:execution) { is_expected.to insert(migration).into_schema }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "with a column-specific definition" do
    let(:migration) do
      <<~RUBY
        create_sequence "global_num" do |s|
          s.owned_by "customers", "global_num"
          s.increment_by 2
          s.min_value 0
          s.max_value 2000
          s.start_with 1
          s.cache 10
          s.cycle true
          s.comment "Sequence for customers global_num"
        end
      RUBY
    end

    its(:execution) { is_expected.to insert(migration).into_schema }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "when the sequence existed" do
    before { run_migration(migration) }

    context "without the `:if_not_exists` option" do
      let(:migration) do
        <<~RUBY
          create_sequence "app.global_num"
        RUBY
      end

      its(:execution) { is_expected.to raise_error(StandardError) }
    end

    context "with the `if_not_exists: true` option" do
      let(:migration) do
        <<~RUBY
          create_sequence "app.global_num", if_not_exists: true
        RUBY
      end
      let(:snippet) do
        <<~RUBY
          create_sequence "app.global_num"
        RUBY
      end

      its(:execution) { is_expected.not_to change_schema }
      it { is_expected.to be_irreversible.because_of(/if_not_exists: true/i) }
    end
  end

  context "with a zero increment" do
    let(:migration) do
      <<~RUBY
        create_sequence "app.global_number", increment_by: 0
      RUBY
    end

    it { is_expected.to fail_validation.because(/increment must not be zero/i) }
  end

  context "with invalid min..max range" do
    let(:migration) do
      <<~RUBY
        create_sequence "app.global_number", min_value: 2, max_value: 1
      RUBY
    end

    it { is_expected.to fail_validation.because(/min value must not exceed max value/i) }
  end

  context "with start value out of min..max range" do
    let(:migration) do
      <<~RUBY
        create_sequence "app.global_number",
                        min_value: 0,
                        max_value: 10,
                        start_with: -1
      RUBY
    end

    it { is_expected.to fail_validation.because(/start value cannot be less than min value/i) }
  end

  context "with a zero cache" do
    let(:migration) do
      <<~RUBY
        create_sequence "app.global_number", cache: 0
      RUBY
    end

    it { is_expected.to fail_validation.because(/cache must be greater than or equal to 1/i) }
  end

  context "with a wrong type" do
    let(:migration) do
      <<~RUBY
        create_sequence "app.global_number", as: "text"
      RUBY
    end

    its(:execution) { is_expected.to raise_error(StandardError) }
  end

  context "without a name" do
    let(:migration) do
      <<~RUBY
        create_sequence
      RUBY
    end

    it { is_expected.to fail_validation.because(/name can't be blank/i) }
  end
end
