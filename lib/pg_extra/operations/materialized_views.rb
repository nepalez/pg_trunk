# frozen_string_literal: true

# nodoc
module PGExtra::Definitions
  # Namespace for operations with materialized views
  module MaterializedViews
    require_relative "materialized_views/column"
    require_relative "materialized_views/base"

    require_relative "materialized_views/change_materialized_view"
    require_relative "materialized_views/create_materialized_view"
    require_relative "materialized_views/drop_materialized_view"
    require_relative "materialized_views/refresh_materialized_view"
    require_relative "materialized_views/rename_materialized_view"
  end
end
