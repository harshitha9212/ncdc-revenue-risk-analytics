-- Create revenue streams table
CREATE TABLE revenue_streams (
    stream_id INT PRIMARY KEY,
    stream_name VARCHAR(50),
    year_1_revenue DECIMAL(12,2),
    churn_rate DECIMAL(4,2),
    stability VARCHAR(20)
);

-- Insert data
INSERT INTO revenue_streams VALUES
(1, 'Fertilizer_Sales', 5927862.09, 0.15, 'Medium'),
(2, 'Rental_Income', 1279410.88, 0.10, 'High'),
(3, 'PDS_Commission', 936447.31, 0.20, 'High'),
(4, 'Food_Grains', 173232.00, 0.35, 'Low'),
(5, 'MSP_Commission', 25650.00, 0.40, 'Low');

-- Query 1: Revenue concentration
SELECT 
    stream_name,
    year_1_revenue,
    ROUND(year_1_revenue / (SELECT SUM(year_1_revenue) FROM revenue_streams) * 100, 1) as share_pct
FROM revenue_streams
ORDER BY share_pct DESC;

-- Query 2: High-risk streams (churn > 20%)
SELECT stream_name, churn_rate, stability
FROM revenue_streams
WHERE churn_rate > 0.20;

-- Query 3: Weighted average churn
SELECT 
    SUM(year_1_revenue * churn_rate) / SUM(year_1_revenue) as weighted_avg_churn
FROM revenue_streams;