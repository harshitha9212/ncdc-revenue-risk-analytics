-- ============================================
-- TAPCMS AFZALPUR REVENUE ANALYTICS
-- Intermediate SQL for Risk Assessment
-- ============================================

-- Create main table with constraints
CREATE TABLE revenue_streams (
    stream_id INT PRIMARY KEY,
    stream_name VARCHAR(50) NOT NULL,
    year_1_revenue DECIMAL(12,2) NOT NULL CHECK (year_1_revenue > 0),
    churn_rate DECIMAL(4,2) NOT NULL CHECK (churn_rate BETWEEN 0 AND 1),
    stability VARCHAR(20) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert data
INSERT INTO revenue_streams (stream_id, stream_name, year_1_revenue, churn_rate, stability) VALUES
(1, 'Fertilizer_Sales', 5927862.09, 0.15, 'Medium'),
(2, 'Rental_Income', 1279410.88, 0.10, 'High'),
(3, 'PDS_Commission', 936447.31, 0.20, 'High'),
(4, 'Food_Grains', 173232.00, 0.35, 'Low'),
(5, 'MSP_Commission', 25650.00, 0.40, 'Low');

-- ============================================
-- QUERY 1: Revenue Concentration with Ranking
-- Using window functions
-- ============================================

WITH revenue_stats AS (
    SELECT 
        stream_name,
        year_1_revenue,
        SUM(year_1_revenue) OVER () AS total_revenue,
        year_1_revenue / SUM(year_1_revenue) OVER () * 100 AS share_pct,
        RANK() OVER (ORDER BY year_1_revenue DESC) AS revenue_rank,
        ROW_NUMBER() OVER (ORDER BY year_1_revenue DESC) AS row_num
    FROM revenue_streams
)
SELECT 
    stream_name,
    year_1_revenue,
    ROUND(share_pct, 2) AS share_pct,
    revenue_rank,
    CASE 
        WHEN share_pct > 50 THEN 'Critical'
        WHEN share_pct > 20 THEN 'High'
        WHEN share_pct > 10 THEN 'Medium'
        ELSE 'Low'
    END AS concentration_risk
FROM revenue_stats
ORDER BY revenue_rank;

-- ============================================
-- QUERY 2: Churn Risk Segmentation
-- Using CTE and conditional aggregation
-- ============================================

WITH risk_categories AS (
    SELECT 
        stream_name,
        year_1_revenue,
        churn_rate,
        stability,
        CASE 
            WHEN churn_rate <= 0.15 THEN 'Low Risk'
            WHEN churn_rate <= 0.25 THEN 'Medium Risk'
            ELSE 'High Risk'
        END AS risk_category,
        year_1_revenue * churn_rate AS expected_annual_loss
    FROM revenue_streams
)
SELECT 
    risk_category,
    COUNT(*) AS stream_count,
    SUM(year_1_revenue) AS total_revenue,
    SUM(expected_annual_loss) AS total_expected_loss,
    AVG(churn_rate) AS avg_churn_rate
FROM risk_categories
GROUP BY risk_category
HAVING COUNT(*) >= 1
ORDER BY avg_churn_rate;

-- ============================================
-- QUERY 3: Year-over-Year Retention Projection
-- Using recursive CTE
-- ============================================

WITH RECURSIVE retention_projection AS (
    -- Base case: Year 0
    SELECT 
        stream_id,
        stream_name,
        churn_rate,
        100.0 AS retention_pct,
        0 AS year_num
    FROM revenue_streams
    
    UNION ALL
    
    -- Recursive case: each year
    SELECT 
        r.stream_id,
        r.stream_name,
        r.churn_rate,
        rp.retention_pct * (1 - r.churn_rate) AS retention_pct,
        rp.year_num + 1 AS year_num
    FROM revenue_streams r
    JOIN retention_projection rp ON r.stream_id = rp.stream_id
    WHERE rp.year_num < 7
)
SELECT 
    stream_name,
    year_num,
    ROUND(retention_pct, 2) AS retention_pct
FROM retention_projection
ORDER BY stream_name, year_num;

-- ============================================
-- QUERY 4: CLV Calculation with Discounting
-- Using LAG for year-over-year comparison
-- ============================================

WITH clv_calc AS (
    SELECT 
        stream_id,
        stream_name,
        year_1_revenue,
        churn_rate,
        year_1_revenue * 0.65 AS annual_margin,
        0.09 AS discount_rate,
        (year_1_revenue * 0.65) * (1 + 0.09) / (0.09 + churn_rate) AS clv
    FROM revenue_streams
)
SELECT 
    c.stream_name,
    c.year_1_revenue,
    c.churn_rate,
    ROUND(c.clv, 2) AS clv,
    ROUND(c.clv / c.year_1_revenue, 2) AS clv_multiple,
    LAG(c.clv) OVER (ORDER BY c.clv DESC) AS next_highest_clv,
    c.clv - LAG(c.clv) OVER (ORDER BY c.clv DESC) AS clv_gap
FROM clv_calc c
ORDER BY c.clv DESC;

-- ============================================
-- QUERY 5: Scenario Impact Analysis
-- Using self-JOIN and calculated fields
-- ============================================

SELECT 
    r.stream_name,
    r.year_1_revenue,
    r.churn_rate,
    s.scenario_name,
    s.revenue_loss_pct,
    ROUND(r.year_1_revenue * (1 - s.revenue_loss_pct), 2) AS projected_revenue,
    ROUND(r.year_1_revenue * (1 - s.revenue_loss_pct) * 0.70, 2) AS projected_pat
FROM revenue_streams r
CROSS JOIN (
    SELECT 'Base' AS scenario_name, 0.00 AS revenue_loss_pct
    UNION ALL SELECT '10pct_Churn', 0.10
    UNION ALL SELECT '20pct_Churn', 0.20
    UNION ALL SELECT '30pct_Churn', 0.30
    UNION ALL SELECT 'Lose_Fertilizer', 0.711
) s
WHERE r.stream_name = 'Fertilizer_Sales' OR s.scenario_name = 'Base'
ORDER BY s.revenue_loss_pct, r.stream_name;
