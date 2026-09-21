USE bikestores;

-- ============================================================
-- BikeStores Analytics
-- Cleaning Decisions
-- ============================================================

/*
DATA QUALITY SUMMARY
---------------------------------------------------------------

1. PRIMARY KEYS
   - No duplicate primary keys detected.
   - Composite keys are unique.

2. FOREIGN KEYS
   - No orphan records detected.

3. MISSING VALUES
   - customers.phone contains many NULL values.
     Decision: Keep as NULL.
     Reason: Optional contact information and not required
     for planned business analysis.

   - orders.shipped_date contains NULL values.
     Decision: Keep as NULL.
     Reason: NULL values belong to Pending, Processing,
     or Rejected orders.

   - staffs.manager_id contains one NULL value.
     Decision: Keep as NULL.
     Reason: Represents the root manager in the hierarchy.

4. NUMERIC VALUES
   - No invalid quantities.
   - No negative prices.
   - No invalid discount values.
   - No negative inventory values.

5. DATE CONSISTENCY
   - No required_date values before order_date.
   - No shipped_date values before order_date.

6. CATEGORICAL / STRING VALUES
   - No leading/trailing whitespace detected.
   - No empty critical string values detected.
   - Brand/category/state values are consistent.

FINAL DECISION
---------------------------------------------------------------
No destructive cleaning operations are required.

Raw source tables will remain unchanged.

Business transformations and derived fields will be created
in analytical views.
*/