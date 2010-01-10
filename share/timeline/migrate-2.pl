use strict;
use Padre::DB::Migrate::Patch;

# This patch creates the plugin table.
# In the initial implementation this stores the enabled/disabled
# state of the plugin, the version, and the config structure for
# the plugin.

# Create the host settings table
do(<<'END_SQL');
CREATE TABLE plugin (
	name VARCHAR(255) PRIMARY KEY,
	version VARCHAR(255),
	enabled BOOLEAN,
	config TEXT
)
END_SQL
