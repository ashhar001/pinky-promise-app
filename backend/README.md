# Pinky Promise App - Backend

This directory contains the backend server for the Pinky Promise application. The backend is built with Node.js, Express, and PostgreSQL.

## Table of Contents

- [Prerequisites](#prerequisites)
- [PostgreSQL Setup](#postgresql-setup)
  - [MacOS](#macos)
  - [Windows](#windows)
  - [Linux](#linux)
- [Database Setup](#database-setup)
- [Environment Configuration](#environment-configuration)
- [Running the Server](#running-the-server)
- [Common Database Queries](#common-database-queries)
- [Database Backup & Restore](#database-backup--restore)
- [Database Migrations](#database-migrations)
- [Troubleshooting](#troubleshooting)
- [Security Best Practices](#security-best-practices)

## Prerequisites

- Node.js (v14 or later)
- npm or yarn
- PostgreSQL (v12 or later)

## PostgreSQL Setup

### MacOS

1. **Using Homebrew**:
   ```bash
   # Install Homebrew if not already installed
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   
   # Install PostgreSQL
   brew install postgresql
   
   # Start PostgreSQL service
   brew services start postgresql
   ```

2. **Using Postgres.app** (Alternative):
   - Download and install from [https://postgresapp.com/](https://postgresapp.com/)
   - Open the app to start the PostgreSQL server

### Windows

1. **Using Installer**:
   - Download the installer from [https://www.postgresql.org/download/windows/](https://www.postgresql.org/download/windows/)
   - Run the installer and follow the prompts
   - Make sure to remember the password you set for the postgres user

2. **Using Chocolatey**:
   ```powershell
   # Install Chocolatey if not already installed
   # Run in PowerShell as administrator
   Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
   
   # Install PostgreSQL
   choco install postgresql
   ```

### Linux (Ubuntu/Debian)

```bash
# Update package list
sudo apt update

# Install PostgreSQL
sudo apt install postgresql postgresql-contrib

# Start PostgreSQL service
sudo service postgresql start
```

## Database Setup

1. **Create a new database**:
   ```bash
   # Login to PostgreSQL as postgres user
   sudo -u postgres psql
   
   # Create a new database
   CREATE DATABASE pinky_promise;
   
   # Create a new user (replace 'your_username' and 'your_password')
   CREATE USER your_username WITH ENCRYPTED PASSWORD 'your_password';
   
   # Grant privileges
   GRANT ALL PRIVILEGES ON DATABASE pinky_promise TO your_username;
   
   # Exit psql
   \q
   ```

2. **Initialize the database tables**:
   ```bash
   # Navigate to the backend directory
   cd /path/to/pinky-promise-app/backend
   
   # Run the database initialization script (if available)
   # This command may vary based on your project setup
   npm run db:init
   
   # Alternatively, you can run the SQL setup directly
   psql -U your_username -d pinky_promise -a -f ./db/schema.sql
   ```

## Environment Configuration

Create a `.env` file in the backend directory with the following variables:

```bash
# Server Configuration
PORT=5001

# Database Configuration
DATABASE_URL=postgresql://your_username:your_password@localhost:5432/pinky_promise

# JWT Configuration (generate strong secrets)
JWT_SECRET=your_jwt_secret
JWT_REFRESH_SECRET=your_jwt_refresh_secret

# reCAPTCHA Configuration
RECAPTCHA_SECRET_KEY=your_recaptcha_secret_key
```

Make sure to replace placeholder values with your actual configuration.

## Running the Server

```bash
# Install dependencies
npm install

# Start the server
npm start

# For development with auto-restart
npm run dev
```

## Common Database Queries

Here are some common PostgreSQL queries for managing the users table:

### View All Users

```sql
SELECT id, name, email, created_at FROM users ORDER BY created_at DESC;
```

### Search Users

```sql
-- By Email
SELECT id, name, email, created_at FROM users WHERE email LIKE '%search_term%';

-- By Name
SELECT id, name, email, created_at FROM users WHERE name LIKE '%search_term%';
```

### User Statistics

```sql
-- Count total users
SELECT COUNT(*) as total_users FROM users;

-- Users registered by date
SELECT DATE(created_at) as date, COUNT(*) as registrations 
FROM users 
GROUP BY DATE(created_at) 
ORDER BY date DESC;
```

### Pinky Promise Specific Queries

```sql
-- Find users who haven't logged in recently
SELECT id, name, email, created_at 
FROM users
WHERE id NOT IN (
    SELECT DISTINCT user_id FROM login_history WHERE login_time > NOW() - INTERVAL '30 days'
)
ORDER BY created_at DESC;

-- Get user authentication statistics
SELECT 
    DATE(created_at) as registration_date,
    COUNT(*) as registrations,
    (SELECT COUNT(*) FROM login_history WHERE DATE(login_time) = DATE(u.created_at)) as logins
FROM users u
GROUP BY DATE(created_at)
ORDER BY registration_date DESC;

-- Find duplicate email registrations (should be none due to constraints)
SELECT email, COUNT(*) 
FROM users 
GROUP BY email 
HAVING COUNT(*) > 1;

-- Check for compromised or weak passwords (if you store password metadata)
-- Note: Actual passwords should never be stored in plaintext
SELECT id, name, email 
FROM users 
WHERE password_last_changed < NOW() - INTERVAL '90 days'
OR password_strength < 3;
```

### Managing Users

```sql
-- Create a new user (from SQL directly, not recommended for production)
INSERT INTO users (name, email, password) 
VALUES ('User Name', 'user@example.com', 'hashed_password_here')
RETURNING id, name, email, created_at;

-- Update user information
UPDATE users 
SET name = 'New Name', email = 'new@example.com' 
WHERE id = 'user_uuid_here'
RETURNING id, name, email, created_at;

-- Delete a user
DELETE FROM users WHERE id = 'user_uuid_here';
```

### Database Maintenance

```sql
-- Check table sizes
SELECT
  table_name,
  pg_size_pretty(pg_relation_size(quote_ident(table_name))) as size
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY pg_relation_size(quote_ident(table_name)) DESC;

-- Get table structure
\d users
```

## Database Backup & Restore

Regular database backups are essential for data safety. Here's how to back up and restore your Pinky Promise database:

### Creating Database Backups

```bash
# Full database backup (SQL format)
pg_dump -U your_username -d pinky_promise > backup_$(date +%Y%m%d).sql

# Compressed backup (smaller file size)
pg_dump -U your_username -d pinky_promise | gzip > backup_$(date +%Y%m%d).sql.gz

# Backup specific tables only
pg_dump -U your_username -d pinky_promise -t users > users_backup_$(date +%Y%m%d).sql
```

### Automating Backups

Create a shell script in the `scripts` directory:

```bash
#!/bin/bash
# scripts/backup-db.sh

BACKUP_DIR="/path/to/backup/directory"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Create backup directory if it doesn't exist
mkdir -p $BACKUP_DIR

# Create the backup
pg_dump -U your_username -d pinky_promise | gzip > $BACKUP_DIR/pinky_promise_$TIMESTAMP.sql.gz

# Optional: Delete backups older than 30 days
find $BACKUP_DIR -name "pinky_promise_*.sql.gz" -type f -mtime +30 -delete

echo "Backup completed: $BACKUP_DIR/pinky_promise_$TIMESTAMP.sql.gz"
```

Make it executable and schedule with cron:

```bash
chmod +x scripts/backup-db.sh

# Add to crontab (daily at 2 AM)
crontab -e
# Add the following line
0 2 * * * /path/to/pinky-promise-app/backend/scripts/backup-db.sh
```

### Restoring from Backup

```bash
# For plain SQL backups
psql -U your_username -d pinky_promise < backup_file.sql

# For compressed backups
gunzip -c backup_file.sql.gz | psql -U your_username -d pinky_promise

# To restore to a new/empty database
createdb -U your_username pinky_promise_restored
psql -U your_username -d pinky_promise_restored < backup_file.sql
```

## Database Migrations

As your application evolves, you'll need to make changes to the database schema. Here's how to manage migrations:

### Creating a Migration

Store migration scripts in a `migrations` directory:

```bash
# Create migrations directory if it doesn't exist
mkdir -p migrations

# Create a new migration file
touch migrations/$(date +%Y%m%d%H%M%S)_add_user_profile_table.sql
```

Example migration file structure:

```sql
-- migrations/20250531120000_add_user_profile_table.sql

-- Up Migration (Apply changes)
BEGIN;

CREATE TABLE user_profiles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  bio TEXT,
  avatar_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX user_profiles_user_id_idx ON user_profiles(user_id);

COMMIT;

-- Down Migration (Rollback changes)
-- BEGIN;
-- DROP TABLE IF EXISTS user_profiles;
-- COMMIT;
```

### Applying Migrations

Execute the migration script:

```bash
psql -U your_username -d pinky_promise -f migrations/20250531120000_add_user_profile_table.sql
```

### Tracking Migrations

Create a migrations table to track applied migrations:

```sql
CREATE TABLE migrations (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL UNIQUE,
  applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

Update your migration scripts to check if they've been applied:

```sql
-- Check if migration has been applied
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM migrations WHERE name = '20250531120000_add_user_profile_table') THEN
    -- Migration code here
    
    -- Record migration
    INSERT INTO migrations (name) VALUES ('20250531120000_add_user_profile_table');
  END IF;
END $$;
```

## Troubleshooting

### Common Issues

1. **Cannot connect to database**:
   - Make sure PostgreSQL service is running
   - Verify credentials in your `.env` file
   - Check if the database exists
   - Ensure your IP is allowed in pg_hba.conf

2. **Rate limiting issues**:
   - The auth endpoints have rate limiting (30 requests per 5 minutes by default)
   - Check the rateLimiter.js file to adjust settings during development

3. **JWT or authentication issues**:
   - Make sure your JWT_SECRET and JWT_REFRESH_SECRET are set correctly
   - Check token expiration settings in your auth routes

4. **reCAPTCHA issues**:
   - Verify your RECAPTCHA_SECRET_KEY in the .env file
   - Make sure the frontend site key matches the backend secret key
   - For development, you may need to temporarily disable captcha verification

5. **Database Schema Issues**:
   - If you get errors about missing columns or tables:
     ```bash
     # View current table structure
     psql -d pinky_promise -c "\d users"
     
     # Check if a specific column exists
     psql -d pinky_promise -c "SELECT column_name FROM information_schema.columns WHERE table_name='users' AND column_name='column_name';"
     ```

### Resolving Common Errors

1. **"relation does not exist" error**:
   ```bash
   # Create the missing table
   psql -d pinky_promise -c "CREATE TABLE users (
     id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
     name TEXT NOT NULL,
     email TEXT NOT NULL UNIQUE,
     password TEXT NOT NULL,
     created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
   );"
   ```

2. **"role does not exist" error**:
   ```bash
   # Login as postgres user
   sudo -u postgres psql
   
   # Create the missing role
   CREATE USER your_username WITH ENCRYPTED PASSWORD 'your_password';
   GRANT ALL PRIVILEGES ON DATABASE pinky_promise TO your_username;
   ```

3. **"extension does not exist" error for uuid-ossp**:
   ```bash
   # As postgres user
   sudo -u postgres psql -d pinky_promise -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";"
   ```

### Logs

Check the server logs for more detailed error information:

```bash
# View last 100 lines of logs
tail -n 100 server.log
```

## Security Best Practices

1. **Environment Variables**:
   - Never commit `.env` files to your repository
   - Use strong, unique secrets for JWT tokens
   - Rotate secrets periodically

2. **Database Security**:
   - Use a dedicated database user with limited permissions
   - Never use the postgres superuser in your application
   - Set a strong password for database users
   - Consider using SSL for database connections

3. **API Security**:
   - Implement proper rate limiting
   - Use HTTPS in production
   - Validate and sanitize all user inputs
   - Implement proper CORS settings

4. **Password Storage**:
   - Always hash passwords (the app uses bcrypt)
   - Never store plain text passwords
   - Consider implementing additional security like 2FA

5. **Production Deployment**:
   - Use a reverse proxy like Nginx
   - Set up proper firewall rules
   - Regularly update dependencies
   - Implement health checks and monitoring

---

For any additional information or support, please refer to the project documentation or contact the development team.

