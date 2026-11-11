-- MySQL reference data required by every environment (roles, permissions,
-- notification templates). Idempotent: applied automatically by server/migrate.js.
-- Includes the starter catalog (products, materials, lighting, service categories).
-- Demo users live in seed.demo.mysql.sql (never applied in production).
INSERT IGNORE INTO roles(name) VALUES ('super_admin'),('admin'),('sales_manager'),('service_manager'),('technician_manager'),('support_agent'),('customer'),('technician');
INSERT INTO permissions(name,description) VALUES
('customer.view','View customers'),('customer.create','Create customers'),('customer.update','Update customers'),('customer.disable','Disable customers'),
('product.view','View catalog'),('product.create','Create catalog records'),('product.update','Update catalog records'),('product.delete','Disable catalog records'),
('pricing.view','View pricing'),('pricing.create','Create pricing rules'),('pricing.update','Update pricing rules'),
('order.view','View orders'),('order.update','Update orders'),('order.approve','Approve orders'),('order.cancel','Cancel orders'),
('quotation.view','View quotations'),('quotation.create','Create quotations'),('quotation.update','Update quotations'),('quotation.edit','Edit draft quotations'),('quotation.send','Send quotations'),('quotation.cancel','Cancel quotations'),('quotation.download','Download quotation PDFs'),('quotation.manage_revisions','Create and view quotation revisions'),('quotation.view_own','View own quotations'),('quotation.approve_own','Approve own quotations'),('quotation.request_changes_own','Request changes to own quotations'),('quotation.reject_own','Reject own quotations'),('quotation.download_own','Download own quotation PDFs'),
('service.view','View services'),('service.create','Create services'),('service.update','Update services'),('service.assign','Assign services'),('service.close','Close services'),
('technician.view','View technicians'),('technician.create','Create technicians'),('technician.update','Update technicians'),('technician.assign','Assign technicians'),
('asset.view','View assets'),('asset.create','Create assets'),('asset.update','Update assets'),('reports.view','View reports'),('reports.export','Export reports'),
('ai.view','View AI records'),('ai.create','Create AI records'),('ai.update','Update AI records'),('ai.delete','Disable AI records'),
('notifications.view','View notifications'),('settings.view','View settings'),('settings.create','Create settings'),('settings.update','Update settings'),('settings.delete','Delete settings'),
('audit.view','View audit logs')
ON DUPLICATE KEY UPDATE description=VALUES(description);
INSERT IGNORE INTO role_permissions(role_id,permission_id)
SELECT r.id,p.id FROM roles r CROSS JOIN permissions p WHERE r.name='admin';
INSERT IGNORE INTO role_permissions(role_id,permission_id)
SELECT r.id,p.id FROM roles r JOIN permissions p ON
 (r.name='sales_manager' AND (p.name LIKE 'customer.%' OR p.name LIKE 'product.%' OR p.name LIKE 'pricing.%' OR p.name LIKE 'order.%' OR p.name IN ('quotation.view','quotation.create','quotation.update','quotation.edit','quotation.send','quotation.cancel','quotation.download','quotation.manage_revisions') OR p.name LIKE 'ai.%' OR p.name='reports.view')) OR
 (r.name='service_manager' AND (p.name LIKE 'customer.view' OR p.name LIKE 'service.%' OR p.name LIKE 'technician.view' OR p.name LIKE 'asset.%' OR p.name='reports.view')) OR
 (r.name='technician_manager' AND (p.name LIKE 'technician.%' OR p.name LIKE 'service.%' OR p.name LIKE 'asset.view' OR p.name='reports.view')) OR
 (r.name='support_agent' AND p.name IN ('customer.view','order.view','quotation.view','quotation.download','service.view','asset.view','ai.view','notifications.view'));
INSERT IGNORE INTO role_permissions(role_id,permission_id)
SELECT r.id,p.id FROM roles r JOIN permissions p ON
 (r.name='customer' AND p.name IN ('product.view','pricing.view','order.view','quotation.view_own','quotation.approve_own','quotation.request_changes_own','quotation.reject_own','quotation.download_own','service.view','asset.view','notifications.view')) OR
 (r.name='technician' AND p.name IN ('service.view','asset.view','notifications.view'));
INSERT IGNORE INTO notification_templates(name,event_key,category,title,body,channels,status) VALUES
('Order update','order.status','order','Order {{orderNo}} updated','Your order is now {{status}}.','["push","email"]',TRUE),
('Quotation ready','quotation.sent','quotation','Quotation {{quotationNo}} ready','Your quotation is ready for review.','["push","email","whatsapp"]',TRUE),
('Payment receipt','payment.received','payment','Payment received','We received your payment of {{amount}}.','["push","email"]',TRUE),
('Service update','service.status','service','Service {{ticketNo}} updated','Your service request is now {{status}}.','["push","whatsapp"]',TRUE),
('Technician assigned','technician.assigned','technician','Technician assigned','{{technicianName}} has been assigned to your request.','["push","whatsapp"]',TRUE),
('Work completed','completion.done','completion','Work completed','Work for {{ticketNo}} has been completed.','["push","email","whatsapp"]',TRUE),
('Promotion','promotion.campaign','promotion','{{offerTitle}}','{{offerMessage}}','["push","email"]',TRUE);

-- Starter catalog. Rows are only added when missing, so admin edits are kept.
INSERT INTO products(name,category,description,pricing_method,status,is_discounted)
SELECT v.* FROM (SELECT 'LED Sign Board' AS name,'Illuminated' AS category,'Energy-efficient LED signage' AS description,'sqft' AS pricing_method,TRUE AS status,TRUE AS is_discounted
      UNION ALL SELECT 'Acrylic Sign Board','Premium','Premium acrylic signage','sqft',TRUE,TRUE
      UNION ALL SELECT 'Flex Sign Board','Economy','Printed flex signage','sqft',TRUE,FALSE
      UNION ALL SELECT 'Neon Sign','Decorative','Custom neon concept','sqft',TRUE,FALSE
      UNION ALL SELECT 'Glow Sign Board','Illuminated','Illuminated glow signage','sqft',TRUE,FALSE
      UNION ALL SELECT '3D Letter','Letters','Dimensional letter signage','sqft',TRUE,FALSE
      UNION ALL SELECT 'Channel Letter','Letters','Fabricated channel letters','sqft',TRUE,FALSE
      UNION ALL SELECT 'Backlit Sign','Illuminated','Backlit signage','sqft',TRUE,FALSE
      UNION ALL SELECT 'Outdoor Signage','Outdoor','Weather-resistant outdoor signage','sqft',TRUE,FALSE
      UNION ALL SELECT 'Custom Sign Board','Custom','Custom sign board requirement','sqft',TRUE,FALSE
      UNION ALL SELECT 'Other','Custom','Other signage requirement','sqft',TRUE,FALSE) v
WHERE NOT EXISTS (SELECT 1 FROM products p WHERE p.name=v.name);
INSERT INTO pricing_rules(product_id,rule_type,amount,tax_rate)
SELECT p.id,'base_sqft',v.amount,18
FROM (SELECT 'LED Sign Board' AS name,850 AS amount UNION ALL SELECT 'Acrylic Sign Board',650 UNION ALL SELECT 'Flex Sign Board',280 UNION ALL SELECT 'Neon Sign',1100) v
JOIN products p ON p.name=v.name
WHERE NOT EXISTS (SELECT 1 FROM pricing_rules pr WHERE pr.product_id=p.id AND pr.rule_type='base_sqft');
INSERT IGNORE INTO product_categories(name) VALUES ('Illuminated'),('Non-illuminated'),('Letters'),('Outdoor'),('Custom');
INSERT IGNORE INTO materials(name,price_per_sqft) VALUES ('Acrylic',100),('ACP',130),('PVC',80),('Flex',50),('Stainless Steel',250),('Aluminium',180),('Other',0);
INSERT IGNORE INTO lighting_options(name,price_per_sqft) VALUES ('No Lighting',0),('LED',120),('Backlit',160),('Neon',240),('Front Lit',140),('Custom',0);
INSERT IGNORE INTO service_categories(name) VALUES ('LED Problem'),('Electrical Issue'),('Physical Damage'),('Sign Board Repair'),('Replacement'),('Installation'),('Reinstallation'),('Cleaning'),('Maintenance'),('Inspection'),('Emergency'),('Other');
