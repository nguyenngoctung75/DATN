-- Grant the app user full access to all app databases (primary, cache, queue, cable)
GRANT ALL PRIVILEGES ON `tool_test_%`.* TO 'tool_test'@'%';
FLUSH PRIVILEGES;
