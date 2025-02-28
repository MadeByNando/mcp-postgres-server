-- Create tables for Employees database

-- Departments table
CREATE TABLE departments (
  department_id SERIAL PRIMARY KEY,
  department_name VARCHAR(100) NOT NULL,
  location VARCHAR(100)
);

-- Employees table
CREATE TABLE employees (
  employee_id SERIAL PRIMARY KEY,
  first_name VARCHAR(50) NOT NULL,
  last_name VARCHAR(50) NOT NULL,
  email VARCHAR(100) UNIQUE NOT NULL,
  phone_number VARCHAR(20),
  hire_date DATE NOT NULL,
  job_title VARCHAR(100) NOT NULL,
  salary NUMERIC(10, 2) NOT NULL,
  department_id INTEGER REFERENCES departments(department_id)
);

-- Projects table
CREATE TABLE projects (
  project_id SERIAL PRIMARY KEY,
  project_name VARCHAR(100) NOT NULL,
  start_date DATE,
  end_date DATE,
  budget NUMERIC(12, 2),
  status VARCHAR(20) DEFAULT 'Planning'
);

-- Employee-Project assignments
CREATE TABLE employee_projects (
  employee_id INTEGER REFERENCES employees(employee_id),
  project_id INTEGER REFERENCES projects(project_id),
  role VARCHAR(50),
  assignment_date DATE NOT NULL,
  PRIMARY KEY (employee_id, project_id)
);

-- Insert sample data for departments
INSERT INTO departments (department_name, location) VALUES
  ('Engineering', 'Building A'),
  ('Marketing', 'Building B'),
  ('Human Resources', 'Building A'),
  ('Finance', 'Building C'),
  ('Sales', 'Building B');

-- Insert sample data for employees
INSERT INTO employees (first_name, last_name, email, phone_number, hire_date, job_title, salary, department_id) VALUES
  ('John', 'Smith', 'john.smith@example.com', '555-1234', '2020-01-15', 'Software Engineer', 85000.00, 1),
  ('Emily', 'Johnson', 'emily.johnson@example.com', '555-2345', '2019-05-20', 'Marketing Specialist', 65000.00, 2),
  ('Michael', 'Williams', 'michael.williams@example.com', '555-3456', '2021-03-10', 'HR Manager', 78000.00, 3),
  ('Sarah', 'Brown', 'sarah.brown@example.com', '555-4567', '2018-11-05', 'Financial Analyst', 72000.00, 4),
  ('David', 'Jones', 'david.jones@example.com', '555-5678', '2020-08-22', 'Sales Representative', 68000.00, 5),
  ('Jessica', 'Davis', 'jessica.davis@example.com', '555-6789', '2021-01-30', 'Software Engineer', 82000.00, 1),
  ('Robert', 'Miller', 'robert.miller@example.com', '555-7890', '2019-09-15', 'Marketing Manager', 88000.00, 2),
  ('Jennifer', 'Wilson', 'jennifer.wilson@example.com', '555-8901', '2020-04-12', 'HR Specialist', 62000.00, 3),
  ('Christopher', 'Moore', 'christopher.moore@example.com', '555-9012', '2018-07-25', 'Financial Manager', 95000.00, 4),
  ('Amanda', 'Taylor', 'amanda.taylor@example.com', '555-0123', '2021-02-18', 'Sales Manager', 90000.00, 5);

-- Insert sample data for projects
INSERT INTO projects (project_name, start_date, end_date, budget, status) VALUES
  ('Website Redesign', '2022-01-10', '2022-06-30', 120000.00, 'In Progress'),
  ('Marketing Campaign', '2022-02-15', '2022-05-15', 75000.00, 'In Progress'),
  ('Employee Training Program', '2022-03-01', '2022-04-30', 30000.00, 'Planning'),
  ('Financial Reporting System', '2022-04-01', '2022-09-30', 200000.00, 'Planning'),
  ('Sales Automation', '2022-02-01', '2022-07-31', 150000.00, 'In Progress');

-- Insert sample data for employee-project assignments
INSERT INTO employee_projects (employee_id, project_id, role, assignment_date) VALUES
  (1, 1, 'Lead Developer', '2022-01-10'),
  (6, 1, 'Frontend Developer', '2022-01-15'),
  (2, 2, 'Marketing Specialist', '2022-02-15'),
  (7, 2, 'Project Manager', '2022-02-15'),
  (3, 3, 'Training Coordinator', '2022-03-01'),
  (8, 3, 'Content Developer', '2022-03-05'),
  (4, 4, 'Financial Analyst', '2022-04-01'),
  (9, 4, 'Project Manager', '2022-04-01'),
  (5, 5, 'Sales Representative', '2022-02-01'),
  (10, 5, 'Project Manager', '2022-02-01'); 