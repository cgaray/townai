CREATE TABLE IF NOT EXISTS "active_storage_blobs" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "byte_size" bigint NOT NULL, "checksum" varchar, "content_type" varchar, "created_at" datetime(6) NOT NULL, "filename" varchar NOT NULL, "key" varchar NOT NULL, "metadata" text, "service_name" varchar NOT NULL);
CREATE UNIQUE INDEX "index_active_storage_blobs_on_key" ON "active_storage_blobs" ("key") /*application='Townai'*/;
CREATE TABLE IF NOT EXISTS "active_storage_attachments" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "blob_id" bigint NOT NULL, "created_at" datetime(6) NOT NULL, "name" varchar NOT NULL, "record_id" bigint NOT NULL, "record_type" varchar NOT NULL, CONSTRAINT "fk_rails_c3b3935057"
FOREIGN KEY ("blob_id")
  REFERENCES "active_storage_blobs" ("id")
);
CREATE INDEX "index_active_storage_attachments_on_blob_id" ON "active_storage_attachments" ("blob_id") /*application='Townai'*/;
CREATE UNIQUE INDEX "index_active_storage_attachments_uniqueness" ON "active_storage_attachments" ("record_type", "record_id", "name", "blob_id") /*application='Townai'*/;
CREATE TABLE IF NOT EXISTS "active_storage_variant_records" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "blob_id" bigint NOT NULL, "variation_digest" varchar NOT NULL, CONSTRAINT "fk_rails_993965df05"
FOREIGN KEY ("blob_id")
  REFERENCES "active_storage_blobs" ("id")
);
CREATE UNIQUE INDEX "index_active_storage_variant_records_uniqueness" ON "active_storage_variant_records" ("blob_id", "variation_digest") /*application='Townai'*/;
CREATE TABLE IF NOT EXISTS "api_calls" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "completion_tokens" integer, "cost_credits" decimal(12,6), "created_at" datetime(6) NOT NULL, "document_id" integer, "error_message" text, "model" varchar NOT NULL, "operation" varchar NOT NULL, "prompt_tokens" integer, "provider" varchar NOT NULL, "response_time_ms" integer, "status" varchar NOT NULL, "total_tokens" integer, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_833f30121c"
FOREIGN KEY ("document_id")
  REFERENCES "documents" ("id")
);
CREATE INDEX "index_api_calls_on_created_at" ON "api_calls" ("created_at") /*application='Townai'*/;
CREATE INDEX "index_api_calls_on_document_id" ON "api_calls" ("document_id") /*application='Townai'*/;
CREATE INDEX "index_api_calls_on_model" ON "api_calls" ("model") /*application='Townai'*/;
CREATE INDEX "index_api_calls_on_provider" ON "api_calls" ("provider") /*application='Townai'*/;
CREATE INDEX "index_api_calls_on_status" ON "api_calls" ("status") /*application='Townai'*/;
CREATE TABLE IF NOT EXISTS "attendees" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "created_at" datetime(6) NOT NULL, "governing_body_extracted" varchar NOT NULL, "governing_body_id" integer, "name" varchar NOT NULL, "normalized_name" varchar NOT NULL, "person_id" integer, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_705838fd59"
FOREIGN KEY ("governing_body_id")
  REFERENCES "governing_bodies" ("id")
, CONSTRAINT "fk_rails_4ff535fe1d"
FOREIGN KEY ("person_id")
  REFERENCES "people" ("id")
);
CREATE INDEX "index_attendees_on_governing_body_id" ON "attendees" ("governing_body_id") /*application='Townai'*/;
CREATE INDEX "index_attendees_on_name" ON "attendees" ("name") /*application='Townai'*/;
CREATE UNIQUE INDEX "index_attendees_on_normalized_name_and_governing_body_extracted" ON "attendees" ("normalized_name", "governing_body_extracted") /*application='Townai'*/;
CREATE INDEX "index_attendees_on_person_id" ON "attendees" ("person_id") /*application='Townai'*/;
CREATE TABLE IF NOT EXISTS "document_attendees" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "attendee_id" integer NOT NULL, "created_at" datetime(6) NOT NULL, "document_id" integer NOT NULL, "role" varchar, "source_text" text, "status" varchar, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_967e60c1ed"
FOREIGN KEY ("attendee_id")
  REFERENCES "attendees" ("id")
, CONSTRAINT "fk_rails_96bf242bb6"
FOREIGN KEY ("document_id")
  REFERENCES "documents" ("id")
);
CREATE INDEX "index_document_attendees_on_attendee_id" ON "document_attendees" ("attendee_id") /*application='Townai'*/;
CREATE UNIQUE INDEX "index_document_attendees_on_document_id_and_attendee_id" ON "document_attendees" ("document_id", "attendee_id") /*application='Townai'*/;
CREATE INDEX "index_document_attendees_on_document_id" ON "document_attendees" ("document_id") /*application='Townai'*/;
CREATE TABLE IF NOT EXISTS "documents" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "created_at" datetime(6) NOT NULL, "extracted_metadata" text, "governing_body_id" integer, "raw_text" text, "source_file_hash" varchar, "source_file_name" varchar, "status" integer DEFAULT 0, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_d8dcddfde2"
FOREIGN KEY ("governing_body_id")
  REFERENCES "governing_bodies" ("id")
);
CREATE INDEX "index_documents_on_governing_body_id" ON "documents" ("governing_body_id") /*application='Townai'*/;
CREATE UNIQUE INDEX "index_documents_on_source_file_hash" ON "documents" ("source_file_hash") /*application='Townai'*/;
CREATE TABLE IF NOT EXISTS "schema_migrations" ("version" varchar NOT NULL PRIMARY KEY);
CREATE TABLE IF NOT EXISTS "ar_internal_metadata" ("key" varchar NOT NULL PRIMARY KEY, "value" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE INDEX "index_documents_on_status" ON "documents" ("status") /*application='Townai'*/;
CREATE VIRTUAL TABLE search_entries USING fts5(
  entity_type,
  entity_id UNINDEXED,
  title,
  subtitle,
  content,
  url UNINDEXED,
  tokenize='porter unicode61'
)
/* search_entries(entity_type,entity_id,title,subtitle,content,url) */;
CREATE TABLE IF NOT EXISTS 'search_entries_data'(id INTEGER PRIMARY KEY, block BLOB);
CREATE TABLE IF NOT EXISTS 'search_entries_idx'(segid, term, pgno, PRIMARY KEY(segid, term)) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS 'search_entries_content'(id INTEGER PRIMARY KEY, c0, c1, c2, c3, c4, c5);
CREATE TABLE IF NOT EXISTS 'search_entries_docsize'(id INTEGER PRIMARY KEY, sz BLOB);
CREATE TABLE IF NOT EXISTS 'search_entries_config'(k PRIMARY KEY, v) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS "towns" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar NOT NULL, "normalized_name" varchar NOT NULL, "slug" varchar NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_towns_on_normalized_name" ON "towns" ("normalized_name") /*application='Townai'*/;
CREATE UNIQUE INDEX "index_towns_on_slug" ON "towns" ("slug") /*application='Townai'*/;
CREATE TABLE IF NOT EXISTS "governing_bodies" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "created_at" datetime(6) NOT NULL, "documents_count" integer DEFAULT 0, "name" varchar NOT NULL, "normalized_name" varchar NOT NULL, "updated_at" datetime(6) NOT NULL, "town_id" integer, CONSTRAINT "fk_rails_3a54026665"
FOREIGN KEY ("town_id")
  REFERENCES "towns" ("id")
);
CREATE INDEX "index_governing_bodies_on_name" ON "governing_bodies" ("name") /*application='Townai'*/;
CREATE INDEX "index_governing_bodies_on_town_id" ON "governing_bodies" ("town_id") /*application='Townai'*/;
CREATE TABLE IF NOT EXISTS "people" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "created_at" datetime(6) NOT NULL, "document_appearances_count" integer DEFAULT 0, "name" varchar NOT NULL, "normalized_name" varchar NOT NULL, "updated_at" datetime(6) NOT NULL, "town_id" integer, CONSTRAINT "fk_rails_6d6cdfea37"
FOREIGN KEY ("town_id")
  REFERENCES "towns" ("id")
);
CREATE INDEX "index_people_on_document_appearances_count" ON "people" ("document_appearances_count") /*application='Townai'*/;
CREATE INDEX "index_people_on_name" ON "people" ("name") /*application='Townai'*/;
CREATE INDEX "index_people_on_normalized_name" ON "people" ("normalized_name") /*application='Townai'*/;
CREATE INDEX "index_people_on_town_id" ON "people" ("town_id") /*application='Townai'*/;
CREATE UNIQUE INDEX "index_governing_bodies_on_normalized_name_and_town_id" ON "governing_bodies" ("normalized_name", "town_id") /*application='Townai'*/;
CREATE TABLE IF NOT EXISTS "users" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "email" varchar DEFAULT '' NOT NULL, "admin" boolean DEFAULT FALSE NOT NULL, "remember_created_at" datetime(6), "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_users_on_email" ON "users" ("email") /*application='Townai'*/;
CREATE TABLE IF NOT EXISTS "topics" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "document_id" integer NOT NULL, "title" varchar NOT NULL, "summary" text, "action_taken" integer DEFAULT 0, "source_text" text, "position" integer DEFAULT 0, "category" varchar, "amount_cents" integer, "amount_type" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "action_taken_raw" varchar /*application='Townai'*/, CONSTRAINT "fk_rails_9cac59730d"
FOREIGN KEY ("document_id")
  REFERENCES "documents" ("id")
);
CREATE INDEX "index_topics_on_document_id" ON "topics" ("document_id") /*application='Townai'*/;
CREATE INDEX "index_topics_on_document_id_and_position" ON "topics" ("document_id", "position") /*application='Townai'*/;
CREATE INDEX "index_topics_on_action_taken" ON "topics" ("action_taken") /*application='Townai'*/;
CREATE INDEX "index_topics_on_category" ON "topics" ("category") /*application='Townai'*/;
CREATE TABLE IF NOT EXISTS "admin_audit_logs" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "user_id" integer NOT NULL, "action" varchar NOT NULL, "resource_type" varchar NOT NULL, "resource_id" bigint, "params" text, "previous_state" text, "new_state" text, "ip_address" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_194c515e61"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_admin_audit_logs_on_user_id" ON "admin_audit_logs" ("user_id") /*application='Townai'*/;
CREATE INDEX "index_admin_audit_logs_on_user_id_and_created_at" ON "admin_audit_logs" ("user_id", "created_at") /*application='Townai'*/;
CREATE INDEX "index_admin_audit_logs_on_resource_type_and_resource_id" ON "admin_audit_logs" ("resource_type", "resource_id") /*application='Townai'*/;
CREATE INDEX "index_admin_audit_logs_on_action" ON "admin_audit_logs" ("action") /*application='Townai'*/;
CREATE TABLE IF NOT EXISTS "document_event_logs" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "document_id" integer NOT NULL, "event_type" varchar NOT NULL, "metadata" text, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_e9258834fe"
FOREIGN KEY ("document_id")
  REFERENCES "documents" ("id")
);
CREATE INDEX "index_document_event_logs_on_document_id" ON "document_event_logs" ("document_id") /*application='Townai'*/;
CREATE INDEX "index_document_event_logs_on_document_id_and_created_at" ON "document_event_logs" ("document_id", "created_at") /*application='Townai'*/;
CREATE INDEX "index_document_event_logs_on_event_type" ON "document_event_logs" ("event_type") /*application='Townai'*/;
CREATE TABLE IF NOT EXISTS "authentication_logs" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "user_id" integer, "action" varchar NOT NULL, "email_hash" varchar, "ip_address" varchar, "user_agent" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE INDEX "index_authentication_logs_on_user_id" ON "authentication_logs" ("user_id") /*application='Townai'*/;
CREATE INDEX "index_authentication_logs_on_user_id_and_created_at" ON "authentication_logs" ("user_id", "created_at") /*application='Townai'*/;
CREATE INDEX "index_authentication_logs_on_action" ON "authentication_logs" ("action") /*application='Townai'*/;
CREATE INDEX "index_authentication_logs_on_email_hash" ON "authentication_logs" ("email_hash") /*application='Townai'*/;
CREATE TABLE IF NOT EXISTS "duplicate_suggestions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "person_id" integer NOT NULL, "duplicate_person_id" integer NOT NULL, "match_type" varchar DEFAULT 'exact' NOT NULL, "similarity_score" integer DEFAULT 0 NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_c4dd4ff487"
FOREIGN KEY ("person_id")
  REFERENCES "people" ("id")
, CONSTRAINT "fk_rails_700cd4dc14"
FOREIGN KEY ("duplicate_person_id")
  REFERENCES "people" ("id")
);
CREATE INDEX "index_duplicate_suggestions_on_person_id" ON "duplicate_suggestions" ("person_id") /*application='Townai'*/;
CREATE INDEX "index_duplicate_suggestions_on_duplicate_person_id" ON "duplicate_suggestions" ("duplicate_person_id") /*application='Townai'*/;
CREATE UNIQUE INDEX "idx_on_person_id_duplicate_person_id_5606038b71" ON "duplicate_suggestions" ("person_id", "duplicate_person_id") /*application='Townai'*/;
INSERT INTO "schema_migrations" (version) VALUES
('20260101184306'),
('20260101134241'),
('20260101124059'),
('20251231173616'),
('20251231122803'),
('20251231114742'),
('20251231114720'),
('20251231025933'),
('20251231024801'),
('20251230184307'),
('20251230182934'),
('20251229125336'),
('20251228192040'),
('20251226194717'),
('20251226194547'),
('20250101000002'),
('20250101000001'),
('20250101000000');

