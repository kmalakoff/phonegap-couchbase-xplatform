# Run me with:
#   $ ruby couch_automate.rb
#
require 'rubygems'
require 'soca'
require 'couchpack'

# watch the soca directories
p = fork { exec 'cd soca/mycouchapp; soca autopush' }
Process.detach(p)
p = fork { exec 'cd soca/mydata; soca autopush' }
Process.detach(p)
p = fork { exec 'cd soca/mydata_views; soca autopush' }
Process.detach(p)

# give a little time for the database to be updated
sleep(2)

# watch the couch documents
p = fork { exec 'cd phonegap-couchbase-ios/phonegap-couchbase-ios/Resources; couchpack document http://localhost:5984/mycouchapp_db/_design/mycouchapp mycouchapp --auto' }
Process.detach(p)
p = fork { exec 'cd phonegap-couchbase-ios/phonegap-couchbase-ios/Resources; couchpack document http://localhost:5984/mycouchapp_db/mydata mydata --auto' }
Process.detach(p)
p = fork { exec 'cd phonegap-couchbase-ios/phonegap-couchbase-ios/Resources; couchpack document http://localhost:5984/mycouchapp_db/_design/mydata_views mydata_views --auto' }
Process.detach(p)
p = fork { exec 'cd phonegap-couchbase-android/assets; couchpack document http://localhost:5984/mycouchapp_db/_design/mycouchapp mycouchapp --auto' }
Process.detach(p)
p = fork { exec 'cd phonegap-couchbase-android/assets; couchpack document http://localhost:5984/mycouchapp_db/mydata mydata --auto' }
Process.detach(p)
p = fork { exec 'cd phonegap-couchbase-android/assets; couchpack document http://localhost:5984/mycouchapp_db/_design/mydata_views mydata_views --auto' }
Process.detach(p)
