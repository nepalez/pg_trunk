# frozen_string_literal: true

# @private
# Ensure that all items in the array are valid
class PGExtra::AllItemsValidValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    Array.wrap(value).each.with_index.map do |item, index|
      item.errors.messages.each do |name, list|
        list.each do |message|
          record.errors.add :base, "#{attribute}[#{index}]: #{name} #{message}"
        end
      end
    end
  end
end
