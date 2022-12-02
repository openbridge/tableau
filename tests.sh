

{
echo '<tsRequest>'
echo '  <credentials name="admin" password="admin" >'
echo '    <site contentUrl="" />'
echo '  </credentials>'
echo '</tsRequest>'
} | tee ./login.xml


curl "http://tableau.openbridge.com/api/3.6/auth/signin" -X POST -d "@login.xml"
curl -H "X-Tableau-Auth:OLe3RzF1SXe7PhePPg06zw|aaqi5TUvTNP5luGZTzqBz5CZmLmrn5W3" "http://18.212.214.37/api/3.4/sites" -X POST -d "@login.xml"




{
  echo '    <tsRequest>'
  echo '       <project name="testing-2"'
  echo '        description="project-description" />'
  echo '    </tsRequest>'
} | tee ./project2.xml

curl "http://18.212.214.37/api/3.4/sites/9b4b857b-e5dc-48d5-8bcc-7752410dd26e/projects" -X POST -H "X-Tableau-Auth:OLe3RzF1SXe7PhePPg06zw|aaqi5TUvTNP5luGZTzqBz5CZmLmrn5W3" -d "@project2.xml"


{
  echo '    <tsRequest>'
  echo '       <user fullName="tom"'
  echo '         authSetting="SAML"'
  echo '         siteRole="Interactor" />'
  echo '    </tsRequest>'
} | tee ./update-user.xml

curl "http://54.237.231.210/api/3.6/sites/985c172e-cd8e-461a-8057-69316238dc6f/users/fd4e323c-9f3f-4f54-bd77-5f3733dfe3d8" -X PUT -H "X-Tableau-Auth:Q8gwfNhATHy4lJJzwwO1mg|ix3FxJELDL3frCVX21KSqvSLhz8Bk89G" -d "@update-user.xml"

{
  echo '    <tsRequest>'
  echo '        <user name="thomas@openbridge.com"'
  echo '        siteRole="Interactor" />'
  echo '        authSetting="SAML"'
  echo '    </tsRequest>'
} | tee ./new-user.xml


curl "http://tableau.openbridge.com/api/3.6/sites/985c172e-cd8e-461a-8057-69316238dc6f/users/" -X POST -H "X-Tableau-Auth:ZgRJHi2ETwSK_FNVPtluoA|mQ1jB7BsneyASj6p9CY7X9VrrjrK2nyA" -d "@new-user.xml"



{
  echo '    <tsRequest>'
  echo '        <user name="thomas@openbridge.com"'
  echo '        siteRole="SiteAdministratorExplorer" />'
  echo '        authSetting="SAML"'
  echo '    </tsRequest>'
} | tee ./update-user.xml


curl "http://tableau.openbridge.com/api/3.6/sites/985c172e-cd8e-461a-8057-69316238dc6f/users/" -X POST -H "X-Tableau-Auth:bSJfcquvQ-2EAED3GX674A|q3lEPFKII3OcpRSDazO8VB4esZGv60Jv" -d "@new-user.xml"



# In this example, we need to add a user to a group. A requirement is the "username" as it is a unique key in Tableau. This would need to align with Keycloak.
# First, we need to call "/api/api-version/sites/site-id/users" to get a list. We can use a filter
# /api/api-version/sites/site-id/users?filter=name:eq:henryw
# (if this user does not exist, then create?)
# With the response, we get the user ID.
# Next, we call to get the groups assocaited with the site ""/api/api-version/sites/site-id/groups"

# We need to get a list of sites "/api/api-version/sites" to get the site id. The "name="site-name"" needs to match assuming a site is passed from keyCloak. This is a unique key (like user-name above)

To make the call we need to get the site ID, group ID and user ID

{
  echo '    <tsRequest>'
  echo '      <user id="user-id" />'
  echo '    </tsRequest>'
} | tee ./add-user-group.xml

curl "http://18.212.214.37/api/3.6/sites/site-id/groups/group-id/users" -X POST -H "X-Tableau-Auth:OLe3RzF1SXe7PhePPg06zw|aaqi5TUvTNP5luGZTzqBz5CZmLmrn5W3" -d "@add-user-group.xml"
