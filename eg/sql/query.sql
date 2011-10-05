-- Get all employees with a salary of more than 500
-- and sort them by last name ascending
SELECT *
    FROM Employee
    WHERE salary > 500.00
    ORDER BY last_name;