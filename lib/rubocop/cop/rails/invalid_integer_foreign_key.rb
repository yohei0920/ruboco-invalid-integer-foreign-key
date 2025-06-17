# frozen_string_literal: true

module RuboCop
  module Cop
    module Rails
      # This cop checks for foreign key type mismatches in db/schema.rb.
      # It detects when a table uses `t.integer :xxx_id` but the referenced
      # table's primary key is `bigint` (Rails 7+ default).
      #
      # @example
      #   # bad
      #   create_table "applications", force: :cascade do |t|
      #     t.bigint "id", null: false
      #     t.string "name"
      #   end
      #
      #   create_table "device_settings", force: :cascade do |t|
      #     t.integer "application_id" # ← warning
      #     t.string "setting_name"
      #   end
      #
      #   # good
      #   create_table "applications", force: :cascade do |t|
      #     t.bigint "id", null: false
      #     t.string "name"
      #   end
      #
      #   create_table "device_settings", force: :cascade do |t|
      #     t.bigint "application_id" # ← correct
      #     t.string "setting_name"
      #   end
      class InvalidIntegerForeignKey < Base
        extend AutoCorrector

        MSG = '外部キーが参照するテーブルの主キーがbigint型の場合、外部キーにbigint型を使用してください。'

        def initialize(*args)
          super
          @table_pk_types = {}
        end

        def on_send(node)
          return unless node.method_name == :create_table

          table_name_node = node.arguments.first
          return unless table_name_node&.str_type?

          table_name = table_name_node.value
          pk_type = extract_pk_type(node)
          @table_pk_types[table_name] = pk_type

          block = node.block_node
          check_integer_foreign_keys(block) if block
        end

        private

        def extract_pk_type(node)
          node.arguments.each do |arg|
            next unless arg.hash_type?

            pk_type = extract_pk_type_from_hash(arg)
            return pk_type if pk_type
          end

          # Default to bigint
          :bigint
        end

        def extract_pk_type_from_hash(hash_node)
          hash_node.each_pair do |key, value|
            next unless key.sym_type? && key.value == :id
            next unless value.sym_type?

            return :integer if value.value == :integer
            return :bigint if value.value == :bigint
          end
          nil
        end

        def check_integer_foreign_keys(block_node)
          block_node.body&.each_node(:send) do |send_node|
            next unless send_node.method_name == :integer

            check_integer_foreign_key(send_node)
          end
        end

        def check_integer_foreign_key(send_node)
          fk_name = send_node.arguments.first.value
          return unless fk_name&.end_with?('_id')

          referenced_table = extract_referenced_table(fk_name)
          return unless referenced_table

          # Check if referenced table has bigint primary key
          referenced_pk_type = @table_pk_types[referenced_table]
          return unless referenced_pk_type == :bigint

          add_offense(send_node, message: MSG) do |corrector|
            corrector.replace(send_node.loc.expression, send_node.source.sub('integer', 'bigint'))
          end
        end

        def extract_referenced_table(fk_name)
          base = fk_name.chomp('_id')
          if base.end_with?('y')
            "#{base[0..-2]}ies"
          else
            "#{base}s"
          end
        end
      end
    end
  end
end
