-- Account table of the "SQL users" recipe. The Lua backend reads it with a read-only connection for logins and
-- writes the MFA columns through a second connection.
CREATE TABLE accounts (
  id INT NOT NULL AUTO_INCREMENT,
  username VARCHAR(255) NOT NULL,
  account VARCHAR(255) NOT NULL,
  password VARCHAR(255) NOT NULL,
  display_name VARCHAR(255) NOT NULL,
  mail VARCHAR(255) NOT NULL,
  enabled BOOLEAN NOT NULL DEFAULT TRUE,
  totp_secret VARCHAR(255) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY username_idx (username),
  UNIQUE KEY account_idx (account)
);

CREATE TABLE recovery_codes (
  account_id INT NOT NULL,
  code VARCHAR(255) NOT NULL,
  PRIMARY KEY (account_id, code),
  FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE
);

-- alice: alice-secret ({SSHA512}), bob: bob-secret (bcrypt), dave: dave-secret but disabled.
INSERT INTO accounts (username, account, password, display_name, mail, enabled) VALUES
  ('alice', 'alice@example.test',
   '{SSHA512}bIs2FISYSUHHJuB7yzQJBQbnSc2TUG1toOZKJ96a0H5teLaswlqMRRMGbXq99MuZvKvW5aHXJQdPjoL/foemUmNvb2tib29r',
   'Alice Example', 'alice@example.test', TRUE),
  ('bob', 'bob@example.test',
   '$2y$10$vUNCt8LDP9xgBCJkIRd7k.RzPdWOIqbK2ijZTTDEVb6blyR.KLJQC',
   'Bob Example', 'bob@example.test', TRUE),
  ('dave', 'dave@example.test',
   '$2y$10$jTeWfTpO/LLsuC9Z61sbzuKwZBUZKNJUf1rJPuXPZJElxlkcdn77S',
   'Dave Example (disabled)', 'dave@example.test', FALSE);

-- Two database users: one that can only read, one that may change the MFA columns.
CREATE USER 'nauthilus_ro'@'%' IDENTIFIED BY 'cookbook-ro';
GRANT SELECT ON cookbook.* TO 'nauthilus_ro'@'%';

CREATE USER 'nauthilus_mfa'@'%' IDENTIFIED BY 'cookbook-mfa';
GRANT SELECT, UPDATE (totp_secret) ON cookbook.accounts TO 'nauthilus_mfa'@'%';
GRANT SELECT, INSERT, DELETE ON cookbook.recovery_codes TO 'nauthilus_mfa'@'%';
