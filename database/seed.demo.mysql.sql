-- MySQL development demo accounts. Applied by server/migrate.js only when
-- NODE_ENV is not "production". All demo passwords are SignFix@123.
-- The product/material/service catalog is in seed.mysql.sql.
INSERT INTO users(role_id,name,email,mobile,password_hash,status)
SELECT r.id,v.name,v.email,v.mobile,'$2b$10$N7YMUi7f4qo0wnpExQagQuR7tpjUD3rcOabitmozbImGYkOhlSYW6','active'
FROM (SELECT 'super_admin' AS role,'Arun Kumar' AS name,'admin@signfix.in' AS email,'9999999999' AS mobile
      UNION ALL SELECT 'customer','Demo Customer','customer@signfix.in','9876543210'
      UNION ALL SELECT 'technician','Demo Technician','tech@signfix.in','9812345678') v
JOIN roles r ON r.name=v.role
ON DUPLICATE KEY UPDATE role_id=VALUES(role_id),name=VALUES(name),mobile=VALUES(mobile),password_hash=VALUES(password_hash),status='active';
INSERT IGNORE INTO customers(user_id,company_name,address) SELECT id,'Demo Retail','{"city":"Bengaluru","state":"Karnataka"}' FROM users WHERE email='customer@signfix.in';
INSERT IGNORE INTO technicians(user_id,service_areas) SELECT id,'["Bengaluru"]' FROM users WHERE email='tech@signfix.in';
