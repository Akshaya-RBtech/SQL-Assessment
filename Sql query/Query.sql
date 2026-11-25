-- QUESTION 1 – STANDARDIZE STORE REGIONS

CREATE TABLE Regions (
    RegionID INT PRIMARY KEY,
    RegionName VARCHAR(30) UNIQUE
);

INSERT INTO Regions (RegionID, RegionName)
VALUES
    (1, 'North'),
    (2, 'South'),
    (3, 'West');

ALTER TABLE Stores
ADD COLUMN RegionID INT;

UPDATE Stores
SET RegionID = CASE
    WHEN UPPER(TRIM(RegionRaw)) IN ('N', 'NORTH') THEN 1
    WHEN UPPER(TRIM(RegionRaw)) IN ('S', 'SOUTH') THEN 2
    WHEN UPPER(TRIM(RegionRaw)) IN ('W', 'WEST') THEN 3
    ELSE NULL
END;


SELECT
    s.StoreID,
    s.StoreName,
    s.RegionRaw,
    r.RegionName
FROM Stores s
LEFT JOIN Regions r
    ON s.RegionID = r.RegionID
ORDER BY s.StoreID;

SELECT
    StoreID,
    StoreName,
    RegionRaw
FROM Stores
WHERE RegionID IS NULL
ORDER BY StoreID;


-- QUESTION 2 – REMOVE DUPLICATE ORDER LINES

DROP TABLE IF EXISTS CleanOrderItems;

CREATE TABLE CleanOrderItems AS
SELECT
    OrderItemID,
    OrderID,
    ProductID,
    Quantity,
    UnitPrice,
    LoadedAt
FROM (
    SELECT
        oi.*,
        ROW_NUMBER() OVER (
            PARTITION BY OrderItemID
            ORDER BY LoadedAt DESC NULLS LAST
        ) AS rn
    FROM OrderItems oi
) AS ranked
WHERE rn = 1;

SELECT *
FROM CleanOrderItems
ORDER BY OrderItemID;

SELECT COUNT(*) AS TotalCleanRecords
FROM CleanOrderItems;

-- QUESTION 4 – ORDERS WITH MATCHING CUSTOMERS

SELECT
    o.OrderID,
    o.CustomerID,
    c.CustomerName
FROM Orders o
INNER JOIN Customers c
    ON o.CustomerID = c.CustomerID
ORDER BY o.OrderID;


-- QUESTION 5 – ORDERS WITH UNMATCHED CUSTOMER IDs

SELECT
    o.OrderID,
    o.CustomerID
FROM Orders o
LEFT JOIN Customers c
    ON o.CustomerID = c.CustomerID
WHERE c.CustomerID IS NULL
ORDER BY o.OrderID;


-- QUESTION 6 – CUSTOMERS WITH NO ORDERS

SELECT
    c.CustomerID,
    c.CustomerName
FROM Customers c
LEFT JOIN Orders o
    ON c.CustomerID = o.CustomerID
WHERE o.OrderID IS NULL
ORDER BY c.CustomerID;


-- QUESTION 7 – ORDER LINES WITH MULTIPLE RETURNS

SELECT
    OrderItemID,
    COUNT(*) AS ReturnTransactionCount,
    SUM(ReturnQuantity) AS TotalReturnedUnits
FROM Returns
GROUP BY OrderItemID
HAVING COUNT(*) > 1
ORDER BY OrderItemID;


-- QUESTION 8 – REGIONAL SALES AND RETURNS
-- Query 1:

SELECT
    r.RegionName,
    COUNT(DISTINCT o.OrderID) AS CompletedOrderCount,
    SUM(coi.Quantity * coi.UnitPrice) AS GrossSalesUSD
FROM Orders o
JOIN Stores s
    ON o.StoreID = s.StoreID
JOIN Regions r
    ON s.RegionID = r.RegionID
JOIN CleanOrderItems coi
    ON o.OrderID = coi.OrderID
WHERE o.OrderStatus = 'Completed'
  AND o.OrderDate >= DATE '2026-10-01'
  AND o.OrderDate < DATE '2026-11-01'
GROUP BY r.RegionName
ORDER BY r.RegionName;

-- Query 2: 

SELECT
    r.RegionName,
    SUM(ret.ReturnQuantity * coi.UnitPrice) AS ReturnValue
FROM Returns ret
JOIN CleanOrderItems coi
    ON ret.OrderItemID = coi.OrderItemID
JOIN Orders o
    ON coi.OrderID = o.OrderID
JOIN Stores s
    ON o.StoreID = s.StoreID
JOIN Regions r
    ON s.RegionID = r.RegionID
WHERE o.OrderStatus = 'Completed'
  AND ret.ReturnDate >= DATE '2026-10-01'
  AND ret.ReturnDate < DATE '2026-11-01'
GROUP BY r.RegionName
ORDER BY r.RegionName;

-- QUESTION 9 – COMPARE THE REGIONS

WITH Sales AS (
    SELECT
        s.RegionID,
        SUM(coi.Quantity * coi.UnitPrice) AS GrossSales
    FROM Orders o
    JOIN Stores s
        ON o.StoreID = s.StoreID
    JOIN CleanOrderItems coi
        ON o.OrderID = coi.OrderID
    WHERE o.OrderStatus = 'Completed'
      AND o.OrderDate >= DATE '2026-10-01'
      AND o.OrderDate < DATE '2026-11-01'
    GROUP BY s.RegionID
),
ReturnData AS (
    SELECT
        s.RegionID,
        SUM(ret.ReturnQuantity * coi.UnitPrice) AS ReturnValue
    FROM Returns ret
    JOIN CleanOrderItems coi
        ON ret.OrderItemID = coi.OrderItemID
    JOIN Orders o
        ON coi.OrderID = o.OrderID
    JOIN Stores s
        ON o.StoreID = s.StoreID
    WHERE o.OrderStatus = 'Completed'
      AND ret.ReturnDate >= DATE '2026-10-01'
      AND ret.ReturnDate < DATE '2026-11-01'
    GROUP BY s.RegionID
),
RegionSummary AS (
    SELECT
        rg.RegionName,
        COALESCE(sa.GrossSales, 0) AS GrossSales,
        COALESCE(rt.ReturnValue, 0) AS ReturnValue,
        COALESCE(sa.GrossSales, 0)
            - COALESCE(rt.ReturnValue, 0) AS NetSales
    FROM Regions rg
    LEFT JOIN Sales sa
        ON rg.RegionID = sa.RegionID
    LEFT JOIN ReturnData rt
        ON rg.RegionID = rt.RegionID
),
RankedRegions AS (
    SELECT
        *,
        RANK() OVER (ORDER BY GrossSales DESC) AS GrossSalesRank,
        RANK() OVER (ORDER BY NetSales DESC) AS NetSalesRank
    FROM RegionSummary
)
SELECT
    RegionName,
    GrossSales,
    ReturnValue,
    NetSales,
    GrossSalesRank,
    NetSalesRank,
    MAX(NetSales) OVER () -
        NetSales AS DifferenceFromHighestNetSales
FROM RankedRegions
ORDER BY NetSales DESC;


-- QUESTION 10 – COMPARE STORES WITHIN EACH REGION
-- Query 1: October gross sales by store.

SELECT
    r.RegionName,
    s.StoreID,
    s.StoreName,
    SUM(coi.Quantity * coi.UnitPrice) AS GrossSales
FROM Orders o
JOIN Stores s
    ON o.StoreID = s.StoreID
JOIN Regions r
    ON s.RegionID = r.RegionID
JOIN CleanOrderItems coi
    ON o.OrderID = coi.OrderID
WHERE o.OrderStatus = 'Completed'
  AND o.OrderDate >= DATE '2026-10-01'
  AND o.OrderDate < DATE '2026-11-01'
GROUP BY r.RegionName, s.StoreID, s.StoreName
ORDER BY r.RegionName, s.StoreID;

-- Query 2: October return value by store.

SELECT
    r.RegionName,
    s.StoreID,
    s.StoreName,
    SUM(ret.ReturnQuantity * coi.UnitPrice) AS ReturnValue
FROM Returns ret
JOIN CleanOrderItems coi
    ON ret.OrderItemID = coi.OrderItemID
JOIN Orders o
    ON coi.OrderID = o.OrderID
JOIN Stores s
    ON o.StoreID = s.StoreID
JOIN Regions r
    ON s.RegionID = r.RegionID
WHERE o.OrderStatus = 'Completed'
  AND ret.ReturnDate >= DATE '2026-10-01'
  AND ret.ReturnDate < DATE '2026-11-01'
GROUP BY r.RegionName, s.StoreID, s.StoreName
ORDER BY r.RegionName, s.StoreID;

-- Query 3: calculate net sales, rank stores within each region,
-- and show each store's share of regional net sales.

WITH GrossData AS (
    SELECT
        o.StoreID,
        SUM(coi.Quantity * coi.UnitPrice) AS GrossSales
    FROM Orders o
    JOIN CleanOrderItems coi
        ON o.OrderID = coi.OrderID
    WHERE o.OrderStatus = 'Completed'
      AND o.OrderDate >= DATE '2026-10-01'
      AND o.OrderDate < DATE '2026-11-01'
    GROUP BY o.StoreID
),
ReturnData AS (
    SELECT
        o.StoreID,
        SUM(ret.ReturnQuantity * coi.UnitPrice) AS ReturnValue
    FROM Returns ret
    JOIN CleanOrderItems coi
        ON ret.OrderItemID = coi.OrderItemID
    JOIN Orders o
        ON coi.OrderID = o.OrderID
    WHERE o.OrderStatus = 'Completed'
      AND ret.ReturnDate >= DATE '2026-10-01'
      AND ret.ReturnDate < DATE '2026-11-01'
    GROUP BY o.StoreID
),
StoreSummary AS (
    SELECT
        r.RegionName,
        s.StoreID,
        s.StoreName,
        COALESCE(g.GrossSales, 0) AS GrossSales,
        COALESCE(rd.ReturnValue, 0) AS ReturnValue,
        COALESCE(g.GrossSales, 0)
            - COALESCE(rd.ReturnValue, 0) AS NetSales
    FROM Stores s
    JOIN Regions r
        ON s.RegionID = r.RegionID
    LEFT JOIN GrossData g
        ON s.StoreID = g.StoreID
    LEFT JOIN ReturnData rd
        ON s.StoreID = rd.StoreID
),
RankedStores AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY RegionName
            ORDER BY NetSales DESC, StoreID ASC
        ) AS StoreRank,
        SUM(NetSales) OVER (
            PARTITION BY RegionName
        ) AS RegionNetSales
    FROM StoreSummary
)
SELECT
    RegionName,
    StoreID,
    StoreName,
    GrossSales,
    ReturnValue,
    NetSales,
    StoreRank,
    ROUND(
        100.0 * NetSales / NULLIF(RegionNetSales, 0),
        2
    ) AS RegionNetSalesSharePercent
FROM RankedStores
ORDER BY RegionName, StoreRank;


-- QUESTION 11 – CATEGORY WITH THE HIGHEST RETURN VALUE

WITH RegionReturns AS (
    SELECT
        r.RegionName,
        SUM(ret.ReturnQuantity * coi.UnitPrice) AS ReturnValue
    FROM Returns ret
    JOIN CleanOrderItems coi
        ON ret.OrderItemID = coi.OrderItemID
    JOIN Orders o
        ON coi.OrderID = o.OrderID
    JOIN Stores s
        ON o.StoreID = s.StoreID
    JOIN Regions r
        ON s.RegionID = r.RegionID
    WHERE o.OrderStatus = 'Completed'
      AND ret.ReturnDate >= DATE '2026-10-01'
      AND ret.ReturnDate < DATE '2026-11-01'
    GROUP BY r.RegionName
),
HighestReturnRegion AS (
    SELECT RegionName
    FROM RegionReturns
    ORDER BY ReturnValue DESC, RegionName ASC
    LIMIT 1
)
SELECT
    h.RegionName,
    p.Category,
    SUM(ret.ReturnQuantity * coi.UnitPrice) AS CategoryReturnValue,
    ROUND(
        100.0 * SUM(ret.ReturnQuantity * coi.UnitPrice)
        / NULLIF(rr.ReturnValue, 0),
        2
    ) AS ShareOfRegionReturnsPercent
FROM Returns ret
JOIN CleanOrderItems coi
    ON ret.OrderItemID = coi.OrderItemID
JOIN Orders o
    ON coi.OrderID = o.OrderID
JOIN Stores s
    ON o.StoreID = s.StoreID
JOIN Regions r
    ON s.RegionID = r.RegionID
JOIN Products p
    ON coi.ProductID = p.ProductID
JOIN HighestReturnRegion h
    ON r.RegionName = h.RegionName
JOIN RegionReturns rr
    ON rr.RegionName = h.RegionName
WHERE o.OrderStatus = 'Completed'
  AND ret.ReturnDate >= DATE '2026-10-01'
  AND ret.ReturnDate < DATE '2026-11-01'
GROUP BY h.RegionName, p.Category, rr.ReturnValue
ORDER BY CategoryReturnValue DESC, p.Category ASC;

