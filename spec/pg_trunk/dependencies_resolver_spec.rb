# frozen_string_literal: true

# noinspection RubyResolve
require "spec_helper"

RSpec.describe PGTrunk::DependenciesResolver do
  subject { described_class.resolve(input).map(&:oid) }

  let(:input) { (1..10).map { |oid| object.new(oid) }.freeze }
  # For simplicity we presume objects are sorted by oid
  let(:object) do
    Struct.new(:oid) do
      include Comparable

      def <=>(other)
        oid <=> other.oid
      end
    end
  end

  before do
    # We mock the method here to avoid polluting the `pg_depend` catalog.
    allow(described_class).to receive(:dependencies).and_return(dependencies)
  end

  describe "List of independent objects" do
    let(:dependencies) { {} }
    let(:output) { (1..10).to_a }

    it "restores the natural order" do
      expect(subject).to eq(output)
    end
  end

  describe "List of dependent objects" do
    let(:dependencies) { { 2 => [7], 3 => [5], 5 => [8] } }
    let(:output) { [1, 7, 2, 8, 5, 3, 4, 6, 9, 10] }

    it "is sorted so that dependencies are resolved" do
      expect(subject).to eq(output)
    end
  end
end
