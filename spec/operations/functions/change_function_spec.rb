# frozen_string_literal: true

describe ActiveRecord::Migration, "#change_function" do
  before do
    run_migration <<~RUBY
      create_function "mult(a integer, b integer) integer" do |f|
        f.volatility :immutable
        f.body "SELECT a * b"
      end

      # Overload the function to ensure a proper one is found
      create_function "mult(a int, b int, c int) int",
                      body: "SELECT a * b * c"

      # Use the function to ensure it can be chanded
      # even though it has dependent objects.
      create_table "sums" do |t|
        t.integer :a
        t.integer :b
        t.index "mult(a, b)"
      end
    RUBY
  end

  let(:old_snippet) do
    <<~RUBY
      create_function "mult(a integer, b integer) integer" do |f|
        f.volatility :immutable
        f.body "SELECT a * b"
      end
    RUBY
  end

  context "with implicitly reversible changes" do
    let(:migration) do
      <<~RUBY
        change_function "mult(integer, integer)" do |f|
          f.strict true
          f.leakproof true
          f.security :definer
        end
      RUBY
    end
    let(:new_snippet) do
      <<~RUBY
        create_function "mult(a integer, b integer) integer" do |f|
          f.volatility :immutable
          f.leakproof true
          f.strict true
          f.security :definer
          f.body "SELECT a * b"
        end
      RUBY
    end

    its(:execution) { is_expected.to insert(new_snippet).into_schema }
    its(:execution) { is_expected.to remove(old_snippet).from_schema }
    its(:inversion) { is_expected.not_to change_schema }
  end

  context "with explicitly reversible changes" do
    let(:migration) do
      <<~RUBY
        change_function "mult(integer, integer)" do |f|
          f.parallel :safe, from: :unsafe
          f.body <<~Q, from: <<~Q
            SELECT a + b
          Q
            SELECT a * b
          Q
        end
      RUBY
    end
    let(:new_snippet) do
      <<~RUBY
        create_function "mult(a integer, b integer) integer" do |f|
          f.volatility :immutable
          f.parallel :safe
          f.body "SELECT a + b"
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
        change_function "mult(integer, integer)" do |f|
          f.strict true
          f.leakproof true
          f.security :definer
          f.parallel :safe
          f.cost 5.0
        end
      RUBY
    end
    let(:new_snippet) do
      <<~RUBY
        create_function "mult(a integer, b integer) integer" do |f|
          f.volatility :immutable
          f.leakproof true
          f.strict true
          f.security :definer
          f.parallel :safe
          f.cost 5.0
          f.body "SELECT a * b"
        end
      RUBY
    end

    its(:execution) { is_expected.to insert(new_snippet).into_schema }
    its(:execution) { is_expected.to remove(old_snippet).from_schema }
    it { is_expected.to be_irreversible.because_of(/parallel|cost/i) }
  end

  context "with no changes" do
    let(:migration) do
      <<~RUBY
        change_function "mult(integer, integer)"
      RUBY
    end

    it { is_expected.to fail_validation.because(/changes can't be blank/i) }
  end

  context "when the function is absent" do
    let(:migration) do
      <<~RUBY
        change_function "unknown(integer)" do |f|
          f.comment "New comment"
        end
      RUBY
    end

    context "without the `if_exists` option" do
      its(:execution) { is_expected.to raise_error(StandardError) }
    end

    context "with the `if_exists: true` option" do
      let(:migration) do
        <<~RUBY
          change_function "unknown(integer)", if_exists: true do |f|
            f.comment "New comment"
          end
        RUBY
      end

      its(:execution) { is_expected.not_to change_schema }
      it { is_expected.to be_irreversible.because_of(/if_exists: true/i) }
    end
  end

  context "without name" do
    let(:migration) do
      <<~RUBY
        change_function strict: true
      RUBY
    end

    it { is_expected.to fail_validation.because(/name can't be blank/i) }
  end
end
