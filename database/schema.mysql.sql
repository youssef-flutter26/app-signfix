-- Final-state MySQL/MariaDB schema for SignFix. server/migrate.js applies it on
-- start: CREATE TABLE is made idempotent and duplicate index/column errors are
-- ignored, so later ALTER TABLE ... ADD COLUMN lines upgrade older databases.
SET NAMES utf8mb4;

CREATE TABLE roles (id BIGINT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(50) UNIQUE NOT NULL);
CREATE TABLE permissions (id BIGINT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(100) UNIQUE NOT NULL, description VARCHAR(255));
CREATE TABLE users (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  role_id BIGINT NOT NULL,
  name VARCHAR(120) NOT NULL,
  email VARCHAR(190) UNIQUE NOT NULL,
  mobile VARCHAR(20),
  password_hash VARCHAR(255) NOT NULL,
  status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active','disabled','pending_verification','deleted')),
  verified_at DATETIME,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (role_id) REFERENCES roles(id)
);
CREATE TABLE role_permissions (role_id BIGINT NOT NULL, permission_id BIGINT NOT NULL, PRIMARY KEY(role_id,permission_id), FOREIGN KEY(role_id) REFERENCES roles(id) ON DELETE CASCADE, FOREIGN KEY(permission_id) REFERENCES permissions(id) ON DELETE CASCADE);
CREATE TABLE customers (id BIGINT AUTO_INCREMENT PRIMARY KEY, user_id BIGINT UNIQUE NOT NULL, company_name VARCHAR(160), address JSON, payments_enabled BOOLEAN DEFAULT FALSE, FOREIGN KEY(user_id) REFERENCES users(id));
CREATE TABLE technicians (id BIGINT AUTO_INCREMENT PRIMARY KEY, user_id BIGINT UNIQUE NOT NULL, service_areas JSON, location_sharing BOOLEAN DEFAULT FALSE, profile_photo_url TEXT, emergency_contact VARCHAR(20), skills JSON, employee_id VARCHAR(80), date_of_joining DATE, terms_accepted_at DATETIME, last_latitude DECIMAL(10,7), last_longitude DECIMAL(10,7), last_location_at DATETIME, FOREIGN KEY(user_id) REFERENCES users(id));
CREATE TABLE customer_addresses (id BIGINT AUTO_INCREMENT PRIMARY KEY, customer_id BIGINT NOT NULL, label VARCHAR(60) DEFAULT 'Other', address_line TEXT NOT NULL, city VARCHAR(100), state VARCHAR(100), pincode VARCHAR(10), latitude DECIMAL(10,7), longitude DECIMAL(10,7), is_default BOOLEAN DEFAULT FALSE, created_at DATETIME DEFAULT CURRENT_TIMESTAMP, updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, FOREIGN KEY(customer_id) REFERENCES customers(id) ON DELETE CASCADE);

CREATE TABLE products (id BIGINT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(160) NOT NULL, category VARCHAR(100), description TEXT, pricing_method VARCHAR(20) NOT NULL CHECK (pricing_method IN ('sqft','unit','fixed')), status BOOLEAN DEFAULT TRUE, image_url TEXT, base_price DECIMAL(12,2) DEFAULT 0, is_discounted BOOLEAN DEFAULT FALSE);
CREATE TABLE product_categories (id BIGINT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(120) UNIQUE NOT NULL, status BOOLEAN DEFAULT TRUE);
CREATE TABLE materials (id BIGINT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(120) UNIQUE NOT NULL, price_per_sqft DECIMAL(12,2) DEFAULT 0, status BOOLEAN DEFAULT TRUE, description TEXT, image_url TEXT, pricing_method VARCHAR(20) DEFAULT 'sqft');
CREATE TABLE lighting_options (id BIGINT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(120) UNIQUE NOT NULL, price_per_sqft DECIMAL(12,2) DEFAULT 0, status BOOLEAN DEFAULT TRUE, description TEXT, image_url TEXT, pricing_method VARCHAR(20) DEFAULT 'sqft');
CREATE TABLE accessories (id BIGINT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(120) UNIQUE NOT NULL, description TEXT, price DECIMAL(12,2) DEFAULT 0, status BOOLEAN DEFAULT TRUE, image_url TEXT, pricing_method VARCHAR(20) DEFAULT 'unit');
CREATE TABLE installation_options (id BIGINT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(120) UNIQUE NOT NULL, description TEXT, price DECIMAL(12,2) DEFAULT 0, status BOOLEAN DEFAULT TRUE, image_url TEXT, pricing_method VARCHAR(20) DEFAULT 'fixed');
CREATE TABLE service_categories (id BIGINT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(120) UNIQUE NOT NULL, status BOOLEAN DEFAULT TRUE);
CREATE TABLE pricing_rules (id BIGINT AUTO_INCREMENT PRIMARY KEY, product_id BIGINT, rule_type VARCHAR(50), amount DECIMAL(12,2) NOT NULL, tax_rate DECIMAL(5,2) DEFAULT 18, active BOOLEAN DEFAULT TRUE, name VARCHAR(120), pricing_method VARCHAR(20) DEFAULT 'fixed', metadata JSON, FOREIGN KEY(product_id) REFERENCES products(id));

CREATE TABLE orders (id BIGINT AUTO_INCREMENT PRIMARY KEY, order_no VARCHAR(30) UNIQUE NOT NULL, customer_id BIGINT NOT NULL, specifications JSON NOT NULL, estimated_price DECIMAL(12,2), status VARCHAR(40) DEFAULT 'under_review', admin_notes TEXT, installation_technician_id BIGINT, updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, created_at DATETIME DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY(customer_id) REFERENCES customers(id), FOREIGN KEY(installation_technician_id) REFERENCES technicians(id));
CREATE TABLE order_items (id BIGINT AUTO_INCREMENT PRIMARY KEY, order_id BIGINT NOT NULL, product_id BIGINT, description TEXT, quantity DECIMAL(10,2) DEFAULT 1, unit_price DECIMAL(12,2), amount DECIMAL(12,2), FOREIGN KEY(order_id) REFERENCES orders(id) ON DELETE CASCADE, FOREIGN KEY(product_id) REFERENCES products(id));

CREATE TABLE sign_board_assets (id BIGINT AUTO_INCREMENT PRIMARY KEY, asset_no VARCHAR(20) UNIQUE NOT NULL, customer_id BIGINT NOT NULL, details JSON NOT NULL, location JSON, warranty_until DATE, qr_token CHAR(64) UNIQUE NOT NULL, created_at DATETIME DEFAULT CURRENT_TIMESTAMP, installation_date DATE, photos JSON, order_id BIGINT, warranty_start DATE, status VARCHAR(30) NOT NULL DEFAULT 'active' CHECK (status IN ('active','under_service','inactive','retired')), CHECK (warranty_until IS NULL OR warranty_start IS NULL OR warranty_until >= warranty_start), FOREIGN KEY(customer_id) REFERENCES customers(id), FOREIGN KEY(order_id) REFERENCES orders(id));
CREATE TABLE qr_codes (id BIGINT AUTO_INCREMENT PRIMARY KEY, asset_id BIGINT UNIQUE NOT NULL, token CHAR(64) UNIQUE NOT NULL, active BOOLEAN DEFAULT TRUE, created_at DATETIME DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY(asset_id) REFERENCES sign_board_assets(id) ON DELETE CASCADE);
CREATE TABLE asset_service_history (id BIGINT AUTO_INCREMENT PRIMARY KEY, asset_id BIGINT NOT NULL, ticket_id BIGINT, notes TEXT, created_at DATETIME DEFAULT CURRENT_TIMESTAMP, history_type VARCHAR(20) DEFAULT 'service', FOREIGN KEY(asset_id) REFERENCES sign_board_assets(id) ON DELETE CASCADE);

CREATE TABLE quotations (
  id BIGINT AUTO_INCREMENT PRIMARY KEY, quotation_no VARCHAR(30) UNIQUE NOT NULL, order_id BIGINT NOT NULL, customer_id BIGINT NOT NULL,
  subtotal DECIMAL(12,2) NOT NULL DEFAULT 0, discount DECIMAL(12,2) NOT NULL DEFAULT 0, gst DECIMAL(12,2) NOT NULL DEFAULT 0, final_amount DECIMAL(12,2) NOT NULL,
  terms TEXT, valid_until DATE, admin_approved_at DATETIME,
  status VARCHAR(30) NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','sent','viewed','change_requested','approved','rejected','expired','cancelled')),
  version INT NOT NULL DEFAULT 1 CHECK (version > 0), lock_version INT NOT NULL DEFAULT 1 CHECK (lock_version > 0),
  issue_date DATE NOT NULL DEFAULT (CURRENT_DATE),
  discount_type VARCHAR(20) NOT NULL DEFAULT 'fixed' CHECK (discount_type IN ('none','fixed','percentage')),
  discount_value DECIMAL(12,2) NOT NULL DEFAULT 0, discount_amount DECIMAL(12,2) NOT NULL DEFAULT 0, item_discount_amount DECIMAL(12,2) NOT NULL DEFAULT 0, taxable_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
  installation DECIMAL(12,2) NOT NULL DEFAULT 0, transportation DECIMAL(12,2) NOT NULL DEFAULT 0, design DECIMAL(12,2) NOT NULL DEFAULT 0, accessories DECIMAL(12,2) NOT NULL DEFAULT 0, other_charges DECIMAL(12,2) NOT NULL DEFAULT 0, gst_rate DECIMAL(5,2) NOT NULL DEFAULT 0,
  customer_notes TEXT, internal_notes TEXT, change_request_comment TEXT, rejection_reason TEXT,
  created_by BIGINT, updated_by BIGINT,
  sent_at DATETIME, viewed_at DATETIME, approved_at DATETIME, rejected_at DATETIME, change_requested_at DATETIME, expired_at DATETIME, cancelled_at DATETIME,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY(order_id) REFERENCES orders(id), FOREIGN KEY(customer_id) REFERENCES customers(id), FOREIGN KEY(created_by) REFERENCES users(id), FOREIGN KEY(updated_by) REFERENCES users(id)
);
CREATE TABLE quotation_items (
  id BIGINT AUTO_INCREMENT PRIMARY KEY, quotation_id BIGINT NOT NULL, description TEXT NOT NULL, quantity DECIMAL(10,2) NOT NULL DEFAULT 1, unit_price DECIMAL(12,2) NOT NULL DEFAULT 0, amount DECIMAL(12,2) NOT NULL DEFAULT 0,
  product_id BIGINT, unit VARCHAR(30) NOT NULL DEFAULT 'unit', discount_type VARCHAR(20) NOT NULL DEFAULT 'none' CHECK (discount_type IN ('none','fixed','percentage')), discount_value DECIMAL(12,2) NOT NULL DEFAULT 0, discount_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
  tax_percentage DECIMAL(5,2) NOT NULL DEFAULT 0, tax_amount DECIMAL(12,2) NOT NULL DEFAULT 0, line_subtotal DECIMAL(12,2) NOT NULL DEFAULT 0, line_total DECIMAL(12,2) NOT NULL DEFAULT 0, metadata JSON,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY(quotation_id) REFERENCES quotations(id) ON DELETE CASCADE, FOREIGN KEY(product_id) REFERENCES products(id)
);
CREATE TABLE quotation_status_history (id BIGINT AUTO_INCREMENT PRIMARY KEY, quotation_id BIGINT NOT NULL, old_status VARCHAR(30), new_status VARCHAR(30) NOT NULL, changed_by BIGINT, actor_type VARCHAR(20) NOT NULL CHECK (actor_type IN ('admin','customer','system')), customer_comment TEXT, internal_note TEXT, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY(quotation_id) REFERENCES quotations(id) ON DELETE CASCADE, FOREIGN KEY(changed_by) REFERENCES users(id));
CREATE TABLE quotation_revisions (id BIGINT AUTO_INCREMENT PRIMARY KEY, quotation_id BIGINT NOT NULL, version INT NOT NULL CHECK (version > 0), snapshot JSON NOT NULL, created_by BIGINT, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, UNIQUE(quotation_id,version), FOREIGN KEY(quotation_id) REFERENCES quotations(id) ON DELETE CASCADE, FOREIGN KEY(created_by) REFERENCES users(id));

CREATE TABLE service_tickets (id BIGINT AUTO_INCREMENT PRIMARY KEY, ticket_no VARCHAR(30) UNIQUE NOT NULL, customer_id BIGINT NOT NULL, category VARCHAR(80), description TEXT, location JSON, photos JSON, priority VARCHAR(20), status VARCHAR(40) DEFAULT 'submitted', admin_notes TEXT, service_type VARCHAR(120), admin_instructions TEXT, asset_id BIGINT, order_id BIGINT UNIQUE, updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, created_at DATETIME DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY(customer_id) REFERENCES customers(id), FOREIGN KEY(asset_id) REFERENCES sign_board_assets(id), FOREIGN KEY(order_id) REFERENCES orders(id) ON DELETE CASCADE);
CREATE TABLE technician_jobs (id BIGINT AUTO_INCREMENT PRIMARY KEY, ticket_id BIGINT NOT NULL, technician_id BIGINT, status VARCHAR(40), scheduled_at DATETIME, evidence JSON, customer_confirmation JSON, accepted_at DATETIME, travel_started_at DATETIME, reached_at DATETIME, inspection_started_at DATETIME, work_started_at DATETIME, work_completed_at DATETIME, closed_at DATETIME, updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, FOREIGN KEY(ticket_id) REFERENCES service_tickets(id), FOREIGN KEY(technician_id) REFERENCES technicians(id));
CREATE TABLE job_status_history (id BIGINT AUTO_INCREMENT PRIMARY KEY, job_id BIGINT NOT NULL, status VARCHAR(40) NOT NULL, notes TEXT, created_by BIGINT, created_at DATETIME DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY(job_id) REFERENCES technician_jobs(id), FOREIGN KEY(created_by) REFERENCES users(id));
CREATE TABLE job_photos (id BIGINT AUTO_INCREMENT PRIMARY KEY, job_id BIGINT NOT NULL, photo_type VARCHAR(20) NOT NULL CHECK (photo_type IN ('before','damage','work','after')), storage_key VARCHAR(255) NOT NULL, mime_type VARCHAR(80), created_at DATETIME DEFAULT CURRENT_TIMESTAMP, uploaded_by BIGINT, photo_category VARCHAR(40) CHECK (photo_category IS NULL OR photo_category IN ('existing_condition','damage','problem','work_in_progress','completed_work')), FOREIGN KEY(job_id) REFERENCES technician_jobs(id), FOREIGN KEY(uploaded_by) REFERENCES users(id));
CREATE TABLE job_materials (id BIGINT AUTO_INCREMENT PRIMARY KEY, job_id BIGINT NOT NULL, name VARCHAR(160) NOT NULL, quantity DECIMAL(10,2) NOT NULL CHECK (quantity > 0), unit VARCHAR(40) NOT NULL, notes TEXT, created_by BIGINT, created_at DATETIME DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY(job_id) REFERENCES technician_jobs(id) ON DELETE CASCADE, FOREIGN KEY(created_by) REFERENCES users(id));
CREATE TABLE job_location_updates (id BIGINT AUTO_INCREMENT PRIMARY KEY, job_id BIGINT NOT NULL, technician_id BIGINT NOT NULL, latitude DECIMAL(10,7) NOT NULL CHECK (latitude BETWEEN -90 AND 90), longitude DECIMAL(10,7) NOT NULL CHECK (longitude BETWEEN -180 AND 180), accuracy_meters DECIMAL(8,2), created_at DATETIME DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY(job_id) REFERENCES technician_jobs(id) ON DELETE CASCADE, FOREIGN KEY(technician_id) REFERENCES technicians(id));
CREATE TABLE job_completion_otps (id BIGINT AUTO_INCREMENT PRIMARY KEY, job_id BIGINT NOT NULL, otp_hash VARCHAR(255) NOT NULL, expires_at DATETIME NOT NULL, attempts SMALLINT DEFAULT 0, consumed_at DATETIME, created_at DATETIME DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY(job_id) REFERENCES technician_jobs(id) ON DELETE CASCADE);
CREATE TABLE whatsapp_notification_logs (id BIGINT AUTO_INCREMENT PRIMARY KEY, job_id BIGINT NOT NULL, customer_user_id BIGINT, event_key VARCHAR(80) NOT NULL, recipient VARCHAR(30), message TEXT NOT NULL, status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','sent','failed','skipped')), provider_message_id VARCHAR(255), error_message TEXT, attempted_at DATETIME, created_at DATETIME DEFAULT CURRENT_TIMESTAMP, UNIQUE(job_id,event_key), FOREIGN KEY(job_id) REFERENCES technician_jobs(id) ON DELETE CASCADE, FOREIGN KEY(customer_user_id) REFERENCES users(id));

CREATE TABLE notifications (id BIGINT AUTO_INCREMENT PRIMARY KEY, user_id BIGINT NOT NULL, channel VARCHAR(20), title VARCHAR(160), body TEXT, read_at DATETIME, created_at DATETIME DEFAULT CURRENT_TIMESTAMP, event_key VARCHAR(120), data JSON, FOREIGN KEY(user_id) REFERENCES users(id));
CREATE TABLE device_tokens (id BIGINT AUTO_INCREMENT PRIMARY KEY, user_id BIGINT NOT NULL, token TEXT NOT NULL, platform VARCHAR(20) DEFAULT 'web', active BOOLEAN DEFAULT TRUE, last_seen_at DATETIME DEFAULT CURRENT_TIMESTAMP, created_at DATETIME DEFAULT CURRENT_TIMESTAMP, UNIQUE(token(255)), FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE);
CREATE TABLE notification_templates (id BIGINT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(120) NOT NULL, event_key VARCHAR(120) UNIQUE NOT NULL, title VARCHAR(160) NOT NULL, body TEXT NOT NULL, channels JSON, status BOOLEAN DEFAULT TRUE, updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, category VARCHAR(30) DEFAULT 'order');
CREATE TABLE notification_deliveries (id BIGINT AUTO_INCREMENT PRIMARY KEY, user_id BIGINT, template_id BIGINT, channel VARCHAR(20) NOT NULL, title VARCHAR(160), body TEXT, status VARCHAR(20) NOT NULL, provider_id VARCHAR(255), error_message TEXT, attempted_at DATETIME, created_at DATETIME DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY(user_id) REFERENCES users(id), FOREIGN KEY(template_id) REFERENCES notification_templates(id) ON DELETE SET NULL);
CREATE TABLE audit_logs (id BIGINT AUTO_INCREMENT PRIMARY KEY, user_id BIGINT, action VARCHAR(100), entity_type VARCHAR(60), entity_id BIGINT, metadata JSON, created_at DATETIME DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY(user_id) REFERENCES users(id));
CREATE TABLE settings (id BIGINT AUTO_INCREMENT PRIMARY KEY, setting_key VARCHAR(120) UNIQUE NOT NULL, value JSON NOT NULL, updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP);

CREATE TABLE ai_conversations (id BIGINT AUTO_INCREMENT PRIMARY KEY, user_id BIGINT, question TEXT NOT NULL, response TEXT, escalation_status VARCHAR(30) DEFAULT 'none', created_at DATETIME DEFAULT CURRENT_TIMESTAMP, metadata JSON, FOREIGN KEY(user_id) REFERENCES users(id));
CREATE TABLE ai_messages (id BIGINT AUTO_INCREMENT PRIMARY KEY, conversation_id BIGINT NOT NULL, role VARCHAR(20) NOT NULL CHECK (role IN ('user','assistant','system')), content TEXT NOT NULL, provider_message_id VARCHAR(160), metadata JSON, created_at DATETIME DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY(conversation_id) REFERENCES ai_conversations(id) ON DELETE CASCADE);
CREATE TABLE ai_leads (id BIGINT AUTO_INCREMENT PRIMARY KEY, customer_id BIGINT, requirement TEXT, product VARCHAR(160), estimated_budget DECIMAL(12,2), contact VARCHAR(190), status VARCHAR(30) DEFAULT 'new', created_at DATETIME DEFAULT CURRENT_TIMESTAMP, metadata JSON, conversation_id BIGINT, FOREIGN KEY(customer_id) REFERENCES customers(id), FOREIGN KEY(conversation_id) REFERENCES ai_conversations(id) ON DELETE SET NULL);
CREATE TABLE ai_knowledge_base (id BIGINT AUTO_INCREMENT PRIMARY KEY, title VARCHAR(180) NOT NULL, category VARCHAR(80), content TEXT NOT NULL, status BOOLEAN DEFAULT TRUE, embedding JSON, created_at DATETIME DEFAULT CURRENT_TIMESTAMP, updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP);
CREATE TABLE ai_settings (id BIGINT AUTO_INCREMENT PRIMARY KEY, `key` VARCHAR(100) UNIQUE NOT NULL, value JSON NOT NULL, updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP);
CREATE TABLE ai_jobs (id BIGINT AUTO_INCREMENT PRIMARY KEY, kind VARCHAR(60) NOT NULL, status VARCHAR(30) DEFAULT 'queued', payload JSON NOT NULL, result JSON, error TEXT, created_at DATETIME DEFAULT CURRENT_TIMESTAMP, updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP);

CREATE TABLE design_categories (id BIGINT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(120) UNIQUE NOT NULL, status BOOLEAN DEFAULT TRUE);
CREATE TABLE design_styles (id BIGINT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(120) UNIQUE NOT NULL, description TEXT, status BOOLEAN DEFAULT TRUE);
CREATE TABLE design_prompt_templates (id BIGINT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(120) UNIQUE NOT NULL, template TEXT NOT NULL, supported_sign_types JSON, status BOOLEAN DEFAULT TRUE);
CREATE TABLE example_designs (id BIGINT AUTO_INCREMENT PRIMARY KEY, title VARCHAR(160) NOT NULL, category_id BIGINT, style_id BIGINT, sign_type VARCHAR(120), image_url TEXT, prompt TEXT, status BOOLEAN DEFAULT TRUE, created_at DATETIME DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY(category_id) REFERENCES design_categories(id), FOREIGN KEY(style_id) REFERENCES design_styles(id));
CREATE TABLE design_requests (id BIGINT AUTO_INCREMENT PRIMARY KEY, customer_id BIGINT, order_id BIGINT, requirements JSON NOT NULL, status VARCHAR(30) DEFAULT 'requested', created_at DATETIME DEFAULT CURRENT_TIMESTAMP, admin_notes TEXT, customer_notes TEXT, metadata JSON, updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, FOREIGN KEY(customer_id) REFERENCES customers(id), FOREIGN KEY(order_id) REFERENCES orders(id));
CREATE TABLE design_concepts (id BIGINT AUTO_INCREMENT PRIMARY KEY, request_id BIGINT, image_url TEXT, prompt TEXT, status VARCHAR(30) DEFAULT 'concept', admin_notes TEXT, created_at DATETIME DEFAULT CURRENT_TIMESTAMP, quotation_id BIGINT, order_id BIGINT, customer_notes TEXT, FOREIGN KEY(request_id) REFERENCES design_requests(id) ON DELETE CASCADE, FOREIGN KEY(quotation_id) REFERENCES quotations(id), FOREIGN KEY(order_id) REFERENCES orders(id));
CREATE TABLE design_files (id BIGINT AUTO_INCREMENT PRIMARY KEY, request_id BIGINT NOT NULL, concept_id BIGINT, file_kind VARCHAR(30) NOT NULL CHECK (file_kind IN ('request_attachment','concept')), original_name VARCHAR(255) NOT NULL, storage_key VARCHAR(255) UNIQUE NOT NULL, mime_type VARCHAR(80) NOT NULL, size_bytes BIGINT NOT NULL CHECK (size_bytes > 0 AND size_bytes <= 8388608), uploaded_by BIGINT, created_at DATETIME DEFAULT CURRENT_TIMESTAMP, CHECK ((file_kind='concept' AND concept_id IS NOT NULL) OR (file_kind='request_attachment' AND concept_id IS NULL)), FOREIGN KEY(request_id) REFERENCES design_requests(id) ON DELETE CASCADE, FOREIGN KEY(concept_id) REFERENCES design_concepts(id) ON DELETE CASCADE, FOREIGN KEY(uploaded_by) REFERENCES users(id));

CREATE TABLE payments (id BIGINT AUTO_INCREMENT PRIMARY KEY, quotation_id BIGINT, order_id BIGINT, amount DECIMAL(12,2) NOT NULL, status VARCHAR(30) CHECK (status IN ('created','pending','initialization_failed','authorized','captured','failed','cancelled','partially_refunded','refunded')), reference VARCHAR(120) UNIQUE, created_at DATETIME DEFAULT CURRENT_TIMESTAMP, payment_type VARCHAR(20) DEFAULT 'full', provider VARCHAR(60), provider_payment_id VARCHAR(160), currency CHAR(3) DEFAULT 'INR', metadata JSON, captured_at DATETIME, verified_at DATETIME, refunded_amount DECIMAL(12,2) DEFAULT 0, updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, provider_order_id VARCHAR(160), idempotency_key VARCHAR(120) UNIQUE, failure_code VARCHAR(120), failure_description TEXT, attempt_count INT NOT NULL DEFAULT 0, UNIQUE(provider,provider_order_id), FOREIGN KEY(quotation_id) REFERENCES quotations(id));
ALTER TABLE payments ADD COLUMN order_id BIGINT NULL;
CREATE INDEX idx_payments_order_id ON payments(order_id);
ALTER TABLE payments ADD CONSTRAINT fk_payments_order_id FOREIGN KEY(order_id) REFERENCES orders(id);
CREATE TABLE payment_webhook_events (id BIGINT AUTO_INCREMENT PRIMARY KEY, provider VARCHAR(60) NOT NULL, event_id VARCHAR(190) NOT NULL, payload JSON NOT NULL, processed_at DATETIME DEFAULT CURRENT_TIMESTAMP, UNIQUE(provider,event_id));
CREATE TABLE payment_refunds (id BIGINT AUTO_INCREMENT PRIMARY KEY, payment_id BIGINT NOT NULL, amount DECIMAL(12,2) NOT NULL, status VARCHAR(20) NOT NULL CHECK (status IN ('initializing','pending','processed','failed')), reference VARCHAR(120) NOT NULL UNIQUE, provider_refund_id VARCHAR(160) UNIQUE, idempotency_key VARCHAR(120) NOT NULL UNIQUE, reason VARCHAR(1000) NOT NULL, created_by BIGINT NOT NULL, metadata JSON, created_at DATETIME DEFAULT CURRENT_TIMESTAMP, updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, FOREIGN KEY(payment_id) REFERENCES payments(id), FOREIGN KEY(created_by) REFERENCES users(id));
CREATE INDEX idx_payment_refunds_payment_status ON payment_refunds(payment_id,status);
CREATE TABLE reviews (id BIGINT AUTO_INCREMENT PRIMARY KEY, customer_id BIGINT, job_id BIGINT, rating SMALLINT CHECK (rating BETWEEN 1 AND 5), comment TEXT, created_at DATETIME DEFAULT CURRENT_TIMESTAMP, order_id BIGINT, review_type VARCHAR(20) NOT NULL DEFAULT 'service', UNIQUE(customer_id,job_id), UNIQUE(customer_id,order_id), CHECK ((job_id IS NOT NULL AND order_id IS NULL AND review_type='service') OR (job_id IS NULL AND order_id IS NOT NULL AND review_type='order')), FOREIGN KEY(customer_id) REFERENCES customers(id), FOREIGN KEY(job_id) REFERENCES technician_jobs(id), FOREIGN KEY(order_id) REFERENCES orders(id) ON DELETE CASCADE);

CREATE TABLE auth_otps (id BIGINT AUTO_INCREMENT PRIMARY KEY, user_id BIGINT NOT NULL, purpose VARCHAR(30) NOT NULL, otp_hash VARCHAR(255) NOT NULL, expires_at DATETIME NOT NULL, consumed_at DATETIME, attempts SMALLINT DEFAULT 0, created_at DATETIME DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE);
CREATE TABLE technician_registration_otps (id BIGINT AUTO_INCREMENT PRIMARY KEY, email VARCHAR(190), mobile VARCHAR(20), otp_hash VARCHAR(255) NOT NULL, expires_at DATETIME NOT NULL, consumed_at DATETIME, attempts SMALLINT NOT NULL DEFAULT 0, created_at DATETIME DEFAULT CURRENT_TIMESTAMP);
ALTER TABLE technician_registration_otps ADD COLUMN email VARCHAR(190);
ALTER TABLE technician_registration_otps MODIFY mobile VARCHAR(20) NULL;
CREATE TABLE revoked_tokens (jti VARCHAR(80) PRIMARY KEY, user_id BIGINT, expires_at DATETIME NOT NULL, created_at DATETIME DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE);
CREATE TABLE support_escalations (id BIGINT AUTO_INCREMENT PRIMARY KEY, conversation_id BIGINT, user_id BIGINT, reason TEXT, status VARCHAR(30) DEFAULT 'open', created_at DATETIME DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY(conversation_id) REFERENCES ai_conversations(id), FOREIGN KEY(user_id) REFERENCES users(id));
CREATE TABLE allowed_cities (id BIGINT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(120) NOT NULL, state VARCHAR(120), country VARCHAR(120) NOT NULL DEFAULT 'India', latitude DECIMAL(10,7) NOT NULL CHECK (latitude BETWEEN -90 AND 90), longitude DECIMAL(10,7) NOT NULL CHECK (longitude BETWEEN -180 AND 180), radius_km DECIMAL(8,2) NOT NULL DEFAULT 25 CHECK (radius_km > 0 AND radius_km <= 500), active BOOLEAN NOT NULL DEFAULT TRUE, created_at DATETIME DEFAULT CURRENT_TIMESTAMP, updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, UNIQUE(name,state,country));
CREATE TABLE business_sequences (sequence_key VARCHAR(80) PRIMARY KEY, current_value BIGINT NOT NULL CHECK (current_value > 0), updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP);

CREATE TABLE customer_wallets (id BIGINT AUTO_INCREMENT PRIMARY KEY, customer_id BIGINT UNIQUE NOT NULL, balance DECIMAL(12,2) NOT NULL DEFAULT 0.00 CHECK (balance >= 0), total_cashback_earned DECIMAL(12,2) NOT NULL DEFAULT 0.00 CHECK (total_cashback_earned >= 0), created_at DATETIME DEFAULT CURRENT_TIMESTAMP, updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, FOREIGN KEY(customer_id) REFERENCES customers(id) ON DELETE CASCADE);
CREATE TABLE wallet_transactions (id BIGINT AUTO_INCREMENT PRIMARY KEY, wallet_id BIGINT NOT NULL, customer_id BIGINT NOT NULL, order_id BIGINT, quotation_id BIGINT, transaction_type VARCHAR(30) NOT NULL CHECK (transaction_type IN ('cashback_credit','wallet_debit','admin_adjustment')), amount DECIMAL(12,2) NOT NULL, balance_after DECIMAL(12,2) NOT NULL, description TEXT NOT NULL, created_at DATETIME DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY(wallet_id) REFERENCES customer_wallets(id) ON DELETE CASCADE, FOREIGN KEY(customer_id) REFERENCES customers(id) ON DELETE CASCADE, FOREIGN KEY(order_id) REFERENCES orders(id) ON DELETE SET NULL, FOREIGN KEY(quotation_id) REFERENCES quotations(id) ON DELETE SET NULL);

CREATE TABLE order_status_history (id BIGINT AUTO_INCREMENT PRIMARY KEY, order_id BIGINT NOT NULL, status VARCHAR(40) NOT NULL, notes TEXT, created_by BIGINT, created_at DATETIME DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY(order_id) REFERENCES orders(id) ON DELETE CASCADE, FOREIGN KEY(created_by) REFERENCES users(id));
CREATE TABLE order_whatsapp_logs (id BIGINT AUTO_INCREMENT PRIMARY KEY, order_id BIGINT NOT NULL, customer_user_id BIGINT, event_key VARCHAR(80) NOT NULL, recipient VARCHAR(30), message TEXT NOT NULL, status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','sent','failed','skipped')), provider_message_id VARCHAR(255), error_message TEXT, attempted_at DATETIME, created_at DATETIME DEFAULT CURRENT_TIMESTAMP, UNIQUE(order_id,event_key), FOREIGN KEY(order_id) REFERENCES orders(id) ON DELETE CASCADE, FOREIGN KEY(customer_user_id) REFERENCES users(id));
CREATE TABLE order_email_logs (id BIGINT AUTO_INCREMENT PRIMARY KEY, order_id BIGINT NOT NULL, customer_user_id BIGINT, event_key VARCHAR(120) NOT NULL, recipient VARCHAR(190), subject VARCHAR(255), body TEXT, status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','sent','failed','skipped')), provider_message_id VARCHAR(255), error_message TEXT, attempted_at DATETIME, created_at DATETIME DEFAULT CURRENT_TIMESTAMP, INDEX idx_order_email_logs_order(order_id), INDEX idx_order_email_logs_created(created_at DESC), FOREIGN KEY(order_id) REFERENCES orders(id) ON DELETE CASCADE, FOREIGN KEY(customer_user_id) REFERENCES users(id));

CREATE INDEX idx_notification_deliveries_created ON notification_deliveries(created_at DESC);
CREATE INDEX idx_device_tokens_user ON device_tokens(user_id,active);
CREATE INDEX idx_customer_addresses_customer ON customer_addresses(customer_id);
CREATE INDEX idx_notifications_user_created ON notifications(user_id,created_at DESC);
CREATE INDEX idx_auth_otps_user_purpose ON auth_otps(user_id,purpose,created_at DESC);
CREATE INDEX idx_technician_registration_otps_mobile ON technician_registration_otps(mobile,created_at DESC);
CREATE INDEX idx_technician_registration_otps_email ON technician_registration_otps(email,created_at DESC);
CREATE INDEX idx_orders_customer_status ON orders(customer_id,status);
CREATE INDEX idx_orders_customer_created ON orders(customer_id,created_at DESC);
CREATE INDEX idx_tickets_customer_status ON service_tickets(customer_id,status);
CREATE INDEX idx_tickets_customer_created ON service_tickets(customer_id,created_at DESC);
CREATE INDEX idx_jobs_technician_status ON technician_jobs(technician_id,status);
CREATE INDEX idx_jobs_ticket ON technician_jobs(ticket_id);
CREATE INDEX idx_assets_customer_id_desc ON sign_board_assets(customer_id,id DESC);
CREATE INDEX idx_assets_order_id ON sign_board_assets(order_id);
CREATE INDEX idx_assets_status ON sign_board_assets(status);
CREATE INDEX idx_asset_history_asset_id_desc ON asset_service_history(asset_id,id DESC);
CREATE INDEX idx_payments_quotation_id_desc ON payments(quotation_id,id DESC);
CREATE INDEX idx_payments_quotation_status ON payments(quotation_id,status);
CREATE INDEX idx_ai_conversations_user_id_desc ON ai_conversations(user_id,id DESC);
CREATE INDEX idx_ai_messages_conversation ON ai_messages(conversation_id,id);
CREATE INDEX idx_ai_leads_conversation ON ai_leads(conversation_id);
CREATE INDEX idx_job_history_job_created ON job_status_history(job_id,created_at DESC);
CREATE INDEX idx_job_photos_job_created ON job_photos(job_id,created_at);
CREATE INDEX idx_job_materials_job ON job_materials(job_id);
CREATE INDEX idx_job_locations_job_created ON job_location_updates(job_id,created_at DESC);
CREATE INDEX idx_job_completion_otps_active ON job_completion_otps(job_id,created_at DESC);
CREATE INDEX idx_allowed_cities_active ON allowed_cities(active);
CREATE INDEX idx_whatsapp_logs_created ON whatsapp_notification_logs(created_at DESC);
CREATE INDEX idx_design_files_request ON design_files(request_id,id);
CREATE INDEX idx_design_files_concept ON design_files(concept_id);
CREATE INDEX idx_quotations_customer_created ON quotations(customer_id,created_at DESC);
CREATE INDEX idx_quotations_status_updated ON quotations(status,updated_at DESC);
CREATE INDEX idx_quotations_valid_until ON quotations(valid_until);
CREATE INDEX idx_quotation_items_quotation ON quotation_items(quotation_id,id);
CREATE INDEX idx_quotation_history_quotation ON quotation_status_history(quotation_id,id);
CREATE INDEX idx_quotation_revisions_quotation ON quotation_revisions(quotation_id,version DESC);
CREATE INDEX idx_customer_wallets_customer ON customer_wallets(customer_id);
CREATE INDEX idx_wallet_transactions_customer ON wallet_transactions(customer_id,created_at DESC);
CREATE INDEX idx_order_status_history_order ON order_status_history(order_id,created_at);
CREATE INDEX idx_order_whatsapp_logs_created ON order_whatsapp_logs(created_at DESC);
CREATE TABLE order_shipments (id BIGINT AUTO_INCREMENT PRIMARY KEY, order_id BIGINT NOT NULL, provider VARCHAR(30) NOT NULL DEFAULT 'delhivery', waybill VARCHAR(40) NOT NULL UNIQUE, status VARCHAR(80), status_type VARCHAR(10), status_location VARCHAR(160), status_at VARCHAR(40), expected_delivery VARCHAR(40), origin VARCHAR(120), destination VARCHAR(120), delivered BOOLEAN NOT NULL DEFAULT FALSE, scans JSON, last_error TEXT, last_synced_at DATETIME, created_by BIGINT, created_at DATETIME DEFAULT CURRENT_TIMESTAMP, updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, INDEX idx_order_shipments_order(order_id), FOREIGN KEY(order_id) REFERENCES orders(id) ON DELETE CASCADE, FOREIGN KEY(created_by) REFERENCES users(id));

-- Read-only directory views used by the admin catalog listing.
CREATE OR REPLACE VIEW customer_directory AS SELECT c.id,u.name,u.email,u.mobile,c.company_name,c.address,u.status,u.created_at FROM customers c JOIN users u ON u.id=c.user_id;
CREATE OR REPLACE VIEW technician_directory AS SELECT t.id,u.name,u.email,u.mobile,t.service_areas,u.status,u.created_at FROM technicians t JOIN users u ON u.id=t.user_id;
CREATE OR REPLACE VIEW quotation_directory AS SELECT q.id,q.quotation_no AS `quotationNo`,o.order_no AS `orderNo`,q.final_amount AS `finalAmount`,q.valid_until AS `validUntil`,q.status FROM quotations q JOIN orders o ON o.id=q.order_id;
CREATE OR REPLACE VIEW asset_directory AS SELECT a.id,a.asset_no AS `assetNo`,u.name AS customer,a.details,a.location,a.warranty_until AS `warrantyUntil`,a.created_at AS `createdAt` FROM sign_board_assets a JOIN customers c ON c.id=a.customer_id JOIN users u ON u.id=c.user_id;
CREATE OR REPLACE VIEW notification_directory AS SELECT n.id,u.email,n.channel,n.title,n.body,n.read_at AS `readAt`,n.created_at AS `createdAt` FROM notifications n JOIN users u ON u.id=n.user_id;

-- Upgrades for databases created before these columns existed.
ALTER TABLE ai_knowledge_base ADD COLUMN embedding JSON;
ALTER TABLE technicians ADD COLUMN employee_id VARCHAR(80);
ALTER TABLE technicians ADD COLUMN date_of_joining DATE;
ALTER TABLE technicians ADD COLUMN terms_accepted_at DATETIME;
-- Delhivery AWB cache on orders. The per-shipment detail stays in
-- order_shipments (waybill UNIQUE); these columns give fast idempotent lookup
-- and a failure record for orders that have no waybill yet.
ALTER TABLE orders ADD COLUMN delhivery_awb VARCHAR(40) NULL;
ALTER TABLE orders ADD COLUMN shipment_status VARCHAR(20) NOT NULL DEFAULT 'PENDING';
ALTER TABLE orders ADD COLUMN shipment_error TEXT NULL;
CREATE INDEX idx_orders_delhivery_awb ON orders(delhivery_awb);
