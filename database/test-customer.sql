-- One-off test customer for manual testing. Run once in phpMyAdmin on the
-- SignFix database. Login: testcustomer@signfix.in / TestCustomer@2025
INSERT INTO users(role_id,name,email,mobile,password_hash,status,verified_at)
SELECT id,'Test Customer','testcustomer@signfix.in','919000000001','$2b$12$rqN1r6h1cbpRDW9t5ewiJOhaWTA.xMDnVjCO7468m8guSMVOQjFDK','active',NOW()
FROM roles WHERE name='customer';

INSERT INTO customers(user_id,company_name,address,payments_enabled)
SELECT id,'Test Signs Pvt Ltd','{"addressLine":"12 MG Road","city":"Bengaluru","state":"Karnataka","pincode":"560001"}',FALSE
FROM users WHERE email='testcustomer@signfix.in';

INSERT INTO customer_addresses(customer_id,label,address_line,city,state,pincode,is_default)
SELECT c.id,'Primary','12 MG Road','Bengaluru','Karnataka','560001',TRUE
FROM customers c JOIN users u ON u.id=c.user_id WHERE u.email='testcustomer@signfix.in';
