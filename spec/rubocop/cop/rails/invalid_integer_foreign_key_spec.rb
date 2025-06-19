# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RuboCop::Cop::Rails::InvalidIntegerForeignKey, :config do
  let(:config) do
    RuboCop::Config.new(
      'Rails/InvalidIntegerForeignKey' => {
        'Enabled' => true,
        'Include' => ['**/*.rb']
      }
    )
  end

  let(:cop) { described_class.new(config) }

  describe '外部キーと主キーの型の整合性チェック' do
    context '外部キー型が参照テーブルと一致する場合' do
      it 'bigint主キーを持つテーブルに対してbigint外部キーを使用している場合は、警告を出さない', aggregate_failures: true do
        expect_no_offenses(<<~RUBY)
          create_table "applications", force: :cascade do |t|
            t.string "name"
          end

          create_table "device_settings", force: :cascade do |t|
            t.bigint "application_id"
            t.string "setting_name"
          end
        RUBY

        expect_no_offenses(<<~RUBY)
          create_table "applications", id: :bigint, force: :cascade do |t|
            t.string "name"
          end

          create_table "device_settings", force: :cascade do |t|
            t.bigint "application_id"
            t.string "setting_name"
          end
        RUBY
      end

      it 'integer主キーを持つテーブルに対してinteger外部キーを使用している場合は、警告を出さない' do
        expect_no_offenses(<<~RUBY)
          create_table "applications", id: :integer, force: :cascade do |t|
            t.string "name"
          end

          create_table "device_settings", force: :cascade do |t|
            t.integer "application_id"
            t.string "setting_name"
          end
        RUBY
      end
    end

    context '外部キー型が参照テーブルと一致しない場合' do
      it 'bigint主キーを持つテーブルに対してinteger外部キーを使用している場合は警告を出す', aggregate_failures: true do
        expect_offense(<<~RUBY)
          create_table "applications", force: :cascade do |t|
            t.string "name"
          end

          create_table "device_settings", force: :cascade do |t|
            t.integer "application_id"
            ^^^^^^^^^^^^^^^^^^^^^^^^^^ 外部キーが参照するテーブルの主キーがbigint型の場合、外部キーにbigint型を使用してください。
            t.string "setting_name"
          end
        RUBY

        expect_offense(<<~RUBY)
          create_table "applications", id: :bigint, force: :cascade do |t|
            t.string "name"
          end

          create_table "device_settings", force: :cascade do |t|
            t.integer "application_id"
            ^^^^^^^^^^^^^^^^^^^^^^^^^^ 外部キーが参照するテーブルの主キーがbigint型の場合、外部キーにbigint型を使用してください。
            t.string "setting_name"
          end
        RUBY
      end

      it 'integer主キーを持つテーブルに対してbigint外部キーを使用している場合は、警告を出さない' do
        expect_no_offenses(<<~RUBY)
          create_table "applications", id: :integer, force: :cascade do |t|
            t.string "name"
          end

          create_table "device_settings", force: :cascade do |t|
            t.bigint "application_id"
            t.string "setting_name"
          end
        RUBY
      end
    end
  end

  describe 'エッジケース' do
    context '外部キーが命名規則に従わない場合' do
      it '_idサフィックスでない場合は、警告を出さない' do
        expect_no_offenses(<<~RUBY)
          create_table "applications", force: :cascade do |t|
            t.string "name"
          end

          create_table "device_settings", force: :cascade do |t|
            t.integer "application"
            t.string "setting_name"
          end
        RUBY
      end

      it '複雑な複数形の場合は、警告を出さない' do
        expect_no_offenses(<<~RUBY)
          create_table "people", force: :cascade do |t|
            t.string "name"
          end

          create_table "orders", force: :cascade do |t|
            t.integer "person_id"
            t.string "order_name"
          end
        RUBY
      end
    end

    context '参照されるテーブルが存在しない場合' do
      it '警告を出さない' do
        expect_no_offenses(<<~RUBY)
          create_table "device_settings", force: :cascade do |t|
            t.integer "nonexistent_table_id"
            t.string "setting_name"
          end
        RUBY
      end
    end
  end

  describe '#extract_pk_type' do
    let(:processed_source) { parse_source(source, 'db/schema.rb') }
    let(:node) { processed_source.ast.children.first }

    context 'id: :integerが明示されている場合' do
      let(:source) { 'create_table "users", id: :integer, force: :cascade, charset: "utf8" do |t| end' }

      it 'integerを返す' do
        expect(cop.send(:extract_pk_type, node)).to eq(:integer)
      end
    end

    context 'id: :bigintが明示されている場合' do
      let(:source) { 'create_table "users", id: :bigint, force: :cascade, charset: "utf8" do |t| end' }

      it 'bigintを返す' do
        expect(cop.send(:extract_pk_type, node)).to eq(:bigint)
      end
    end

    context 'idオプションが指定されていない場合' do
      let(:source) { 'create_table "users", force: :cascade, charset: "utf8" do |t| end' }

      it 'bigintを返す' do
        expect(cop.send(:extract_pk_type, node)).to eq(:bigint)
      end
    end
  end

  describe '@table_pk_types' do
    let(:source) do
      <<~RUBY
        create_table "applications", id: :integer, force: :cascade do |t|
          t.string "name"
        end

        create_table "device_settings", force: :cascade do |t|
          t.integer "application_id"
          t.string "setting_name"
        end
      RUBY
    end

    it '複数テーブルの主キー型が正しく格納されること' do
      processed_source = parse_source(source, 'db/schema.rb')
      cop.instance_variable_set(:@processed_source, processed_source)

      # 全てのcreate_table sendノードを処理
      processed_source.ast.each_node(:send) do |send_node|
        cop.send(:on_send, send_node)
      end

      expect(cop.instance_variable_get(:@table_pk_types)['applications']).to eq(:integer)
      expect(cop.instance_variable_get(:@table_pk_types)['device_settings']).to eq(:bigint)
    end
  end

  describe '#check_integer_foreign_keys' do
    let(:source) do
      <<~RUBY
        create_table "device_settings", force: :cascade do |t|
          t.integer "application_id"
          t.bigint "user_id"
          t.string "setting_name"
        end
      RUBY
    end

    it 'integer外部キーは警告を出す' do
      processed_source = parse_source(source, 'db/schema.rb')
      cop.instance_variable_set(:@processed_source, processed_source)
      cop.instance_variable_set(:@table_pk_types, { 'applications' => :bigint })
      send_node = processed_source.ast.children.first
      block_node = send_node.block_node

      expect(cop).to receive(:add_offense).once
      cop.send(:check_integer_foreign_keys, block_node)
    end

    it 'bigint外部キーは警告を出さない' do
      processed_source = parse_source(source, 'db/schema.rb')
      cop.instance_variable_set(:@processed_source, processed_source)
      cop.instance_variable_set(:@table_pk_types, { 'users' => :bigint })
      send_node = processed_source.ast.children.first
      block_node = send_node.block_node

      expect(cop).not_to receive(:add_offense)

      block_node.body.each_node(:send) do |node|
        next unless node.method_name == :bigint

        cop.send(:check_integer_foreign_keys, block_node)
      end
    end
  end

  describe '#check_integer_foreign_key' do
    it '外部キー名が_idで終わり、参照先主キーがbigintなら警告を出す' do
      source = <<~RUBY
        create_table "applications", force: :cascade do |t|
          t.string "name"
        end
        create_table "device_settings", force: :cascade do |t|
          t.integer "application_id"
          t.string "setting_name"
        end
      RUBY
      cop.instance_variable_set(:@table_pk_types, { 'applications' => :bigint })
      send_node = parse_source(source, 'db/schema.rb').ast.each_node(:send).find { |n| n.method_name == :integer }
      expect(cop).to receive(:add_offense).once
      cop.send(:check_integer_foreign_key, send_node)
    end

    it '外部キー名が_idで終わり、参照先主キーがintegerなら警告を出さない' do
      source = <<~RUBY
        create_table "applications", id: :integer, force: :cascade do |t|
          t.string "name"
        end
        create_table "device_settings", force: :cascade do |t|
          t.integer "application_id"
          t.string "setting_name"
        end
      RUBY
      cop.instance_variable_set(:@table_pk_types, { 'applications' => :integer })
      send_node = parse_source(source, 'db/schema.rb').ast.each_node(:send).find { |n| n.method_name == :integer }
      expect(cop).not_to receive(:add_offense)
      cop.send(:check_integer_foreign_key, send_node)
    end

    it '外部キー名が_idで終わらず、参照先主キーがbigintでも警告を出さない' do
      source = <<~RUBY
        create_table "device_settings", force: :cascade do |t|
          t.integer "application"
          t.string "setting_name"
        end
      RUBY
      cop.instance_variable_set(:@table_pk_types, { 'applications' => :bigint })
      send_node = parse_source(source, 'db/schema.rb').ast.each_node(:send).find { |n| n.method_name == :integer }
      expect(cop).not_to receive(:add_offense)
      cop.send(:check_integer_foreign_key, send_node)
    end

    it '外部キー名が_idで終わらず、参照先主キーがintegerでも警告を出さない' do
      source = <<~RUBY
        create_table "device_settings", force: :cascade do |t|
          t.integer "application"
          t.string "setting_name"
        end
      RUBY
      cop.instance_variable_set(:@table_pk_types, { 'applications' => :integer })
      send_node = parse_source(source, 'db/schema.rb').ast.each_node(:send).find { |n| n.method_name == :integer }
      expect(cop).not_to receive(:add_offense)
      cop.send(:check_integer_foreign_key, send_node)
    end

    it '参照先テーブルが存在しない場合は警告を出さない' do
      source = <<~RUBY
        create_table "device_settings", force: :cascade do |t|
          t.integer "nonexistent_id"
          t.string "setting_name"
        end
      RUBY
      cop.instance_variable_set(:@table_pk_types, {})
      send_node = parse_source(source, 'db/schema.rb').ast.each_node(:send).find { |n| n.method_name == :integer }
      expect(cop).not_to receive(:add_offense)
      cop.send(:check_integer_foreign_key, send_node)
    end

    it '複数外部キーがある場合、bigint主キーの外部キーだけ警告を出す' do
      source = <<~RUBY
        create_table "users", id: :integer, force: :cascade do |t|
          t.string "name"
        end
        create_table "applications", force: :cascade do |t|
          t.string "name"
        end
        create_table "device_settings", force: :cascade do |t|
          t.integer "user_id"
          t.integer "application_id"
          t.string "setting_name"
        end
      RUBY
      cop.instance_variable_set(:@table_pk_types, { 'users' => :integer, 'applications' => :bigint })
      send_nodes = parse_source(source, 'db/schema.rb').ast.each_node(:send).select { |n| n.method_name == :integer }
      expect(cop).to receive(:add_offense).once
      send_nodes.each { |node| cop.send(:check_integer_foreign_key, node) }
    end
  end

  describe '#extract_referenced_table' do
    it 'application_idからapplicationsを返す' do
      expect(cop.send(:extract_referenced_table, 'application_id')).to eq('applications')
    end

    it 'company_idからcompaniesを返す' do
      expect(cop.send(:extract_referenced_table, 'company_id')).to eq('companies')
    end

    it '_idで終わらない場合は末尾にsを追加する' do
      expect(cop.send(:extract_referenced_table, 'application')).to eq('applications')
    end
  end
end
