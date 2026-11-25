CREATE TABLE Customers (
    CustomerID INT PRIMARY KEY,
    CustomerName VARCHAR(100),
    SignupDate DATE
);

CREATE TABLE Stores (
    StoreID INT PRIMARY KEY,
    StoreName VARCHAR(100),
    RegionRaw VARCHAR(30)
);

CREATE TABLE Products (
    ProductID INT PRIMARY KEY,
    ProductName VARCHAR(100),
    Category VARCHAR(50)
);

CREATE TABLE Orders (
    OrderID INT PRIMARY KEY,
    OrderDate DATE,
    CustomerID INT,
    StoreID INT,
    OrderStatus VARCHAR(30)
);

CREATE TABLE OrderItems (
    OrderItemID INT,
    OrderID INT,
    ProductID INT,
    Quantity INT,
    UnitPrice NUMERIC(10,2),
    LoadedAt TIMESTAMP
);

CREATE TABLE Returns (
    ReturnID INT PRIMARY KEY,
    OrderItemID INT,
    ReturnDate DATE,
    ReturnQuantity INT
);
