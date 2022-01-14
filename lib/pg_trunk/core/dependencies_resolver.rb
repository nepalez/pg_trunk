# frozen_string_literal: true

module PGTrunk
  # @private
  # Resolve dependencies between inter-dependent objects,
  # identified by database `#oid` and comparable to each other.
  #
  # The method builds the sorted list:
  # - parent objects moved before their dependants.
  # - independent objects keeps their original order.
  #
  # We have no expectations about the natural order here.
  # @see [PGTrunk::Operation]
  class DependenciesResolver
    class << self
      # Resolve dependencies between objects
      # @param  [Array<Enumerable, #oid>] objects The list of objects
      # @return [Array<#oid>] The sorted list of objects
      # @raise  [Dependencies::CycleError] if dependencies contain a cycle
      def resolve(objects)
        new(objects, dependencies).send(:sorted)
      end

      private

      def query
        <<~SQL.squish
          SELECT child, array_agg(parent) AS parents
          FROM (
            SELECT
              d.objid AS child,
              d.refobjid AS parent
            FROM pg_depend d
              JOIN pg_trunk e1 ON d.objid = e1.oid
              JOIN pg_trunk e2 ON d.refobjid = e2.oid
            WHERE d.objsubid IS NULL
          ) dependencies
          GROUP BY child;
        SQL
      end

      # Extract dependencies between given oids from the database
      def dependencies
        ActiveRecord::Base
          .connection
          .execute(query)
          .each_with_object({}) do |i, obj|
            child = i["child"].to_i
            parents = i["parents"].scan(/\d+/).map(&:to_i)
            obj[child] = parents.uniq
          end
      end
    end

    private

    # @param [Array<Comparable, #oid>] objects Objects to sort
    # @param [Hash<{Integer => Array<Integer>}] parents Dependencies between oid-s
    def initialize(objects, parents)
      @objects = objects
      @parents = parents.transform_values do |oids|
        # preserve the original order of objects
        objects.each_with_object([]) do |obj, list|
          list << obj if oids.include?(obj.oid)
        end
      end
    end

    attr_reader :objects, :parents

    def visited
      @visited ||= {}
    end

    def index
      @index ||= objects.each_with_object({}) { |obj, idx| idx[obj.oid] = obj }
    end

    # Use topological sorting algorithm to resolve dependencies
    # @return [Array<#oid>]
    def sorted
      @sorted ||= [].tap do |output|
        while (object = next_unvisited)
          visit(object, output)
        end
      end
    end

    def next_unvisited
      objects.find { |object| !visited[object.oid] }
    end

    def visit(object, output)
      return if visited[object.oid]

      parents[object.oid]&.each { |parent| visit(parent, output) }
      visited[object.oid] = true
      output << object
    end
  end
end
