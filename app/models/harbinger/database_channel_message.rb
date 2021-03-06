require 'active_record'
require 'harbinger/database_channel_message_element'

module Harbinger
  class DatabaseChannelMessage < ActiveRecord::Base
    self.table_name = 'harbinger_messages'
    has_many :elements, class_name: 'Harbinger::DatabaseChannelMessageElement', foreign_key: :message_id

    def reporters=(values)
      super(Array.wrap(values).join(','))
    end

    def reporters
      super.split(',')
    end

    def self.store_message(message, storage = new)
      storage.reporters = message.reporters
      storage.state = 'new'
      storage.message_object_id = message.object_id
      message.attributes.each do |key, value|
        storage.elements.build(key: key, value: value)
      end
      storage.save!
    end

    def self.search(params = {})
      search_text(params[:q]).
        search_state(params[:state]).
        ordered
    end

    # Search the message and its elements for the matching text.
    scope :search_text, lambda { |text|
      if text
        where(
          arel_table[:reporters].matches("#{text}%").
          or(
            arel_table[:message_object_id].eq(text).
            or(
              arel_table[:id].
              in(Arel::SqlLiteral.new(DatabaseChannelMessageElement.search_text(text).select(:message_id).to_sql))
            )
          )
        )
      else
        all
      end
    }

    scope :search_state, ->(state) { state ? where(arel_table[:state].eq(state)) : all }

    scope :ordered, -> { order(arel_table[:created_at].desc) }
  end
end
