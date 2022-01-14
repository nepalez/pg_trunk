# frozen_string_literal: false

module PGTrunk::Operations::Aggregates
  #
  # Definition for the `create_aggregate` operation
  #
  # The aggregate can be created with a lot of settings:
  #
  class CreateAggregate < Base
    validates :if_exists, :force, absence: true
    validates :sfunc, :stype, presence: true

    from_sql do |version|
      modifiers = <<~SQL.strip if version >= "11"
        (
          CASE
          WHEN a.aggfinalmodify = 's' THEN 'shareable'
          WHEN a.aggfinalmodify = 'w' THEN 'read_write'
          END
        ) AS fmodify,
        (
          CASE
          WHEN a.aggfinalmodify = 's' THEN 'shareable'
          WHEN a.aggfinalmodify = 'w' THEN 'read_write'
          END
        ) AS mfinalfunc_modify,
      SQL

      <<~SQL
        SELECT
          p.oid,
          (
            p.pronamespace::regnamespace || '.' ||
            p.proname ||
            '(' || pg_get_function_identity_arguments(p.oid) || ')'
          ) AS name,
          (CASE WHEN a.aggkind = 'h' THEN true END) AS hypothetical,
          a.aggtransfn::regproc AS sfunc,
          (
            CASE
            WHEN p.proparallel = 's' THEN 'safe'
            WHEN p.proparallel = 'r' THEN 'restricted'
            END
          ) AS parallel,
          (
            CASE WHEN a.aggtranstype != 0 THEN a.aggtranstype::regtype END
          ) AS stype,
          a.aggtransspace AS sspace,
          (
            CASE WHEN a.aggfinalfn != 0 THEN a.aggfinalfn::regproc END
          ) AS ffunc,
          (
            CASE WHEN a.aggfinalextra THEN true END
          ) AS fextra,
          a.agginitval AS initcond,
          (
            CASE WHEN a.aggmtransfn != 0 THEN a.aggmtransfn::regproc END
          ) AS msfunc,
          (
            CASE WHEN a.aggminvtransfn != 0 THEN a.aggminvtransfn::regproc END
          ) AS minvfunc,
          (
            CASE WHEN a.aggmtranstype != 0 THEN a.aggmtranstype::regtype END
          ) AS mstype,
          a.aggmtransspace AS msspace,
          (
            CASE WHEN a.aggmfinalfn != 0 THEN a.aggmfinalfn::regproc END
          ) AS mfinalfunc,
          (
            CASE WHEN a.aggmfinalextra THEN true END
          ) AS mfinalfunc_extra,
          a.aggminitval AS minitcond,
          (
            CASE WHEN a.aggserialfn != 0 THEN a.aggserialfn::regproc END
          ) AS serial_func,
          (
            CASE WHEN a.aggdeserialfn != 0 THEN a.aggdeserialfn::regproc END
          ) AS deserial_func,
          (
            CASE WHEN a.aggcombinefn != 0 THEN a.aggcombinefn::regproc END
          ) AS combine_function,
          (
            CASE WHEN a.aggsortop != 0 THEN a.aggsortop::regoperator END
          ) AS sort_operator,
          #{modifiers&.indent(2)}
          d.description AS comment
        FROM pg_aggregate a
          JOIN pg_proc p ON p.oid = a.aggfnoid
          JOIN pg_trunk e ON e.oid = p.oid AND e.classid = 'pg_proc'::regclass
          LEFT JOIN pg_description d ON d.objoid = p.oid
      SQL
    end

    def to_sql(version)
      [
        create_aggregate(version),
        *comment_aggregate,
        register_aggregate(version),
      ].join(" ")
    end

    def invert
      irreversible!("replace_existing: true") if replace_existing
      DropAggregate.new(**to_h)
    end

    private

    def create_aggregate(version)
      sql = "CREATE"
      sql << " OR REPLACE" if replace_existing && version >= "12"
      sql << " AGGREGATE #{name.schema.inspect}.#{name.routine.inspect}"
      sql << "(#{name.args}"
      sql << " ORDER BY #{order_by}" if order_by.present?
      sql << ") (SFUNC = #{sfunc.inspect}"
      sql << ", STYPE = #{stype.inspect}"
      sql << ", SSPACE = #{sspace.to_i}" if sspace&.positive?
      sql << ", FINALFUNC = #{ffunc.inspect}" if ffunc.present?
      sql << ", FINALFUNC_EXTRA" if fextra
      sql << ", FINALFUNC_MODIFY = #{fmodify.to_s.upcase}" if fmodify.present?
      sql << ", COMBINEFUNC = #{combine_function.inspect}" if combine_function.present?
      sql << ", SERIALFUNC = #{serial_func.inspect}" if serial_func.present?
      sql << ", DESERIALFUNC = #{deserial_func.inspect}" if deserial_func.present?
      sql << ", INITCOND = #{initcond}" if initcond.present?
      sql << ", MSFUNC = #{msfunc.inspect}" if msfunc.present?
      sql << ", MINVFUNC = #{minvfunc.inspect}" if minvfunc.present?
      sql << ", MSTYPE = #{mstype.inspect}" if mstype.present?
      sql << ", MSSPACE = #{msspace.to_i}" if msspace&.positive?
      sql << ", MFINALFUNC = #{mfinalfunc.inspect}" if mfinalfunc.present?
      sql << ", MFINALFUNC_EXTRA" if mfinalfunc_extra
      sql << ", MFINALFUNC_MODIFY = #{mfinalfunc_modify.to_s.upcase}" if mfinalfunc_modify.present?
      sql << ", MINITCOND = #{minitcond}" if minitcond.present?
      sql << ", SORTOP = #{sort_operator.to_sql}" if sort_operator.present?
      sql << ", PARALLEL = SAFE" if parallel == :safe
      sql << ", PARALLEL = RESTRICTED" if parallel == :restricted
      sql << ", HYPOTHETICAL" if hypothetical
      sql << ");"
    end

    def comment_aggregate
      return if comment.blank?

      "COMMENT ON AGGREGATE #{name.to_sql} IS $comment$#{comment}$comment$;"
    end

    # Register the most recent `oid` of aggregates with this schema/name
    # There can be several overloaded definitions, but we're interested
    # in that one we created just now so we can skip checking its args.
    def register_aggregate(version)
      <<~SQL.squish
        WITH latest AS (
          SELECT
            oid,
            (proname = #{name.quoted} AND pronamespace = #{name.namespace}) AS ok
          FROM pg_proc
          WHERE #{version < '12' ? 'proisagg' : "prokind = 'a'"}
          ORDER BY oid DESC LIMIT 1
        )
        INSERT INTO pg_trunk (oid, classid)
          SELECT oid, 'pg_proc'::regclass
          FROM latest
          WHERE ok
          ON CONFLICT DO NOTHING;
      SQL
    end
  end
end
