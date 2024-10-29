# ora-sql.sh

A Bash script for simplified execution of SQL commands and SQL scripts in Oracle databases. Supports both SYSDBA and user-based connections.

## Features

- 🚀 Quick SQL execution without complex sqlplus syntax
- 👥 Support for SYSDBA and regular users
- 📂 SQL file execution
- 🎯 Automatic SID detection
- 🔒 Secure password prompting
- 🌈 Colored output for better readability

## Prerequisites

- Oracle Database Client (sqlplus)
- Bash Shell
- Properly configured Oracle environment (/etc/oratab)
- Sufficient Oracle access permissions

## Installation

1. Download the script:
```bash
curl -O https://raw.githubusercontent.com/yourusername/ora-sql/main/ora-sql.sh
```

2. Make it executable:
```bash
chmod +x ora-sql.sh
```

3. Optional: Move to PATH directory:
```bash
sudo mv ora-sql.sh /usr/local/bin/ora-sql
```

## Usage

### Basic Syntax
```bash
./ora-sql.sh [-u user] [SID] [command|file.sql]
```

### Parameters
- `-u user`: Oracle user (optional, default: sysdba)
- `SID`: Oracle SID (optional, will be detected automatically)
- `command|file.sql`: SQL command or path to SQL file

### Examples

1. Check database status (as SYSDBA):
```bash
./ora-sql.sh
```

2. Check specific database:
```bash
./ora-sql.sh mydb
```

3. Execute SQL command:
```bash
./ora-sql.sh "select sysdate from dual"
```

4. Execute as specific user:
```bash
./ora-sql.sh -u system "select * from dba_users"
```

5. Execute SQL file:
```bash
./ora-sql.sh myscript.sql
```

6. Execute SQL file on specific database as user:
```bash
./ora-sql.sh -u scott mydb myscript.sql
```

### SQL Files

SQL files must have the `.sql` extension and can contain multiple SQL commands:

```sql
-- Example myscript.sql
select sysdate from dual;
select * from v$version;
-- Comments are ignored
select username from all_users;
```

## Detailed Features

### Automatic SID Detection
- Detects available SIDs from /etc/oratab
- Automatically selects single SID if only one is available
- Provides selection menu for multiple SIDs

### User Authentication
- SYSDBA access without password (default)
- Secure password prompting for regular users
- Supports all Oracle users

### SQL Execution
- Direct command execution
- Script execution
- Automatic comment removal
- Optional semicolon at end of commands

## Exit Status

- 0: Success
- 1: Error (wrong arguments, connection error, SQL error)

## Environment Variables

The script automatically sets:
- `ORACLE_SID`: Based on selection/input
- `ORACLE_HOME`: From /etc/oratab
- `PATH`: Extended with $ORACLE_HOME/bin

## Troubleshooting

### Common Issues

1. "No SIDs found"
   - Check /etc/oratab
   - Ensure Oracle is properly installed

2. "Connection error"
   - Check Oracle listener
   - Verify user/password

3. "Insufficient privileges"
   - Check user permissions
   - Use SYSDBA if needed

## Development

### Tests

The repository includes a test suite:
```bash
./testsql.sh
```

Tests verify:
- Basic functionality
- User connections
- Error handling
- SQL execution
- File processing

### Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create Pull Request

## License

[MIT](LICENSE)

## Author

[Your Name]

## Changelog

### Version 1.0 (October 2024)
- Initial release
- SYSDBA and user support
- SQL file support
- Colored output
- Automatic SID detection

## Advanced Examples

### Working with System Queries
```bash
# Check database version
./ora-sql.sh "select * from v\$version"

# List all users
./ora-sql.sh -u system "select username, created from dba_users"

# Check tablespace usage
./ora-sql.sh "select tablespace_name, used_percent from dba_tablespace_usage_metrics"
```

### Maintenance Tasks
```bash
# Create maintenance script
cat > maintenance.sql << EOF
-- Check invalid objects
select owner, object_type, object_name from dba_objects where status = 'INVALID';
-- Check tablespace usage
select tablespace_name, used_percent from dba_tablespace_usage_metrics;
-- Check active sessions
select username, sid, serial#, status from v\$session where type != 'BACKGROUND';
EOF

# Execute maintenance script
./ora-sql.sh maintenance.sql
```

### User Management
```bash
# Create user management script
cat > user_mgmt.sql << EOF
-- List locked accounts
select username, account_status, lock_date 
from dba_users 
where account_status like '%LOCKED%';
-- Check password expiry
select username, account_status, expiry_date 
from dba_users 
where expiry_date is not null;
EOF

# Execute as system
./ora-sql.sh -u system user_mgmt.sql
```

## Security Notes

- The script uses secure password prompting
- No passwords are stored or logged
- SYSDBA access requires appropriate OS permissions
- Connection details are not exposed in process list

## Performance Tips

1. Use appropriate indexes for queries
2. Include WHERE clauses to limit results
3. Use specific column names instead of SELECT *
4. Consider using bind variables for repeated queries

## Dependencies

- Oracle Instant Client or full Oracle Client
- Bash 4.0 or higher
- Standard Unix utilities (awk, grep, sed)
- Oracle sqlplus executable in PATH

## Feedback and Issues

Please report bugs and feature requests through the GitHub issue tracker.
