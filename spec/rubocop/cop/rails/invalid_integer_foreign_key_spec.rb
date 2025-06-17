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

  context '外部キー型が参照テーブルと一致する場合' do
    it 'bigint主キーを持つテーブルに対してbigint外部キーを使用している場合は警告を出さない' do
      expect_no_offenses(<<~RUBY)
        create_table "applications", force: :cascade do |t|
          t.string "name"
        end

        create_table "device_settings", force: :cascade do |t|
          t.bigint "application_id"
          t.string "setting_name"
        end
      RUBY
    end

    it 'integer主キーを持つテーブルに対してinteger外部キーを使用している場合は警告を出さない' do
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
    it 'bigint主キーを持つテーブルに対してinteger外部キーを使用している場合は警告を出す' do
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
    end
  end

  context 'Rails 7+の動作: デフォルトでbigint主キー' do
    it '明示的なid定義がないテーブル（デフォルトでbigint）を参照するinteger外部キーに対して警告を出す' do
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
    end

    it '明示的にinteger主キーを持つテーブルを参照する場合は警告を出さない' do
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

  context 'テーブルに主キー定義がない場合' do
    it '警告を出す（デフォルトでbigint主キー）' do
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
    end
  end

  context '外部キーが命名規則に従わない場合' do
    it '_idサフィックスでない場合は警告を出さない' do
      expect_no_offenses(<<~RUBY)
        create_table "applications", force: :cascade do |t|
          t.string "name"
        end

        create_table "device_settings", force: :cascade do |t|
          t.integer "application_ref"
          t.string "setting_name"
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

  context 'ファイルがdb/schema.rbでない場合' do
    it '警告を出す（Include設定で全rbファイル対象のため）' do
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
    end
  end

  context '自動修正' do
    it 'integerをbigintに修正する' do
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

      expect_correction(<<~RUBY)
        create_table "applications", force: :cascade do |t|
          t.string "name"
        end

        create_table "device_settings", force: :cascade do |t|
          t.bigint "application_id"
          t.string "setting_name"
        end
      RUBY
    end
  end

  describe '#extract_pk_type' do
    let(:processed_source) { parse_source(source, 'db/schema.rb') }
    let(:node) { processed_source.ast.children.first }

    context 'id: :integerが明示されている場合' do
      let(:source) { 'create_table "users", id: :integer, force: :cascade do |t| end' }

      it 'integerを返す' do
        expect(cop.send(:extract_pk_type, node)).to eq(:integer)
      end
    end

    context 'id: :bigintが明示されている場合' do
      let(:source) { 'create_table "users", id: :bigint, force: :cascade do |t| end' }

      it 'bigintを返す' do
        expect(cop.send(:extract_pk_type, node)).to eq(:bigint)
      end
    end

    context 'idオプションが指定されていない場合' do
      let(:source) { 'create_table "users", force: :cascade do |t| end' }

      it 'bigintを返す（デフォルト）' do
        expect(cop.send(:extract_pk_type, node)).to eq(:bigint)
      end
    end

    context 'id以外のオプションが指定されている場合' do
      let(:source) { 'create_table "users", force: :cascade, charset: "utf8" do |t| end' }

      it 'bigintを返す（デフォルト）' do
        expect(cop.send(:extract_pk_type, node)).to eq(:bigint)
      end
    end

    context '複数のオプションが指定されている場合' do
      let(:source) { 'create_table "users", id: :integer, force: :cascade, charset: "utf8" do |t| end' }

      it 'integerを返す' do
        expect(cop.send(:extract_pk_type, node)).to eq(:integer)
      end
    end
  end

  describe '#extract_referenced_table' do
    it 'application_idからapplicationsを返す' do
      expect(cop.send(:extract_referenced_table, 'application_id')).to eq('applications')
    end

    it 'user_idからusersを返す' do
      expect(cop.send(:extract_referenced_table, 'user_id')).to eq('users')
    end

    it 'company_idからcompaniesを返す' do
      expect(cop.send(:extract_referenced_table, 'company_id')).to eq('companies')
    end

    it 'order_idからordersを返す' do
      expect(cop.send(:extract_referenced_table, 'order_id')).to eq('orders')
    end

    it '_idで終わらない場合は適切に変換する' do
      expect(cop.send(:extract_referenced_table, 'application_ref')).to eq('application_refs')
    end
  end

  describe '#on_send' do
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

    it 'テーブル名と主キー型を正しく収集する' do
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
          t.string "setting_name"
        end
      RUBY
    end

    it 'integer外部キーを検出する' do
      processed_source = parse_source(source, 'db/schema.rb')
      cop.instance_variable_set(:@processed_source, processed_source)
      cop.instance_variable_set(:@table_pk_types, { 'applications' => :bigint })

      send_node = processed_source.ast.children.first
      block_node = send_node.block_node

      # 警告が追加されることを確認
      expect(cop).to receive(:add_offense).once
      cop.send(:check_integer_foreign_keys, block_node)
    end
  end

  describe 'AST構造の確認' do
    it 'create_tableブロックの構造を確認する' do
      source = 'create_table "users", id: :integer, force: :cascade do |t| end'
      processed_source = parse_source(source, 'db/schema.rb')
      node = processed_source.ast.children.first

      # 実際のノードタイプを確認
      puts "Node class: #{node.class}"
      puts "Node type: #{node.type}"
      puts "Node: #{node.inspect}"

      # SendNodeの場合
      if node.type == :send
        expect(node.method_name).to eq(:create_table)

        # 引数の構造を確認
        first_arg = node.arguments.first
        expect(first_arg).to be_a(RuboCop::AST::StrNode)
        expect(first_arg.value).to eq('users')
      end
    end
  end
end
