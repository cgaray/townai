# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2025_12_28_192040) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "api_calls", force: :cascade do |t|
    t.integer "completion_tokens"
    t.decimal "cost_credits", precision: 12, scale: 6
    t.datetime "created_at", null: false
    t.integer "document_id"
    t.text "error_message"
    t.string "model", null: false
    t.string "operation", null: false
    t.integer "prompt_tokens"
    t.string "provider", null: false
    t.integer "response_time_ms"
    t.string "status", null: false
    t.integer "total_tokens"
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_api_calls_on_created_at"
    t.index ["document_id"], name: "index_api_calls_on_document_id"
    t.index ["model"], name: "index_api_calls_on_model"
    t.index ["provider"], name: "index_api_calls_on_provider"
    t.index ["status"], name: "index_api_calls_on_status"
  end

  create_table "documents", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "extracted_metadata"
    t.text "raw_text"
    t.string "source_file_hash"
    t.string "source_file_name"
    t.integer "status", default: 0
    t.datetime "updated_at", null: false
    t.index ["source_file_hash"], name: "index_documents_on_source_file_hash", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "api_calls", "documents"
end
