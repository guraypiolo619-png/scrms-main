-- ============================================
-- SUPPLY CHAIN MANAGEMENT SYSTEM (SCMS)
-- Database Script for MySQL
-- ============================================

-- Create the database
CREATE DATABASE IF NOT EXISTS SCMS;

-- Use the database
USE SCMS;

-- ============================================
-- TABLE: users (for admin login)
-- ============================================
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert default admin user
-- Username: admin, Password: admin123
INSERT IGNORE INTO users (username, password) VALUES ('admin', 'admin123');

-- ============================================
-- TABLE: Supplier
-- ============================================
CREATE TABLE IF NOT EXISTS Supplier (
    supplierCode INT AUTO_INCREMENT PRIMARY KEY,
    supplierName VARCHAR(255) NOT NULL,
    telephone VARCHAR(20),
    address TEXT,
    email VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- TABLE: Shipment
-- ============================================
CREATE TABLE IF NOT EXISTS Shipment (
    shipmentNumber INT AUTO_INCREMENT PRIMARY KEY,
    supplierCode INT NOT NULL,
    shipmentDate DATE NOT NULL,
    expectedDeliveryDate DATE NULL,
    shipmentStatus ENUM('Pending', 'In Transit', 'Delivered', 'Cancelled') DEFAULT 'Pending',
    destination VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    -- Foreign Key relationship to Supplier
    FOREIGN KEY (supplierCode) REFERENCES Supplier(supplierCode) ON DELETE CASCADE
);

-- ============================================
-- TABLE: Delivery
-- ============================================
CREATE TABLE IF NOT EXISTS Delivery (
    deliveryCode INT AUTO_INCREMENT PRIMARY KEY,
    shipmentNumber INT NOT NULL,
    deliveryDate DATE NOT NULL,
    quantityDelivered INT NOT NULL,
    deliveryStatus ENUM('Pending', 'In Transit', 'Delivered', 'Failed') DEFAULT 'Pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    -- Foreign Key relationship to Shipment
    FOREIGN KEY (shipmentNumber) REFERENCES Shipment(shipmentNumber) ON DELETE CASCADE
);

-- ============================================
-- TABLE: integration_outbox (Gateway delivery queue)
-- ============================================
CREATE TABLE IF NOT EXISTS integration_outbox (
    event_id CHAR(36) NOT NULL PRIMARY KEY,
    correlation_id VARCHAR(255) NOT NULL,
    external_id VARCHAR(255) NOT NULL,
    event_type VARCHAR(100) NOT NULL,
    payload LONGTEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    gateway_status VARCHAR(20) NULL,
    attempt_count INT NOT NULL DEFAULT 0,
    next_attempt_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_error TEXT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX integration_outbox_due_idx (status, next_attempt_at, created_at)
);

-- ============================================
-- ERD EXPLANATION
-- ============================================
-- 
-- Entity Relationship Diagram:
-- 
--   Supplier (1) -------- (M) Shipment
--   Shipment (1) -------- (M) Delivery
-- 
-- Relationships:
-- 1. One Supplier can have Many Shipments (1:M)
--    - supplierCode in Shipment table references supplierCode in Supplier table
-- 
-- 2. One Shipment can have Many Deliveries (1:M)
--    - shipmentNumber in Delivery table references shipmentNumber in Shipment table
-- 
-- Primary Keys:
-- - Supplier: supplierCode (Auto Increment)
-- - Shipment: shipmentNumber (Auto Increment)
-- - Delivery: deliveryCode (Auto Increment)
-- - users: id (Auto Increment)
-- 
-- Foreign Keys:
-- - Shipment.supplierCode -> Supplier.supplierCode
-- - Delivery.shipmentNumber -> Shipment.shipmentNumber
-- 
-- Cardinalities:
-- - Supplier to Shipment: One-to-Many (1:M)
-- - Shipment to Delivery: One-to-Many (1:M)
-- ============================================

-- ============================================
-- SAMPLE DATA (Optional - for testing)
-- ============================================

-- Insert sample suppliers
INSERT INTO Supplier (supplierName, telephone, address, email) VALUES 
('ABC Supplies Co.', '+27-11-123-4567', '123 Main Street, Johannesburg', 'info@abcsupplies.co.za'),
('XYZ Logistics', '+27-21-987-6543', '456 Harbor Road, Cape Town', 'contact@xyzlogistics.co.za'),
('Global Traders', '+27-31-555-1234', '789 Trade Center, Durban', 'sales@globaltraders.co.za');

-- Insert sample shipments
INSERT INTO Shipment (supplierCode, shipmentDate, shipmentStatus, destination) VALUES 
(1, '2024-01-15', 'Delivered', 'Pretoria Distribution Center'),
(1, '2024-01-20', 'In Transit', 'Bloemfontein Warehouse'),
(2, '2024-01-18', 'Pending', 'Port Elizabeth Hub'),
(3, '2024-01-22', 'In Transit', 'East London Depot');

-- Insert sample deliveries
INSERT INTO Delivery (shipmentNumber, deliveryDate, quantityDelivered, deliveryStatus) VALUES 
(1, '2024-01-16', 100, 'Delivered'),
(1, '2024-01-17', 50, 'Delivered'),
(2, '2024-01-21', 75, 'In Transit'),
(3, '2024-01-19', 200, 'Pending'),
(4, '2024-01-23', 150, 'In Transit');