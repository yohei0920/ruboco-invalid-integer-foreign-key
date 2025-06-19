# RuboCop FK Bigint Checker

## 概要

本RuboCopは、Railsアプリケーションの `db/schema.rb` ファイル内で、外部キー型のミスマッチを検出し警告を出力します。具体的には、親テーブルの主キーが `bigint` 型であるにも関わらず、子テーブルで `integer` 型の外部キーが定義されている場合に警告を出します。

## インストール


```ruby
gem 'rubocop-fk-bigint-checker', 
    github: 'yohei0920/ruboco-invalid-integer-foreign-key',
    branch: 'main'
```

```bash
bundle install
```

## 使い方

Add the following to your `.rubocop.yml`:

```yaml
require:
  - rubocop-fk-bigint-checker

Rails/InvalidIntegerForeignKey:
  Enabled: true
  Include:
    - 'db/schema.rb'
```

### テスト実行


```bash
bundle exec rspec
```


### 例

#### 警告が出力されるケース

```ruby
# db/schema.rb
# パターン1: デフォルトのbigint主キー
create_table "applications", force: :cascade do |t|
  t.string "name"
  t.timestamps
end

create_table "device_settings", force: :cascade do |t|
  t.integer "application_id" # ← ⚠ 警告
  t.string "setting_name"
end
```

```ruby
# db/schema.rb
# パターン2: 明示的にbigint指定
create_table "applications", id: :bigint, force: :cascade do |t|
  t.string "name"
end

create_table "device_settings", force: :cascade do |t|
  t.integer "application_id" # ← ⚠ 警告
  t.string "setting_name"
end
```

#### 警告が出力されないケース

```ruby
# db/schema.rb
# パターン1: 親テーブルが明示的にinteger主キー
create_table "applications", id: :integer, force: :cascade do |t|
  t.string "name"
end

create_table "device_settings", force: :cascade do |t|
  t.integer "application_id" # ← 警告なし
  t.string "setting_name"
end
```

```ruby
# db/schema.rb
# パターン2: 外部キーが正しくbigint型
create_table "applications", force: :cascade do |t|
  t.string "name"
end

create_table "device_settings", force: :cascade do |t|
  t.bigint "application_id" # ← 警告なし
  t.string "setting_name"
end
```

## 技術仕様

### Cop名
```
Rails/InvalidIntegerForeignKey
```

### 警告メッセージ
```
外部キーが参照するテーブルの主キーがbigint型の場合、外部キーにbigint型を使用してください。
```

### 対象ファイル
- **解析対象**: `db/schema.rb` のみ
- **対象外**: 
  - migration等の `.rb` ファイル
  - 設定ファイル

### 検出対象の条件

#### 1. 外部キー定義の検出
`create_table` ブロック内で以下の形式に一致する行を検出：

```ruby
t.integer :xxx_id
```

#### 2. 親テーブルの特定ルール
外部キー名から親テーブル名を特定するルール：

```ruby
# 基本的な変換ルール
t.integer :application_id → applications
t.integer :company_id → companies
```

#### 3. 警告の出力条件
以下の3つの条件をすべて満たす場合に警告を出力：

1. `t.integer :xxx_id` が定義されている
2. `xxx_id` に対応する親テーブル（例：`applications`）が `create_table` に存在する
3. 対応するテーブルの主キー `id` が `bigint` 型であると判断できる

**主キー型の判定ロジック**:

1. **明示的な指定がある場合**:
   - `id: :integer` → `integer`型とみなす
   - `id: :bigint` → `bigint`型とみなす

2. **明示的な指定がない場合**:
   - **PostgreSQL/MySQL**: `bigint`型（Rails 5.1以降のデフォルト）
   - **その他のDB**: 対象外

> **参考**: [Rails Schema Conventions](https://guides.rubyonrails.org/v6.0/active_record_basics.html#schema-conventions)

**技術的な制約**:
- `db/schema.rb`では`create_table`の第一引数は常に文字列（例：`"users"`）であり、シンボル（例：`:users`）は使用されません
- 外部キー定義も文字列（例：`"user_id"`）のみが使用され、シンボル（例：`:user_id`）は使用されません

### 解析方法
- `db/schema.rb` をAST（Abstract Syntax Tree）で解析
- データベースへの接続は行わない

### 制限事項と制約

#### 対応しないケース
- **複雑な複数形**: `person` → `people`, `child` → `children` など
- **t.references**: `t.references :user` はチェック対象外
- **add_foreign_key**: `add_foreign_key` メソッドはチェック対象外
- **カスタム外部キー名**: 命名規則に従わない外部キー名
- **中間テーブル**: `has_and_belongs_to_many` の中間テーブル
- **SQLite**: SQLiteでは主キーが`integer`型のため、本Copは適用されません

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).
