# frozen_string_literal: true

describe ActiveRecord::Migration, "#change_procedure", since_version: 11 do
  before do
    run_migration <<~RUBY
      create_procedure "set_foo(a integer)" do |p|
        p.language "plpgsql"
        p.body "BEGIN set custom.foo = a; END;"
        p.comment "Set foo"
      end

      # Overload the procedure to ensure a proper one is found
      create_procedure "set_foo(a text)",
                       language: "plpgsql",
                       body: "BEGIN set custom.foo = a; END;"
    RUBY
  end

  let(:old_snippet) do
    <<~RUBY
      create_procedure "set_foo(a integer)" do |p|
        p.language "plpgsql"
        p.body "BEGIN set custom.foo = a; END;"
        p.comment "Set foo"
      end
    RUBY
  end

  context "with implicitly reversible changes" do
    let(:migration) do
      <<~RUBY
        change_procedure "set_foo(a integer)", security: :definer
      RUBY
    end
    let(:new_snippet) do
      <<~RUBY
        create_procedure "set_foo(a integer)" do |p|
          p.language "plpgsql"
          p.security :definer
          p.body "BEGIN set custom.foo = a; END;"
          p.comment "Set foo"
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
        change_procedure "set_foo(a integer)" do |p|
          p.body <<~PLPGSQL.chomp, from: <<~PLPGSQL.chomp
            DECLARE
              b integer := 2 * a;
            BEGIN
              set custom.foo = b;
            END;
          PLPGSQL
            BEGIN set custom.foo = a; END;
          PLPGSQL
          p.comment "Set doubled value to foo", from: "Set foo"
        end
      RUBY
    end
    let(:new_snippet) do
      <<~RUBY
        create_procedure "set_foo(a integer)" do |p|
          p.language "plpgsql"
          p.body <<~Q.chomp
            DECLARE
            b integer := 2 * a;
            BEGIN
            set custom.foo = b;
            END;
          Q
          p.comment "Set doubled value to foo"
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
        change_procedure "set_foo(a integer)" do |p|
          p.body <<~PLPGSQL.chomp
            DECLARE
              b integer := 2 * a;
            BEGIN
              set custom.foo = b;
            END;
          PLPGSQL
          p.comment "Set doubled value to foo"
        end
      RUBY
    end
    let(:new_snippet) do
      <<~RUBY
        create_procedure "set_foo(a integer)" do |p|
          p.language "plpgsql"
          p.body <<~Q.chomp
            DECLARE
            b integer := 2 * a;
            BEGIN
            set custom.foo = b;
            END;
          Q
          p.comment "Set doubled value to foo"
        end
      RUBY
    end

    its(:execution) { is_expected.to insert(new_snippet).into_schema }
    its(:execution) { is_expected.to remove(old_snippet).from_schema }
    it { is_expected.to be_irreversible.because_of(/body|comment/i) }
  end

  context "with no changes" do
    let(:migration) do
      <<~RUBY
        change_procedure "set_foo(a integer)"
      RUBY
    end

    it { is_expected.to fail_validation.because(/changes can't be blank/i) }
  end

  context "when the procedure is absent" do
    let(:migration) do
      <<~RUBY
        change_procedure "unknown(integer)" do |p|
          p.comment <<~COMMENT
            New comment
          COMMENT
        end
      RUBY
    end

    context "without the `if_exists` option" do
      its(:execution) { is_expected.to raise_error(StandardError) }
    end

    context "with the `if_exists: true` option" do
      let(:migration) do
        <<~RUBY
          change_procedure "unknown(integer)", if_exists: true do |p|
            p.comment <<~COMMENT
              New comment
            COMMENT
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
        change_procedure security: :invoker
      RUBY
    end

    it { is_expected.to fail_validation.because(/name can't be blank/i) }
  end
end
